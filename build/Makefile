MMI = ../../../NASA_ACQ.runs/impl_1/NASA_ACQ.mmi
BIT = ../../../NASA_ACQ.runs/impl_1/NASA_ACQ.bit
ELF_0 = ../Release/NASA_ACQ.elf
IMAGE = quarzV1.bit

.PHONY: srCheck elfCheck
all: srcCheck elfCheck $(IMAGE)

srcCheck:
	cd ../src ; make

elfCheck:
	cd ../Release ; make all

$(IMAGE): $(MMI) $(BIT) $(ELF_0) $(ELF_1)
	updatemem -force \
              -out "$(IMAGE)" \
              -meminfo "$(MMI)" \
              -bit "$(BIT)" \
              -proc bd_i/microblaze_0 \
              -data "$(ELF_0)"

clean:
	rm -f "$(IMAGE)" chk.bit vitis_pid*.str *.jou *.log eeprom*.bin

