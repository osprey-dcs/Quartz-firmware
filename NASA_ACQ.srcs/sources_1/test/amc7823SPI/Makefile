TEST_SOURCE = ../../hdl/amc7823SPI.v amc7823SPI_tb.v
	
all: amc7823SPI_tb.vvp

amc7823SPI_tb.vvp: $(TEST_SOURCE)
	iverilog -o amc7823SPI_tb.vvp $(TEST_SOURCE)

test: amc7823SPI_tb.vvp
	vvp amc7823SPI_tb.vvp -fst >test.dat

amc7823SPI_tb.fst:  amc7823SPI_tb.vvp
	vvp  amc7823SPI_tb.vvp -fst >test.dat

view:  amc7823SPI_tb.fst force
	-gtkwave amc7823SPI_tb.gtkw &

force:

clean:
	rm -f *.vvp *.fst *.dat
