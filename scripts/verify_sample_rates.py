#!/usr/bin/env python3
"""Hardware-in-the-loop check for Quartz AD7768 sample-rate firmware.

Requires the bundled Bedrock LEEP client and NumPy. See README_sample_rate_test.md.
By default the script does not program flash or reboot the board. The optional
--boot-app path uses Alluvium to clear the boot error state and boot the app image.
The test changes ADC rates, deterministically triggers the DRDY recorder (see
trigger_recorder()) to independently measure the new rates' physical DRDY
cadence, then restores an explicitly requested rate and runtime debug mask.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import socket
import statistics
import struct
import subprocess
import sys
import time
from typing import Any


ACQ_CLOCK_HZ = 125_000_000
ADC_CHIP_COUNT = 4
RECORDER_SAMPLE_COUNT = 131_072
RECORDER_FILE_BYTES = RECORDER_SAMPLE_COUNT * 2

REG_AD7768_RECORDER = 60
REG_AD7768_STATUSES = 65
REG_SAMPLING_RATE = 81
REG_AD7768_RESET = 82
REG_FIRMWARE_BUILD_DATE = 20
REG_SOFTWARE_BUILD_DATE = 21
REG_UPTIME = 40
REG_DRDY_STATUS = 292
REG_ADC_ALIGNMENT_COUNT = 294
REG_AD7768_MCLK_HZ = 295  # sysmon bank 0xC0, index 3

GPIO_DRDY_MISALIGNED = 0x8000_0000
DEBUGFLAG_DUMP_AD7768_REG = 0x0000_2000
DEBUGFLAG_ENABLE_DRDY_FAULT = 0x0020_0000

# Only the first this-many samples of the 131,072-sample recorder buffer are
# used for DRDY rate analysis (settled steady-state history; see
# analyze_drdy_capture()).
DRDY_ANALYSIS_SAMPLE_COUNT = 100_000

# Extra margin (well over 10x) above ad7768recorder.v's PRE_TRIGGER_LOAD
# duration (SAMPLE_COUNT - SAMPLE_COUNT/8 - 2 acqClk cycles, ~0.92ms at
# 125MHz) so the second recorder-arm write in trigger_recorder() reliably
# lands after the state machine has reached ST_AWAIT_TRIGGER.
RECORDER_ARM_TO_TRIGGER_DELAY_S = 0.010

# These flags trigger one-shot actions when the console receives a debug command.
DEBUGFLAG_ONESHOT_MASK = (
    0x0000_0200  # FLASH_SHOW
    | 0x0000_0400  # IIC_FPGA_SCAN
    | 0x0000_0800  # DUMP_MPS_REG
    | DEBUGFLAG_DUMP_AD7768_REG
    | 0x0001_0000  # MGTSTATUSSHOW
    | 0x0002_0000  # MGTCLKSWITCHSHOW
    | 0x0004_0000  # START_AD7768_ALIGN
    | 0x0010_0000  # TEST_AD7768_RAM
)


@dataclass(frozen=True)
class RateSpec:
    rate_hz: int
    mclk_hz: int
    mclk_divider: int
    decimation: int

    @property
    def channel_mode(self) -> int:
        # AD7768 wideband mode values: decimate by 32 through 1024.
        return self.decimation.bit_length() - 6

    @property
    def power_mode_register(self) -> int:
        # Firmware writes LVDS enable (0x08) OR the MCLK divider mode.
        return 0x08 | (0x33 if self.mclk_divider == 4 else 0x00)

    @property
    def calculated_rate_hz(self) -> int:
        return self.mclk_hz // (self.mclk_divider * self.decimation)


RATE_SPECS = {
    250_000: RateSpec(250_000, 32_000_000, 4, 32),
    160_000: RateSpec(160_000, 20_480_000, 4, 32),
    100_000: RateSpec(100_000, 25_600_000, 4, 64),
    50_000: RateSpec(50_000, 25_600_000, 4, 128),
    25_000: RateSpec(25_000, 25_600_000, 4, 256),
    5_000: RateSpec(5_000, 20_480_000, 4, 1024),
    1_000: RateSpec(1_000, 16_384_000, 32, 512),
}

# Test the added rates first, then every previously supported rate.
DEFAULT_RATE_ORDER = (100_000, 160_000, 250_000, 50_000, 25_000, 5_000, 1_000)
NEW_RATES = {100_000, 160_000}
# NOTE: there is no single "reset default" rate to check against. downsampleInfo()'s
# dpOld fallback (used by ad7768SetSamplingRate(0), which ad7768Reset(0) calls) starts
# out pointing at the 50 kSPS table entry, but is reassigned to whichever rate was most
# recently selected successfully. So resetting the AD7768 after this sweep restores
# whatever rate this script tested *last*, not unconditionally 50 kSPS -- the reset
# check below tracks that explicitly instead of assuming a fixed value.


class TestFailure(RuntimeError):
    pass


def parse_int(value: str) -> int:
    try:
        return int(value, 0)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"{value!r} is not an integer; use decimal or 0x-prefixed hexadecimal"
        ) from exc


def import_leep_client():
    firmware_root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(firmware_root / "bedrock"))
    try:
        from leep.raw import LEEPDevice
    except ImportError as exc:
        raise TestFailure(
            "Cannot import the bundled LEEP client. Install python3-numpy; see "
            "README_sample_rate_test.md."
        ) from exc
    return LEEPDevice


class Board:
    def __init__(self, host: str, port: int, timeout: float):
        LEEPDevice = import_leep_client()
        self.device = LEEPDevice(f"{host}:{port}", timeout=timeout)

    def read(self, address: int) -> int:
        values = self.device.exchange([address])
        return int(values[0]) & 0xFFFF_FFFF

    def read_many(self, addresses: list[int]) -> list[int]:
        values = self.device.exchange(addresses)
        return [int(value) & 0xFFFF_FFFF for value in values]

    def write(self, address: int, value: int) -> None:
        self.device.exchange([address], [value])

    def close(self) -> None:
        self.device.close()


class Console:
    """Small UDP client for the firmware's documented console port."""

    def __init__(self, host: str, port: int, timeout: float):
        self.target = (socket.gethostbyname(host), port)
        self.timeout = timeout
        self.quiet_period = 0.20
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("", 0))
        self.sock.settimeout(0.05)
        # Open the UDP console session. This non-printable byte is ignored by
        # the command parser but makes the board send later console output here.
        self.sock.sendto(b"\x01", self.target)
        time.sleep(0.10)
        self._drain()

    def _drain(self) -> None:
        self.sock.settimeout(0.02)
        while True:
            try:
                self.sock.recvfrom(2048)
            except socket.timeout:
                return

    def command(self, command: str, timeout: float | None = None) -> str:
        deadline = time.monotonic() + (timeout or self.timeout)
        self.sock.sendto(command.encode("ascii") + b"\n", self.target)
        chunks: list[bytes] = []
        last_packet_at: float | None = None

        while time.monotonic() < deadline:
            now = time.monotonic()
            if last_packet_at is None:
                wait = min(0.10, deadline - now)
            else:
                wait = min(self.quiet_period - (now - last_packet_at), deadline - now)
                if wait <= 0:
                    break
            self.sock.settimeout(max(0.01, wait))
            try:
                data, _source = self.sock.recvfrom(2048)
            except socket.timeout:
                continue
            chunks.append(data)
            last_packet_at = time.monotonic()

        if not chunks:
            raise TestFailure(f"No reply from UDP console for command: {command!r}")
        return b"".join(chunks).decode("ascii", errors="replace").replace("\r", "")

    def set_debug_flags(self, flags: int) -> None:
        output = self.command(f"debug {flags:X}")
        match = re.search(r"Debug flags\s+0x([0-9A-Fa-f]+)", output)
        if not match or int(match.group(1), 16) != flags:
            raise TestFailure(
                f"Console did not confirm debug flags 0x{flags:X}. Reply: {output[-500:]!r}"
            )

    def dump_adc_registers(self) -> dict[int, list[int]]:
        # DEBUGFLAG_DUMP_AD7768_REG is a one-shot console action. Firmware
        # clears it immediately after printing the four chips' register values.
        output = self.command(f"debug {DEBUGFLAG_DUMP_AD7768_REG:X}", timeout=12.0)
        registers: dict[int, list[int]] = {}
        for line in output.splitlines():
            parts = line.strip().split()
            if len(parts) != ADC_CHIP_COUNT + 1 or not parts[0].endswith(":"):
                continue
            try:
                address = int(parts[0][:-1], 16)
                values = [int(part, 16) for part in parts[1:]]
            except ValueError:
                continue
            if all(0 <= value <= 0xFF for value in values):
                registers[address] = values

        for address in (0x01, 0x04, 0x09):
            if address not in registers:
                raise TestFailure(
                    f"ADC register dump was incomplete (missing 0x{address:02X}). "
                    f"Console reply tail: {output[-800:]!r}"
                )
        return registers

    def close(self) -> None:
        self.sock.close()


def tftp_get(host: str, filename: str, port: int, timeout: float = 2.0) -> bytes:
    """Fetch one file using a minimal RFC 1350 octet-mode TFTP read."""
    host_ip = socket.gethostbyname(host)
    server = (host_ip, port)
    request = b"\x00\x01" + filename.encode("ascii") + b"\x00octet\x00"
    last_packet, last_target = request, server
    expected_block = 1
    transfer_peer: tuple[str, int] | None = None
    payload = bytearray()
    retries = 0

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(timeout)
        sock.sendto(last_packet, last_target)
        while True:
            try:
                packet, source = sock.recvfrom(2048)
            except socket.timeout:
                retries += 1
                if retries > 5:
                    raise TestFailure(f"TFTP timeout while reading {filename}")
                sock.sendto(last_packet, last_target)
                continue

            if source[0] != host_ip or len(packet) < 4:
                continue
            opcode, block = struct.unpack("!HH", packet[:4])
            if opcode == 5:
                message = packet[4:].split(b"\x00", 1)[0].decode("ascii", "replace")
                raise TestFailure(f"TFTP server error {block}: {message}")
            if opcode == 6:
                raise TestFailure("TFTP server returned OACK despite no options being requested")
            if opcode != 3:
                continue

            if transfer_peer is None:
                transfer_peer = source
            elif source != transfer_peer:
                continue

            data = packet[4:]
            if block == expected_block:
                payload.extend(data)
                ack = struct.pack("!HH", 4, block)
                sock.sendto(ack, transfer_peer)
                last_packet, last_target = ack, transfer_peer
                retries = 0
                if len(data) < 512:
                    return bytes(payload)
                expected_block = (expected_block + 1) & 0xFFFF
            elif block == ((expected_block - 1) & 0xFFFF):
                # The preceding ACK may have been lost; acknowledge the duplicate.
                ack = struct.pack("!HH", 4, block)
                sock.sendto(ack, transfer_peer)
                last_packet, last_target = ack, transfer_peer
                retries = 0


def boot_application(host: str, alluvium_dir: Path | None,
                     wait_seconds: float) -> dict[str, Any]:
    """Use the Alluvium CLI to clear the boot error state and boot the app image."""
    commands = [
        [sys.executable, "-m", "alluvium", host, "clear"],
        [sys.executable, "-m", "alluvium", host, "reboot", "app"],
    ]
    cwd = alluvium_dir.resolve() if alluvium_dir else None
    if cwd is not None and not cwd.is_dir():
        raise TestFailure(f"Alluvium directory does not exist: {cwd}")

    results: list[dict[str, Any]] = []
    for command in commands:
        printable = " ".join(command)
        print(f"Boot: {printable}")
        try:
            completed = subprocess.run(
                command,
                cwd=cwd,
                check=False,
                capture_output=True,
                text=True,
                timeout=20,
            )
        except subprocess.TimeoutExpired as exc:
            raise TestFailure(
                f"Alluvium command timed out: {printable}. Check Alluvium installation "
                "and board connectivity."
            ) from exc
        except OSError as exc:
            raise TestFailure(
                f"Could not run Alluvium ({printable}): {exc}. Install/clone Alluvium "
                "or pass --alluvium-dir with its source directory."
            ) from exc

        result = {
            "command": printable,
            "returncode": completed.returncode,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
        }
        results.append(result)
        if completed.stdout.strip():
            print(completed.stdout.strip())
        if completed.stderr.strip():
            print(completed.stderr.strip(), file=sys.stderr)
        if completed.returncode:
            raise TestFailure(
                f"Alluvium command failed with exit status {completed.returncode}: "
                f"{printable}"
            )

    print(f"Waiting {wait_seconds:g}s for the application image to start...")
    time.sleep(wait_seconds)
    return {"commands": results, "startup_wait_seconds": wait_seconds}


def analyze_drdy_capture(data: bytes, spec: RateSpec, tolerance_percent: float) -> list[dict[str, Any]]:
    if len(data) != RECORDER_FILE_BYTES:
        raise TestFailure(
            f"DRDY capture has {len(data)} bytes; expected {RECORDER_FILE_BYTES}"
        )

    samples = struct.unpack(f"<{RECORDER_SAMPLE_COUNT}H", data)
    if any(sample & ~0x1FF for sample in samples):
        raise TestFailure("DRDY capture contains bits outside the 9-bit recorder word")
    # Analyze only the settled leading portion of the buffer.
    samples = samples[:DRDY_ANALYSIS_SAMPLE_COUNT]

    measurements = []
    for chip in range(ADC_CHIP_COUNT):
        mask = 1 << chip  # Recorder word bits 0..3 are DRDY[0..3].
        rising_edges = []
        previous = samples[0] & mask
        for index, sample in enumerate(samples[1:], start=1):
            current = sample & mask
            if current and not previous:
                rising_edges.append(index)
            previous = current

        intervals = [right - left for left, right in zip(rising_edges, rising_edges[1:])]
        if len(intervals) < 20:
            raise TestFailure(
                f"ADC chip {chip} produced only {len(rising_edges)} DRDY rising edges "
                f"at {spec.rate_hz} SPS; expected at least 21"
            )

        average_cycles = statistics.mean(intervals)
        measured_hz = ACQ_CLOCK_HZ / average_cycles
        error_percent = abs(measured_hz - spec.rate_hz) * 100.0 / spec.rate_hz
        if error_percent > tolerance_percent:
            raise TestFailure(
                f"ADC chip {chip} DRDY rate {measured_hz:.2f} SPS is "
                f"{error_percent:.3f}% from {spec.rate_hz} SPS"
            )

        measurements.append({
            "chip": chip,
            "rising_edges": len(rising_edges),
            "mean_period_acq_clocks": average_cycles,
            "measured_rate_hz": measured_hz,
            "error_percent": error_percent,
        })

    return measurements


def check_rate_formula() -> None:
    for rate, spec in RATE_SPECS.items():
        if spec.rate_hz != rate or spec.calculated_rate_hz != rate:
            raise TestFailure(f"Internal rate table formula mismatch for {rate} SPS")


def validate_adc_configuration(spec: RateSpec, registers: dict[int, list[int]]) -> None:
    expected_mode = spec.channel_mode
    expected_power = spec.power_mode_register
    observed_modes = registers[0x01]
    observed_power = registers[0x04]
    if observed_modes != [expected_mode] * ADC_CHIP_COUNT:
        raise TestFailure(
            f"{spec.rate_hz} SPS expects AD7768 R1={expected_mode:02X} on all chips; "
            f"read {[f'{value:02X}' for value in observed_modes]}"
        )
    if observed_power != [expected_power] * ADC_CHIP_COUNT:
        raise TestFailure(
            f"{spec.rate_hz} SPS expects AD7768 R4={expected_power:02X} on all chips; "
            f"read {[f'{value:02X}' for value in observed_power]}"
        )


def check_adc_status(status_word: int, allow_no_clock: bool = False) -> list[int]:
    statuses = [(status_word >> (8 * (ADC_CHIP_COUNT - chip - 1))) & 0xFF
                for chip in range(ADC_CHIP_COUNT)]
    error_mask = 0x09 | (0 if allow_no_clock else 0x04)
    failures = [chip for chip, status in enumerate(statuses) if status & error_mask]
    if failures:
        details = ", ".join(f"chip {chip}=0x{statuses[chip]:02X}" for chip in failures)
        raise TestFailure(
            "AD7768 reports CHIP_ERROR (bit 3), "
            + ("" if allow_no_clock else "NO_CLOCK_ERROR (bit 2), ")
            + "or RAM_BIST_RUNNING (bit 0): " + details
        )
    return statuses


def wait_recorder(board: Board, timeout: float) -> None:
    # REG_AD7768_RECORDER reads ad7768recorderIsBusy(), a plain C boolean
    # (0 or 1) -- NOT a bit-31 flag on the raw recorder CSR. (epics.c's
    # readReg() returns that function's result directly.)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if board.read(REG_AD7768_RECORDER) == 0:
            return
        time.sleep(0.05)
    raise TestFailure(
        "DRDY recorder did not complete. The arm/trigger sequence may not have "
        "reached the FPGA; check board timing and ADC wiring."
    )


def trigger_recorder(board: Board, timeout: float) -> None:
    """Arm the DRDY/DCLK recorder, then force a deterministic trigger.

    ad7768recorder.v's state machine: the first CSR write (bit 31 set, which
    toggles sysArmToggle) takes it from ST_IDLE through ST_FILL (recording
    starts immediately) to ST_AWAIT_TRIGGER once PRE_TRIGGER_LOAD acqClk
    cycles have elapsed (~0.92ms at 125MHz). ST_AWAIT_TRIGGER triggers on
    EITHER a real DRDY misalignment OR another sysArmToggle edge -- so a
    second CSR write, issued after waiting comfortably past that ~0.92ms
    fill period, deterministically triggers a capture of purely normal,
    steady-state DRDY activity without needing to induce a real fault.
    """
    board.write(REG_AD7768_RECORDER, 1)
    time.sleep(RECORDER_ARM_TO_TRIGGER_DELAY_S)
    board.write(REG_AD7768_RECORDER, 1)
    wait_recorder(board, timeout)


def wait_for_rate(board: Board, spec: RateSpec, align_before: int,
                  timeout: float, mclk_tolerance_percent: float) -> dict[str, int]:
    deadline = time.monotonic() + timeout
    last = {"align_count": align_before, "drdy_status": 0, "mclk_hz": 0}
    while time.monotonic() < deadline:
        align_count, drdy_status, mclk_hz = board.read_many(
            [REG_ADC_ALIGNMENT_COUNT, REG_DRDY_STATUS, REG_AD7768_MCLK_HZ]
        )
        last = {
            "align_count": align_count,
            "drdy_status": drdy_status,
            "mclk_hz": mclk_hz,
        }
        alignment_delta = (align_count - align_before) & 0xFFFF_FFFF
        mclk_error = abs(mclk_hz - spec.mclk_hz) * 100.0 / spec.mclk_hz
        if (alignment_delta >= 2
                and not (drdy_status & GPIO_DRDY_MISALIGNED)
                and mclk_error <= mclk_tolerance_percent):
            return last
        time.sleep(0.10)

    raise TestFailure(
        f"{spec.rate_hz} SPS did not settle within {timeout:g}s. "
        f"Alignment count {last['align_count']} (started {align_before}), "
        f"DRDY status 0x{last['drdy_status']:08X}, "
        f"MCLK {last['mclk_hz']} Hz (expected {spec.mclk_hz}). "
        "This test requires a working PPS/timing reference."
    )


def print_rate_result(spec: RateSpec, observed: dict[str, int],
                      drdy: list[dict[str, Any]] | None) -> None:
    print(
        f"PASS {spec.rate_hz:6d} SPS | MCLK {observed['mclk_hz']:>9,d} Hz | "
        f"decimation {spec.decimation:4d} | AD7768 mode 0x{spec.channel_mode:02X}"
    )
    if drdy:
        for result in drdy:
            print(
                f"     DRDY chip {result['chip']}: {result['measured_rate_hz']:.2f} SPS "
                f"({result['error_percent']:.3f}% error, "
                f"{result['rising_edges']} edges)"
            )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Exercise every Quartz AD7768 sample-rate setting on a live board."
    )
    parser.add_argument("--host", required=True, help="Quartz IPv4 address or hostname")
    parser.add_argument("--port", type=int, default=50006, help="LEEP UDP port")
    parser.add_argument("--console-port", type=int, default=55002,
                        help="firmware console UDP port")
    parser.add_argument("--tftp-port", type=int, default=69, help="TFTP UDP port")
    parser.add_argument("--restore-rate", type=int, choices=sorted(RATE_SPECS), required=True,
                        help="rate to leave on the board (rate is write-only in firmware)")
    parser.add_argument("--restore-debug-flags", type=parse_int, required=True,
                        help="runtime debug mask to leave on the board, e.g. 0x0")
    parser.add_argument("--rates", type=int, nargs="+", choices=sorted(RATE_SPECS),
                        default=list(DEFAULT_RATE_ORDER),
                        help="rates to exercise (default: all seven supported rates)")
    parser.add_argument("--expect-software-build-date", type=parse_int,
                        help="optional expected softwareBuildDate register value")
    parser.add_argument("--expect-codehash",
                        help="optional expected LEEP code hash from the built image")
    parser.add_argument("--timeout", type=float, default=12.0,
                        help="per-rate alignment/MCLK settle timeout in seconds")
    parser.add_argument("--network-timeout", type=float, default=2.0,
                        help="UDP/TFTP packet timeout in seconds")
    parser.add_argument("--mclk-tolerance-percent", type=float, default=1.0,
                        help="allowed measured MCLK error")
    parser.add_argument("--drdy-tolerance-percent", type=float, default=2.0,
                        help="allowed measured DRDY sample-rate error")
    parser.add_argument("--output-dir", type=Path,
                        help="directory for DRDY captures and JSON report")
    parser.add_argument("--boot-app", action="store_true",
                        help="before testing, run Alluvium 'clear' and 'reboot app' (reboots the board)")
    parser.add_argument("--alluvium-dir", type=Path,
                        help="working directory for 'python -m alluvium' (default: current directory)")
    parser.add_argument("--boot-wait", type=float, default=30.0,
                        help="seconds to wait after rebooting the app image (default: 30)")
    parser.add_argument("--yes", action="store_true",
                        help="skip the live-board confirmation prompt")
    args = parser.parse_args()

    try:
        check_rate_formula()
        if args.timeout <= 0 or args.network_timeout <= 0:
            raise TestFailure("timeouts must be positive")
        if args.boot_wait < 0:
            raise TestFailure("boot wait must be non-negative")
        if args.alluvium_dir is not None and not args.alluvium_dir.is_dir():
            raise TestFailure(f"Alluvium directory does not exist: {args.alluvium_dir}")
        if not 0 < args.mclk_tolerance_percent <= 10:
            raise TestFailure("MCLK tolerance must be between 0 and 10 percent")
        if not 0 < args.drdy_tolerance_percent <= 10:
            raise TestFailure("DRDY tolerance must be between 0 and 10 percent")
        if args.restore_debug_flags < 0 or args.restore_debug_flags > 0x7FFF_FFFF:
            raise TestFailure("restore debug mask must be a non-negative 31-bit value")
        if args.restore_debug_flags & DEBUGFLAG_ONESHOT_MASK:
            raise TestFailure(
                "restore debug mask includes a one-shot action; remove those bits before testing"
            )
        if args.restore_debug_flags & DEBUGFLAG_ENABLE_DRDY_FAULT:
            raise TestFailure(
                "restore debug mask must not leave ENABLE_DRDY_FAULT set"
            )
        if len(set(args.rates)) != len(args.rates):
            raise TestFailure("--rates contains duplicate values")
        if not NEW_RATES.issubset(set(args.rates)):
            raise TestFailure("full test requires both new rates: 100000 and 160000")
    except TestFailure as exc:
        parser.error(str(exc))

    output_dir = args.output_dir or Path(
        "sample-rate-test-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    )
    prompt = (
        f"Run the sample-rate test on {args.host}? "
        + ("It first clears the boot error state and reboots into the app image. "
           if args.boot_app else "")
        + "It briefly resets the AD7768 chips, "
        "changes ADC rate and syncs, and for each new rate arms and triggers "
        "the FPGA's DRDY recorder to independently measure the physical "
        "sample cadence. It restores the requested rate "
        f"({args.restore_rate} SPS) and debug mask (0x{args.restore_debug_flags:X})."
    )
    if args.yes:
        print(prompt)
    else:
        if not sys.stdin.isatty():
            print("Refusing non-interactive hardware changes without --yes.", file=sys.stderr)
            return 2
        print(prompt)
        if input("Type 'yes' to continue: ").strip().lower() != "yes":
            print("Cancelled.")
            return 2

    output_dir.mkdir(parents=True, exist_ok=True)
    report: dict[str, Any] = {
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "host": args.host,
        "tested_rates_hz": list(args.rates),
        "restore_rate_hz": args.restore_rate,
        "restore_debug_flags": args.restore_debug_flags,
        "boot_app_requested": args.boot_app,
        "rate_results": [],
        "cleanup_errors": [],
    }
    board: Board | None = None
    console: Console | None = None
    rate_write_attempted = False
    recorder_may_be_active = False
    reset_may_be_active = False
    debug_flags_touched = False
    test_error: str | None = None

    def set_debug(flags: int) -> None:
        nonlocal debug_flags_touched
        if console is None:
            raise TestFailure("UDP console is not connected")
        debug_flags_touched = True
        console.set_debug_flags(flags)

    try:
        if args.boot_app:
            report["boot"] = boot_application(
                args.host, args.alluvium_dir, args.boot_wait
            )
        board = Board(args.host, args.port, args.network_timeout)
        console = Console(args.host, args.console_port, args.network_timeout)

        rate_info = board.device.regmap.get("ACQ:rate", {})
        if int(rate_info.get("base_addr", -1)) != REG_SAMPLING_RATE:
            raise TestFailure("Device LEEP ROM does not expose the expected Quartz ACQ:rate register")
        if "w" not in rate_info.get("access", ""):
            raise TestFailure("Device LEEP ROM marks ACQ:rate as non-writable")

        fw_date, sw_date, uptime, reset_state, drdy_status, adc_status, recorder_status = (
            board.read_many([
                REG_FIRMWARE_BUILD_DATE,
                REG_SOFTWARE_BUILD_DATE,
                REG_UPTIME,
                REG_AD7768_RESET,
                REG_DRDY_STATUS,
                REG_AD7768_STATUSES,
                REG_AD7768_RECORDER,
            ])
        )
        report["firmware_build_date"] = fw_date
        report["software_build_date"] = sw_date
        report["codehash"] = str(board.device.codehash)
        report["device_description"] = str(board.device.descript)
        report["uptime_seconds"] = uptime
        print(f"Device: {report['device_description']}")
        print(f"Build dates: FPGA={fw_date}, software={sw_date}; code hash={report['codehash']}")
        print(f"Uptime: {uptime} seconds; LEEP rate register: {rate_info}")

        if args.expect_software_build_date is not None and sw_date != args.expect_software_build_date:
            raise TestFailure(
                f"softwareBuildDate is {sw_date}; expected {args.expect_software_build_date}"
            )
        if args.expect_codehash:
            expected_hash = args.expect_codehash.lower().removeprefix("0x").strip()
            actual_hash = str(board.device.codehash).lower().removeprefix("0x").strip()
            if actual_hash != expected_hash:
                raise TestFailure(f"code hash {actual_hash} does not match {expected_hash}")
        if reset_state != 0:
            raise TestFailure("AD7768 is in reset; refusing to change sample rate")
        if recorder_status != 0:
            raise TestFailure("AD7768 DRDY recorder is already active; refusing to disturb it")
        initial_statuses = check_adc_status(adc_status, allow_no_clock=True)
        if any(status & 0x04 for status in initial_statuses):
            print("Warning: an ADC reported NO_CLOCK_ERROR before the rate sweep; "
                  "each programmed rate must clear it.")
        if drdy_status & GPIO_DRDY_MISALIGNED:
            print("Warning: DRDY was misaligned before the test; each tested rate must clear it.")

        last_rate = None
        for rate in args.rates:
            spec = RATE_SPECS[rate]
            drdy_result = None
            align_before = board.read(REG_ADC_ALIGNMENT_COUNT)

            rate_write_attempted = True
            board.write(REG_SAMPLING_RATE, rate)

            observed = wait_for_rate(
                board,
                spec,
                align_before=align_before,
                timeout=args.timeout,
                mclk_tolerance_percent=args.mclk_tolerance_percent,
            )

            # The one-shot register dump confirms the programmed decimation and
            # power mode on all four physical AD7768 chips.
            adc_status = board.read(REG_AD7768_STATUSES)
            chip_statuses = check_adc_status(adc_status)
            registers = console.dump_adc_registers()
            validate_adc_configuration(spec, registers)

            if rate in NEW_RATES:
                # Independently confirm the physical DRDY cadence for the new
                # rates by capturing the FPGA's logic-analyzer recorder, once
                # the rate above has already settled into steady state. See
                # trigger_recorder() for how the deterministic (non-fault)
                # trigger works.
                recorder_may_be_active = True
                trigger_recorder(board, args.timeout)
                recorder_may_be_active = False

                capture = tftp_get(
                    args.host, "AD7768_DRDY.bin", args.tftp_port, args.network_timeout
                )
                if len(capture) != RECORDER_FILE_BYTES:
                    raise TestFailure(
                        f"TFTP recorder file is {len(capture)} bytes; "
                        f"expected {RECORDER_FILE_BYTES}"
                    )
                capture_path = output_dir / f"AD7768_DRDY_{rate}.bin"
                capture_path.write_bytes(capture)
                drdy_result = analyze_drdy_capture(
                    capture, spec, args.drdy_tolerance_percent
                )

            result = {
                "rate_hz": rate,
                "mclk_hz": observed["mclk_hz"],
                "decimation": spec.decimation,
                "channel_mode": spec.channel_mode,
                "power_mode_register": spec.power_mode_register,
                "adc_status_bytes": chip_statuses,
                "drdy": drdy_result,
            }
            report["rate_results"].append(result)
            print_rate_result(spec, observed, drdy_result)
            last_rate = rate

        # Exercise the ADC-reset initialization path after cycling rates.
        # ad7768SetSamplingRate(0) (called by ad7768Reset(0)) restores
        # whichever rate was selected last, NOT a fixed default (see the
        # NEW_RATES/dpOld comment above) -- so verify against last_rate.
        if last_rate is None:
            raise TestFailure("No sampling rate was successfully verified before the reset test")
        reset_rate = last_rate
        reset_spec = RATE_SPECS[reset_rate]
        align_before = board.read(REG_ADC_ALIGNMENT_COUNT)
        rate_write_attempted = True  # Ensure cleanup restores after any reset error.
        reset_may_be_active = True
        board.write(REG_AD7768_RESET, 1)
        if board.read(REG_AD7768_RESET) != 1:
            raise TestFailure("AD7768 reset did not assert")
        board.write(REG_AD7768_RESET, 0)
        if board.read(REG_AD7768_RESET) != 0:
            raise TestFailure("AD7768 reset did not release")
        reset_may_be_active = False
        reset_observed = wait_for_rate(
            board, reset_spec, align_before, args.timeout,
            args.mclk_tolerance_percent,
        )
        reset_statuses = check_adc_status(board.read(REG_AD7768_STATUSES))
        reset_registers = console.dump_adc_registers()
        validate_adc_configuration(reset_spec, reset_registers)
        report["reset_restore_check"] = {
            "rate_hz": reset_rate,
            "mclk_hz": reset_observed["mclk_hz"],
            "decimation": reset_spec.decimation,
            "channel_mode": reset_spec.channel_mode,
            "power_mode_register": reset_spec.power_mode_register,
            "adc_status_bytes": reset_statuses,
        }
        print_rate_result(reset_spec, reset_observed, None)
        print(f"     AD7768 reset path restored the previously selected "
              f"{reset_rate} SPS rate.")

        report["test_passed"] = True

    except KeyboardInterrupt:
        test_error = "Interrupted by operator"
    except Exception as exc:  # Keep cleanup in the same process after any test failure.
        test_error = f"{type(exc).__name__}: {exc}"
        print(f"FAIL: {test_error}", file=sys.stderr)
    finally:
        if board is not None and reset_may_be_active:
            try:
                board.write(REG_AD7768_RESET, 0)
                if board.read(REG_AD7768_RESET) != 0:
                    raise TestFailure("AD7768 reset remains asserted")
                reset_may_be_active = False
            except Exception as exc:
                report["cleanup_errors"].append(f"Could not release AD7768 reset: {exc}")
                print(f"CLEANUP ERROR releasing AD7768 reset: {exc}", file=sys.stderr)

        if board is not None and recorder_may_be_active:
            try:
                # trigger_recorder() didn't complete (e.g. a dropped UDP
                # packet ate its second arm write while the recorder sat in
                # ST_AWAIT_TRIGGER). One more toggle write forces a trigger
                # from there; harmless if it's actually stuck elsewhere.
                board.write(REG_AD7768_RECORDER, 1)
                wait_recorder(board, min(args.timeout, 5.0))
                recorder_may_be_active = False
            except Exception as exc:
                report["cleanup_errors"].append(
                    f"Could not finish active recorder during cleanup: {exc}"
                )

        if board is not None and rate_write_attempted:
            if console is not None:
                try:
                    set_debug(0)
                except Exception as exc:
                    report["cleanup_errors"].append(
                        f"Could not clear temporary debug flags before restore: {exc}"
                    )
            try:
                restore_spec = RATE_SPECS[args.restore_rate]
                align_before = board.read(REG_ADC_ALIGNMENT_COUNT)
                board.write(REG_SAMPLING_RATE, args.restore_rate)
                restored = wait_for_rate(
                    board, restore_spec, align_before, args.timeout,
                    args.mclk_tolerance_percent
                )
                if console is None:
                    raise TestFailure("UDP console unavailable for ADC register verification")
                statuses = check_adc_status(board.read(REG_AD7768_STATUSES))
                registers = console.dump_adc_registers()
                validate_adc_configuration(restore_spec, registers)
                report["restored_rate_hz"] = args.restore_rate
                report["restored_mclk_hz"] = restored["mclk_hz"]
                report["restored_adc_status_bytes"] = statuses
                print(
                    f"Restored {args.restore_rate} SPS; MCLK {restored['mclk_hz']:,} Hz; "
                    "ADC alignment and register readback pass."
                )
            except Exception as exc:
                report["cleanup_errors"].append(f"Could not restore sample rate: {exc}")
                print(f"CLEANUP ERROR restoring rate: {exc}", file=sys.stderr)

        if console is not None and (debug_flags_touched or rate_write_attempted):
            try:
                set_debug(args.restore_debug_flags)
                report["restored_debug_flags"] = args.restore_debug_flags
            except Exception as exc:
                report["cleanup_errors"].append(f"Could not restore runtime debug flags: {exc}")
                print(f"CLEANUP ERROR restoring debug flags: {exc}", file=sys.stderr)

        if board is not None:
            board.close()
        if console is not None:
            console.close()

        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        report["test_error"] = test_error
        report["test_passed"] = (
            bool(report.get("test_passed"))
            and not test_error
            and not report["cleanup_errors"]
        )
        report_path = output_dir / "report.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Report: {report_path.resolve()}")

    if test_error or report["cleanup_errors"]:
        return 1
    print("PASS: all requested sample rates verified on the board.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
