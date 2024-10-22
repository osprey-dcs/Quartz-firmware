# Show closed-loop pole locations and step response of clock synchronization PLL
1;
function chk (kp, ki, hzPerCount)
controller = parallel(tf([kp], [1]), tf([ki 0], [1 -1], 1.0))
plant = tf([hzPerCount 0], [1 -1], 1.0)
SYS = feedback(controller, plant)
pole(SYS)
abs(pole(SYS))
step(SYS,20)
pause
step(SYS,250)
pause
endfunction

chk(1/16, 1/256, 1)

chk(1/2, 1/4, 1)
