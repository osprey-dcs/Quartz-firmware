// Minimal code to instantiate Quartz-specific firmware

`define QUARTZ_VERSION_2
`define QUARTZ_COMPATABILITY_BITMAP 32'b00000010
`define QUARTZ_AD7768_SYNC_LATENCY  2
`include "../hdl/NASA_ACQ_TOP.v"
