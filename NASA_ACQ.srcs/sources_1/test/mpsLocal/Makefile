TEST_SOURCE = ../../hdl/mpsLocal.v \
              mpsLocal_tb.v 
	
all: mpsLocal_tb.vvp

mpsLocal_tb.vvp: $(TEST_SOURCE)
	iverilog -Wall -o mpsLocal_tb.vvp $(TEST_SOURCE)

test: mpsLocal_tb.vvp
	vvp mpsLocal_tb.vvp -fst >test.dat

mpsLocal_tb.fst:  mpsLocal_tb.vvp
	vvp  mpsLocal_tb.vvp -fst >test.dat

view:  mpsLocal_tb.fst force
	-gtkwave mpsLocal_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
