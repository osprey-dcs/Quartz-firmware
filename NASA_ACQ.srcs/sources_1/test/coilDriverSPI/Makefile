TEST_SOURCE = ../../hdl/coilDriverSPI.v coilDriverSPI_tb.v
	
all: coilDriverSPI_tb.vvp

coilDriverSPI_tb.vvp: $(TEST_SOURCE)
	iverilog -o coilDriverSPI_tb.vvp $(TEST_SOURCE)

test: coilDriverSPI_tb.vvp
	vvp coilDriverSPI_tb.vvp -fst >test.dat

coilDriverSPI_tb.fst:  coilDriverSPI_tb.vvp
	vvp  coilDriverSPI_tb.vvp -fst >test.dat

view:  coilDriverSPI_tb.fst force
	-gtkwave coilDriverSPI_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
