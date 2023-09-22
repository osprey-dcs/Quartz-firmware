#
# Record POSIX time at which this script was run
#
puts "Set firmware time from [pwd]"
if {![catch {set firmwareDateFile [open "../../NASA_ACQ.srcs/sources_1/hdl/firmwareBuildDate.v" w]}]} {
    puts $firmwareDateFile "// MACHINE GENERATED -- DO NOT EDIT"
    puts $firmwareDateFile "localparam FIRMWARE_BUILD_DATE = [clock seconds];"
    close $firmwareDateFile
}
