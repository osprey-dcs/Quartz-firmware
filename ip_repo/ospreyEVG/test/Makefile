TEST_SOURCE = ../hdl/evgSequencer.v evgSequencer_tb.v
	
all: evgSequencer_tb.vvp

evgSequencer_tb.vvp: $(TEST_SOURCE)
	iverilog -o evgSequencer_tb.vvp $(TEST_SOURCE)

test: evgSequencer_tb.vvp
	vvp evgSequencer_tb.vvp -fst >test.dat

evgSequencer_tb.fst:  evgSequencer_tb.vvp
	vvp  evgSequencer_tb.vvp -fst >test.dat

view:  evgSequencer_tb.fst force
	-gtkwave evgSequencer_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
