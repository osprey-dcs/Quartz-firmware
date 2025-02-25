# Quartz firmware

A note on repository organization.
Currently [this repository](https://github.com/osprey-dcs/Quartz-firmware)
contains two unrelated git branches: `v1.x` and `v1.x-software`.
This `v1.x` branch should be used as an entry point.
`v1.x` contains the Vivado project, and references the Vitis project
in `v1.x-software` as a git-submodule (thus the `--recursive` below).

## Dependencies

- AMD/Xilinx [Vivado/Vitis 2023.1 development tools](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2023-1.html)

## Building

The following assume a Linux host to execute the `buildit.sh` wrapper script.

The `vivado` and `xsct` (vitis) executables must be present in the default search `$PATH`.
One way to accomplish this is to run:

```sh
. /path_to_Vivado_installation/2023.1/settings64.sh
```

Note: this only modifies the environment of the current shell session,
      and must be repeated each time a new session starts.

```sh
git clone --recursive https://github.com/osprey-dcs/Quartz-firmware.git
cd Quartz-firmware
./buildit.sh
# Go get a coffee.  This will take a long time...
```

On success a file `quartzV1*.bit` will be left in the same directory.

```
...
All done!
+ ls -lh quartzV1-20241230-350d71f.bit
-rw-rw-r-- 1 mdavidsaver mdavidsaver 3.8M Jan 23 07:53 quartzV1-20241230-350d71f.bit
+ rm -rf /tmp/tmp.9aYygea65p
```

This bitstream file can be loaded via the [alluvium](https://github.com/mdavidsaver/alluvium) tool.

Note: The scripted build process is not current idemopotent.
      The `./reset.sh` script is provided to DELETE ALL LOCATION CHANGES
      to source files which the xilinx tools make.


## EPICS IOC

See [atf-acq-ioc](https://github.com/osprey-dcs/atf-acq-ioc).
