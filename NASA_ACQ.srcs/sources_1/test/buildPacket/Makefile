TEST_SOURCE = ../../hdl/buildPacket.v buildPacket_tb.v
	
all: buildPacket_tb.vvp

buildPacket_tb.vvp: $(TEST_SOURCE)
	iverilog -o buildPacket_tb.vvp $(TEST_SOURCE)

test: buildPacket_tb.vvp
	vvp buildPacket_tb.vvp -lxt2 >test.dat

buildPacket_tb.lxt:  buildPacket_tb.vvp
	vvp  buildPacket_tb.vvp -lxt2 >test.dat

view:  buildPacket_tb.lxt force
	-open /Applications/gtkwave.app buildPacket_tb.gtkw 
	-gtkwave buildPacket_tb.gtkw &

force:

clean:
	rm -f *.vvp *.lxt *.dat
