VIVADO = ${HOME}/Xilinx/2023.1/Vivado/2023.1/data/verilog/src
TEST_SOURCE = ospreyUDP.v udpStack.v \
    ${VIVADO}/unisims/BUFIO.v \
    ${VIVADO}/unisims/BUFR.v \
    ${VIVADO}/unisims/IBUF.v \
    ${VIVADO}/unisims/IDDR.v \
    ${VIVADO}/unisims/OBUF.v \
    ${VIVADO}/unisims/ODDR.v \
    ${VIVADO}/glbl.v \

compileTest.vvp: $(TEST_SOURCE)
	iverilog -o compileTest.vvp  $(TEST_SOURCE)

clean:
	rm -rf a.out *.vvp *.lxt *.dat
