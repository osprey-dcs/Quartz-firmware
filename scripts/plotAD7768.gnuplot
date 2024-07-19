set style data lines
set xlabel "Time (ns)"
plot \
    filename using 1:2 with steps title "DCLK[3]", \
    filename using 1:3 with steps title "DCLK[2]", \
    filename using 1:4 with steps title "DCLK[1]", \
    filename using 1:5 with steps title "DCLK[0]", \
    filename using 1:6 with steps title "DRDY[3]", \
    filename using 1:7 with steps title "DRDY[2]", \
    filename using 1:8 with steps title "DRDY[1]", \
    filename using 1:9 with steps title "DRDY[0]"
