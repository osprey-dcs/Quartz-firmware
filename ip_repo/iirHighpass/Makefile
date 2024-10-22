TEST_SOURCE = iirHighpass_tb.v iirHighpass.v

all: iirHighpass_tb.vvp

iirHighpass_tb.vvp: $(TEST_SOURCE)
	iverilog -Wall -o iirHighpass_tb.vvp $(TEST_SOURCE)

iirHighpass_tb.lxt: iirHighpass_tb.vvp
	vvp iirHighpass_tb.vvp -lxt2

test: iirHighpass_tb.vvp
	vvp iirHighpass_tb.vvp -lxt2

view: iirHighpass_tb.lxt
	-open /Applications/gtkwave.app iirHighpass_tb.gtkw
	-gtkwave iirHighpass_tb.lxt iirHighpass_tb.gtkw &

clean:
	rm -rf a.out test.dat *.vvp *.lxt *.dat
