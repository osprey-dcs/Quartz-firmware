# First column is DAC setting, second column is frequency, in Hz.
set style data linespoints
l(x) = y0 + m*x
y0 = 125000000
m = 0.1
fit l(x) 'vcxo.dat' via y0, m
plot 'vcxo.dat', l(x)
print "Counts/Hz: ", 1.0/m, "   y0: ", y0
