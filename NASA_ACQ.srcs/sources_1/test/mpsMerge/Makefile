TEST_SOURCE = ../../hdl/mpsMerge.v \
              mpsMerge_tb.v 
	
all: mpsMerge_tb.vvp

mpsMerge_tb.vvp: $(TEST_SOURCE)
	iverilog -Wall -o mpsMerge_tb.vvp $(TEST_SOURCE)

test: mpsMerge_tb.vvp
	vvp mpsMerge_tb.vvp -fst >test.dat

mpsMerge_tb.fst:  mpsMerge_tb.vvp
	vvp  mpsMerge_tb.vvp -fst >test.dat

view:  mpsMerge_tb.fst force
	-gtkwave mpsMerge_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
