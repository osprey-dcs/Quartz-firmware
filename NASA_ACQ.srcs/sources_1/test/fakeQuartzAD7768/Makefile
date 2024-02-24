TEST_SOURCE = ../../hdl/fakeQuartzAD7768.v fakeQuartzAD7768_tb.v
	
all: fakeQuartzAD7768_tb.vvp

fakeQuartzAD7768_tb.vvp: $(TEST_SOURCE)
	iverilog -o fakeQuartzAD7768_tb.vvp $(TEST_SOURCE)

test: fakeQuartzAD7768_tb.vvp
	vvp fakeQuartzAD7768_tb.vvp -fst >test.dat

fakeQuartzAD7768_tb.fst:  fakeQuartzAD7768_tb.vvp
	vvp  fakeQuartzAD7768_tb.vvp -fst >test.dat

view:  fakeQuartzAD7768_tb.fst force
	-gtkwave fakeQuartzAD7768_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
