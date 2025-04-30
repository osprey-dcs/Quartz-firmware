# Show closed-loop pole locations and step response of clock synchronization PLL
1;
function chk (kp, ki, hzPerCount)
printf("***** Kp:%d  Ki:%d *****\n", kp, ki);
controller = parallel(tf([kp], [1]), tf([ki 0], [1 -1], 1.0))
plant = tf([hzPerCount 0], [1 -1], 1.0)
SYS = feedback(controller, plant)
pole(SYS)
abs(pole(SYS))
step(SYS,20)
pause
[y,t] = step(SYS,250);
step(SYS,250);
[ymin, ymini] = min(y);
printf("Initial error %d\n", y(1));
if (ymin < 0)
    printf("Overshoot %d at step %d\n", -ymin, ymini);
endif
pause
endfunction

chk(1/16, 1/512, 1)

chk(1/4, 1/16, 1)
