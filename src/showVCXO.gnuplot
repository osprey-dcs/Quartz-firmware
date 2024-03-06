set style data linespoints
l(x) = y0 + m*x
y0 = 100
m = 28e-9
fit l(x) 'vcxo.dat' via y0, m
plot 'vcxo.dat', l(x)
print "Counts/Hz: ", 1/(m*1e6), "   y0: ", y0
