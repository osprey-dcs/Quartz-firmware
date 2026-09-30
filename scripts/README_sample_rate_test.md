# Quartz sample-rate hardware test (Ubuntu 24.04)

`verify_sample_rates.py` tests the Quartz AD7768 sample-rate path on a live board. It does not program flash or start the acquisition data stream. By default it does not reboot the board. With the optional `--boot-app` flag, it uses Alluvium to clear the boot error state and reboot into the application image before testing. It briefly resets the AD7768 chips to check that reset correctly restores the ADC's sampling configuration, then restores the requested rate at the end.

## Checks performed

By default, the script exercises all seven supported rates: 250, 160, 100, 50, 25, 5, and 1 kSPS. After the sweep, it resets the AD7768 chips and checks that reset restores whichever rate was tested *last* in the sweep -- the firmware's reset-restore fallback (`downsampleInfo()`'s `dpOld`) tracks the most recently selected rate, not a fixed value, so there is no single "reset default" to check against once any rate has been selected. At each rate it checks that:

- The firmware accepts the rate and selects the expected MCLK.
- ADC alignment completes and the DRDY alignment fault clears.
- The measured MCLK is within the configured tolerance.
- AD7768 registers 0x01 (decimation mode) and 0x04 (power/MCLK divider) match on all four ADC chips.
- The AD7768 status has no chip-error or missing-clock bits.

For the new 100 and 160 kSPS rates, it also arms the FPGA DRDY recorder and deterministically triggers a capture (two register writes timed around the recorder's own pre-trigger fill period -- no real DRDY fault is induced), downloads `AD7768_DRDY.bin` using TFTP, and measures the DRDY period for all four chips. Raw captures and `report.json` are saved in a timestamped output directory.

The test requires a working PPS/timing reference, because the firmware synchronizes the ADCs to PPS during rate changes. Run it on a test board when disrupting the ADC sample rate is acceptable. Pause acquisition consumers that require a stable rate; rate changes and SPI register reads will interrupt normal ADC data flow. Keep other rate-control/console users off the board during the test, and do not run another TFTP transfer at the same time.

## Install and run

From the repository root on Ubuntu 24.04:

```sh
sudo apt update
sudo apt install python3-numpy
cd Quartz-firmware-100ksps/Workspace/NASA_ACQ
/usr/bin/python3 scripts/verify_sample_rates.py \
  --host 192.168.79.1 \
  --restore-rate 50000 \
  --restore-debug-flags 0x0
```

Replace the address and restore rate with the board and rate you want left configured. Firmware does not expose a readback for the current sample rate, so the script requires `--restore-rate` rather than guessing. As a safety measure it always sets a known runtime debug mask before restoring the rate at the end, regardless of whether it changed anything during the run; `--restore-debug-flags` is the mask to leave the board with. Use `0x0` for the usual no-debug-flags setting, or pass the desired mask in hexadecimal.

### Boot the application without starting an IOC

If the chassis is currently running the Golden image, the script can boot the application itself. This uses the same Alluvium commands documented in the Quartz IOC setup guide: `clear`, followed by `reboot app`. The Alluvium Python module must be available to `/usr/bin/python3`; point `--alluvium-dir` at the Alluvium checkout so the module can be run from that directory:

```sh
/usr/bin/python3 scripts/verify_sample_rates.py \
  --host 192.168.79.32 \
  --restore-rate 50000 \
  --restore-debug-flags 0x0 \
  --boot-app \
  --alluvium-dir ~/alluvium
```

The script asks for confirmation before rebooting. It waits 30 seconds after `reboot app`, then connects to the application LEEP and console endpoints and starts the test. Adjust that delay with `--boot-wait` if this board takes longer to initialize. This boot option requires no IOC; without `--boot-app`, the application must already be running.

To require a particular running software build, pass the value from that build's `softwareBuildDate.h`:

```sh
/usr/bin/python3 scripts/verify_sample_rates.py \
  --host 192.168.79.1 \
  --restore-rate 50000 \
  --restore-debug-flags 0x0 \
  --expect-software-build-date 1720000000
```

The exact build-date value above is only an example. `--expect-codehash` is also available if you have the expected LEEP code hash.

The script prompts before touching hardware. Add `--yes` to skip that prompt for a controlled automated run. Pressing Ctrl-C runs cleanup; a forced process kill or loss of connectivity can prevent the rate and debug mask from being restored.

## Network ports

The test host must be able to reach the board over UDP on LEEP port 50006, console port 55002, and TFTP port 69. Override these with `--port`, `--console-port`, and `--tftp-port` when needed.
