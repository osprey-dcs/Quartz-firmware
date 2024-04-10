TEST_SOURCE = ../../hdl/mergeLimitExcursions.v \
              mergeLimitExcursions_tb.v 
	
all: mergeLimitExcursions_tb.vvp

mergeLimitExcursions_tb.vvp: $(TEST_SOURCE)
	iverilog -o mergeLimitExcursions_tb.vvp $(TEST_SOURCE)

test: mergeLimitExcursions_tb.vvp
	vvp mergeLimitExcursions_tb.vvp -fst >test.dat

mergeLimitExcursions_tb.fst:  mergeLimitExcursions_tb.vvp
	vvp  mergeLimitExcursions_tb.vvp -fst >test.dat

view:  mergeLimitExcursions_tb.fst force
	-gtkwave mergeLimitExcursions_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
