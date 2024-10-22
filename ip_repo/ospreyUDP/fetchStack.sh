#!/bin/sh

# Fetch Ethernet-in-fabric source

SRCDIR="../../EthernetInCore/verilog-ethernet"
DEST="hdl/udpStack.v"

for f in rtl/iddr.v \
         rtl/oddr.v \
         rtl/ssio_ddr_in.v \
         rtl/rgmii_phy_if.v \
         rtl/eth_mac_1g_rgmii_fifo.v \
         rtl/eth_mac_1g_rgmii.v \
         rtl/eth_mac_1g.v \
         rtl/axis_gmii_rx.v \
         rtl/axis_gmii_tx.v \
         rtl/lfsr.v \
         rtl/eth_axis_rx.v \
         rtl/eth_axis_tx.v \
         rtl/udp_complete.v \
         rtl/udp_checksum_gen.v \
         rtl/udp.v \
         rtl/udp_ip_rx.v \
         rtl/udp_ip_tx.v \
         rtl/ip_complete.v \
         rtl/ip.v \
         rtl/ip_eth_rx.v \
         rtl/ip_eth_tx.v \
         rtl/ip_arb_mux.v \
         rtl/arp.v \
         rtl/arp_cache.v \
         rtl/arp_eth_rx.v \
         rtl/arp_eth_tx.v \
         rtl/eth_arb_mux.v \
         lib/axis/rtl/arbiter.v \
         lib/axis/rtl/priority_encoder.v \
         lib/axis/rtl/axis_fifo.v \
         lib/axis/rtl/axis_async_fifo.v \
         lib/axis/rtl/axis_async_fifo_adapter.v
do
    echo "/* ===== $SRCDIR/$f ===== */"
    cat "$SRCDIR/$f"
done >"$DEST"

