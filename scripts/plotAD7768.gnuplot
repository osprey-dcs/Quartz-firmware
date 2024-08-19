set style data lines
set title filename
set xlabel "Time (ns)"
set yrange [0:2]
set xrange[900000:950000]

plot \
    filename using 1:2 with steps title "MCLK", \
    filename using 1:3 with steps title "DCLK[3]", \
    filename using 1:4 with steps title "DCLK[2]", \
    filename using 1:5 with steps title "DCLK[1]", \
    filename using 1:6 with steps title "DCLK[0]", \
    filename using 1:7 with steps title "DRDY[3]", \
    filename using 1:8 with steps title "DRDY[2]", \
    filename using 1:9 with steps title "DRDY[1]", \
    filename using 1:10 with steps title "DRDY[0]"
