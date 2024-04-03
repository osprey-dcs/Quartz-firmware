all: softwareBuildDate.h


JSONrom.h: nasaAcq.json
	 PYTHONPATH="../bedrock" python ../bedrock/build_rom.py -d NASA_ACQ \
                                                    -j nasaAcq.json -c JSONrom.h

softwareBuildDate.h: JSONrom.h \
                     acq.c \
                     acq.h \
                     ad7768.c \
                     ad7768.h \
                     amc7823.c \
                     amc7823.h \
                     calibration.c \
                     calibration.h \
                     clockAdjust.c \
                     clockAdjust.h \
                     config.h \
                     console.c \
                     console.h \
                     epics.c \
                     epics.h \
                     evg.c \
                     evg.h \
                     eyescan.c \
                     eyescan.h \
                     fastDataStream.c \
                     fastDataStream.h \
                     ffs.c \
                     ffs.h \
                     gpio.h \
                     iicFPGA.c \
                     iicFPGA.h \
                     main.c \
                     mgt.c \
                     mgt.h \
                     mmcMailbox.c \
                     mmcMailbox.h \
                     platform.c \
                     platform.h \
                     platform_config.h \
                     systemParameters.c \
                     systemParameters.h \
                     tftp.c \
                     tftp.h \
                     util.c \
                     util.h \
                     xadc.c \
                     xadc.h
	sh setSoftwareBuildDate.sh >softwareBuildDate.h
