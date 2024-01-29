TEST_SOURCE = ../../hdl/hwPPSselect.v hwPPSselect_tb.v
	
all: hwPPSselect_tb.vvp

hwPPSselect_tb.vvp: $(TEST_SOURCE)
	iverilog -o hwPPSselect_tb.vvp $(TEST_SOURCE)

test: hwPPSselect_tb.vvp
	vvp hwPPSselect_tb.vvp -fst >test.dat

hwPPSselect_tb.fst:  hwPPSselect_tb.vvp
	vvp  hwPPSselect_tb.vvp -fst >test.dat

view:  hwPPSselect_tb.fst force
	-gtkwave hwPPSselect_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
