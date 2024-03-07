# Downloading and building FPGA code

## Preliminaries

1. Download and install the [Vivado/Vitis 2023.1 development tools](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2023-1.html) from the AMD website.  Ensure that you include support for Kintex7 devices.
1. Some of the commands mentioned below require that the FPGA development tools be on the search path.  For bash this can be done by adding the following to the .bash_login in your home directory:

        source /path_to_Vivado_installation/2023.1/settings64.sh


## Fetch the required support modules

The following support modules must be cloned from their github repositories.  This can be done as follows.

    mkdir -p ~/src/ip_repo
    cd ~/src/ip_repo
    git clone git@github.com:osprey-dcs/axi-lite-generic-reg.git
    git clone git@github.com:osprey-dcs/marble-boot-flash.git
    git clone git@github.com:osprey-dcs/marble-clock-sync-PLL.git
    git clone git@github.com:osprey-dcs/osprey-series7-downsampler.git
    git clone git@github.com:osprey-dcs/osprey-UDP.git

## Fetch the application firmware repository

1. Clone the Vivado project.  Typically this is done from the directory where the **ip_repo** directory created above resides:

        cd ~/src
        git clone git@github.com:osprey-dcs/nasa-fpga-fw.git NASA_ACQ

## Application firmware – part 1

1. Start Vivado and in the **Quick Start** pane click the `Open Project` link.  In the window that pops up navigate to the **NASA_ACQ** directory created in the previous step.  Select the `NASA_ACQ.xpr` project file and click `OK`.
1. In the **Project Manager** pane click `Settings`.  In the **Project Settings** of the window that pops up expand the IP entry and ensure that the **IP Repositories** values match the locations of the support modules.  If not, select the incorrect entries and click the `-` button, then click the `+` button and navigate to and select the correct locations.
 Note that if all the support modules were checked out into a
single directory (e.g. ip_repo in the above section) it is
necessary to specify only that directory.
Once all the repository paths are correct, click `OK` to close the window.
1. Click the `Reports` menu item and click `Report IP Status`.  In the **IP Status** pane at the bottom of the window click `Upgrade Selected` if it is not greyed out (i.e. if any of the support modules has changed).
1. Click `Generate Block Design` in the **Project Manager** pane.  Wait.....

## Application software

1. Start Vitis and create a **Workspace** directory in the Vivado project top-level directory as its workspace.
1. Click `Create Application Project`.
1. In the window that pops up showing a **Create a New Application Project** page, click `Next`.
1. In the **Platform** page that appears, select the `Create a new platform from hardware (XSA)` tab.
1. Browse to the top directory of the Vivado project, select the `NASA_ACQ.xsa` file there, and click `Open`.
1. Set the `Platform name:` to **NASA_ACQ_platform** and click `Next`.
1. In the **Application Project Details** page that apears, set the **Application project name:** to `NASA_ACQ, then click `Next`.
1. Confirm that the Domain is for a standalone microblaze system, then click `Next`.
1. In the **Templates** page that appears, select `Empty application(C)` and click `Finish`.
1. The **Explorer** tab in the main Vitis window should now show **NASA\_ACQ\_platform** and **NASA\_ACQ_system**, and within the latter, **NASA\_ACQ**.  Select both the platform and the system and ensure that the active target in the **Application Project Settings** pane is set to **Release**, not **Debug**.
1. In a shell window, check out the application software repository and place its contents into the **NASA\_ACQ** directory:

        cd xxxxx/NASA_ACQ/Workspace
        git clone git@github.com:osprey-dcs/nasa-fpga-sw.git tmp
        cd tmp
        cp -r . ../NASA_ACQ
        cd ..
        rm -rf tmp

1. Change to the **Workspace/NASA\_ACQ/src** directory and run the `createVerilogHeader.sh` script.  This creates a configuration source file in the Vivado project and ensures that the firmware and software have the same perspective of various configuration values.
1. Right click on `NASA_ACQ_platform` and select `Build Project`.  Wait....
1. Right click on `NASA_ACQ_system` and select `Build Project`.  Wait....

## Application firmware – part 2

Now that the application software `createVerilogHeader.sh` script has been run, it is possible to finish building the firmware.  Get back into Vivado and:

1. Click `Generate Bitstream` in the **Project Manager** pane.  In the window that pops up agree to running **Synthesis and Implementation**.  Wait....

## Create the bootable image:

1. In a shell window, cd to the **NASA_ACQ/build directory** and run `make`.  The result should be a **download.bit** file ready to transfer to the Marble bootstrap flash memory.

## EPICS IOC

1. Clone the EPICS project.  Typically this is done from the top directory of the Vivado project:

        cd ~/src/NASA_ACQ
        git clone git@github.com:osprey-dcs/atf-acq-ioc.git EPICS

1. Edit the **configure/RELEASE** file to point to your EPICS base and support modules.
1. Run make.
1. Edit the st.cmd file to configure the IP addresses of your FPGA acquisition nodes and make any other desired customization.
