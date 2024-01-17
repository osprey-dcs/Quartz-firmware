TEST_SOURCE = ../../hdl/ad7768.v ad7768_tb.v
	
all: ad7768_tb.vvp

ad7768_tb.vvp: $(TEST_SOURCE)
	iverilog -o ad7768_tb.vvp $(TEST_SOURCE)

test: ad7768_tb.vvp
	vvp ad7768_tb.vvp -fst >test.dat

ad7768_tb.fst:  ad7768_tb.vvp
	vvp  ad7768_tb.vvp -fst >test.dat

view:  ad7768_tb.fst force
	-gtkwave ad7768_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
