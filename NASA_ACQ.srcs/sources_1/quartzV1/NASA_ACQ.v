// Minimal code to instantiate Quartz-specific firmware

`define QUARTZ_VERSION_1
`define QUARTZ_COMPATABILITY_BITMAP 32'b00000101
`define QUARTZ_AD7768_SYNC_LATENCY  0
`include "../hdl/NASA_ACQ_TOP.v"
