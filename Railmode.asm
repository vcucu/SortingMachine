
;PINS
;Inputs:
; 0 - start Thrower
; 1 - reset button
; 2 - Checking button (revolution sensor) 
; 3 - Initial position button/sensor?
; 4 - Pulled position button/sensor?
; 5 
; 6
; 7 - start Railmode
;
;Outputs:
; 1 - motor (2nd in the row)
; 2-3 - H-bridge second motor
; 4 - bulb (5th in the row) 


;_____________________________________________________
;  Usage of registers:
;	R0 Read (begin)
; 	R1 Output display (begin)
;	R2 
;	R3 Timer operations + other
;	R4 Timer operations
;	R5 IOAREA (always)

@DATA 
;
	speed		DS  1 ; offset for being on (81 with fast push and 30 with slow one)
	oldinput	DS	1 ; helps to determine end of one push cycle using the button pressed by the circular component on the motor
	mode		DS	1 ; %001 for thrower and %0010 for Railmode
	countb		DS	1 ;
	countw		DS	1;
;
@CODE

   IOAREA      EQU   -16  ;  address of the I/O-Area, modulo 2^18
    INPUT      EQU     7  ;  position of the input buttons (relative to IOAREA)
   OUTPUT      EQU    11  ;  relative position of the power outputs
   TIMER       EQU    13  ;  timer register
   DSPDIG      EQU    9  ;  relative position of the 7-segment display's digit selector
   DSPSEG      EQU    8  ;  relative position of the 7-segment display's segments
   ADCONVS     EQU     6  ;  the outputs, concatenated, of the 2 A/D-converters
   TIM001ms    EQU    10  ;  1ms equals 10 TIMER steps
   fast		   EQU 	  83
   slow		   EQU 	  30
   
	begin :
		BRA initialization
		
	;begin: BRS install
		
	;interrupt:
	;	LOAD R0 10000
	;	STOR R0 [R5+TIMER] ; absolutely no idea why these two lines make the interrupt trigger every time the number of steps elapse
		
	;	LOAD 	R0 [R5+INPUT]
	;	LOAD 	R1	[GB+reset]
	;	AND  	R0	%00010
	;	AND 	R0 	R1
	;	STOR	R0	[GB+reset]
		
		
	;	RTE
		
		
	;install:
		;LOAD R0 [SP++]			; put the address of the first instruction of the IRS in the exception descriptor located at address 2* in memory
		;LOAD R0 interrupt
		;ADD  R0 R5
		;LOAD R1 16    			;this will be exception nr 8
		;STOR R0 [R1]
		;SETI 8						; IE[8] is enabled and the interupt is available
		;BRA initialization			;  skip subroutine Hex7Seg
   
         
;  
;
	Hex7Seg     :  BRS  Hex7Seg_bgn  ;  push address(tbl) onto stack and proceed at "bgn"
	Hex7Seg_tbl :
			  CONS  %01111110    ;  7-segment pattern for '0'
              CONS  %00110000    ;  7-segment pattern for '1'
              CONS  %01101101    ;  7-segment pattern for '2'
              CONS  %01111001    ;  7-segment pattern for '3'
              CONS  %00110011    ;  7-segment pattern for '4'
              CONS  %01011011    ;  7-segment pattern for '5'
              CONS  %01011111    ;  7-segment pattern for '6'
              CONS  %01110000    ;  7-segment pattern for '7'
              CONS  %01111111    ;  7-segment pattern for '8'
              CONS  %01111011    ;  7-segment pattern for '9'
              CONS  %01110111    ;  7-segment pattern for 'A' 10
              CONS  %00011111    ;  7-segment pattern for 'b' 11
              CONS  %01001110    ;  7-segment pattern for 'C' 12
              CONS  %00111101    ;  7-segment pattern for 'd' 13
              CONS  %01001111    ;  7-segment pattern for 'E' 14
              CONS  %01000111    ;  7-segment pattern for 'F' 15
			  CONS  %00110111    ;  7-segment pattern for 'H' 16
			  CONS  %00001110    ;  7-segment pattern for 'L' 17
			  CONS  %01100011    ;  7-segment pattern for 'white' 18
			  CONS  %00011101    ;  7-segment pattern for 'black' 19

	Hex7Seg_bgn:  
              LOAD  R1  [SP++]   ;  R1 := address(tbl) (retrieve from stack)
              LOAD  R1  [R1+R0]  ;  R1 := tbl[R0]
               RTS
;  

	initialization:
			LOAD R0 0					;timer init - prolly not neccessary, but just to be safe
			SUB  R0 [R5+TIMER]			;
			STOR R0 [R5+TIMER]			; timer = timer + (-timer)
			
			LOAD 	R0	%0000
			STOR	R0  [GB+oldinput]			; set the orginal value of stopswitch to 0
			;STOR	R0	[GB+countb]
			;STOR	R0	[GB+countw]
			;LOAD	R0	%0000
			;STOR	R0	[GB+oldreset]
			LOAD  	R5  IOAREA   				;  R5 := "address of the area with  I/O-registers"
			LOAD  	R3  %010000					;load for bulb
			STOR 	R3  [R5+OUTPUT] 			;turn on the bulb (before the first reading)
			BRS		initialposition
			BRA		startbutton						
;__________________________________________________________________________________	
	initialposition: ;set to the initial position = Retracted
			LOAD	R3  [R5+INPUT]
			AND		R3	%01000
			CMP 	R3  %01000
			
			BEQ		returnfrominit 		 ;if already in the initial position 
			LOAD	R3	fast		
			STOR 	R3	[GB+speed] 		 ;speed (=offset for being on is now 80)

			
	on_set2:	 							;method that sets the motor ON and stores the time to stop the waiting in R3
			LOAD	R3	%0100
			STOR 	R3  [R5+OUTPUT] 
			LOAD	R3	[R5+TIMER]
			LOAD 	R4 	[GB+speed] 		;set the waiting time 
			SUB 	R3	R4
			BRA 	on_wait2
			
	on_wait2:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		off_set2
			BRA		on_wait2
			
	off_set2:							;method that sets the motor OFF and sets the correct variables for the waiting 
			LOAD  	R3  %0000			;set the motor off, and just the bulb stays on	
			STOR 	R3  [R5+OUTPUT]    	;
			LOAD	R3 	[GB+speed]  	;calculate the complement of speed (the waiting time to be off) for example with fast => load 81
			LOAD 	R4 	100
			SUB		R4  R3				;and store it R4, in the example its gonna be 19
			LOAD	R3	[R5+TIMER]
			SUB 	R3	R4				;set the waiting according to what was stored in the R4 (the waiting time to be off)
			BRA		off_wait2
	
	off_wait2:
			LOAD    R4  [R5+TIMER]      ; wait off for the time that was calculated before
			CMP 	R4	R3
			BMI		initialposition				;just return to looping in PWM for the motor
			BRA		off_wait2
			
	returnfrominit:
			RTS                  		;the jump to this subroutine can happen either in the beginning when just checking and also when setting the position while sorting
;__________________________________________________________________________________
	pulledposition: ;set to the initial position
			LOAD	R3  [R5+INPUT]
			AND		R3  %010000
			CMP 	R3  %010000
			BEQ		returnfrompull  ;if already in the initial position - wait for start button
			LOAD	R3	fast		
			STOR 	R3	[GB+speed] 		 ;speed (=offset for being on is now 80)
			
	on_set3:	 							;method that sets the motor ON and stores the time to stop the waiting in R3
			LOAD	R3	%01000
			STOR 	R3  [R5+OUTPUT] 
			LOAD	R3	[R5+TIMER]
			LOAD 	R4 	[GB+speed] 		;set the waiting time 
			SUB 	R3	R4
			BRA 	on_wait3
			
	on_wait3:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		off_set3
			BRA		on_wait3
			
	off_set3:							;method that sets the motor OFF and sets the correct variables for the waiting 
			LOAD  	R3  %0000			;set the motor off, and just the bulb stays on	
			STOR 	R3  [R5+OUTPUT]    	;
			LOAD	R3 	[GB+speed]  	;calculate the complement of speed (the waiting time to be off) for example with fast => load 81
			LOAD 	R4 	100
			SUB		R4  R3				;and store it R4, in the example its gonna be 19
			LOAD	R3	[R5+TIMER]
			SUB 	R3	R4				;set the waiting according to what was stored in the R4 (the waiting time to be off)
			BRA		off_wait3
	
	off_wait3:
			LOAD    R4  [R5+TIMER]      ; wait off for the time that was calculated before
			CMP 	R4	R3
			BMI		pulledposition				;just return to looping in PWM for the motor
			BRA		off_wait3
			
	returnfrompull:
			RTS							;the jump to this subroutine can happen either in the beginning when just checking and also when setting the position while sorting

;__________________________________________________________________________________
	startbutton:                             	;wait for start button to be pressed & display hello in the meantime
			LOAD 	R3	0
			STOR	R3	[GB+countb]
			STOR	R3	[GB+countw]
			
			LOAD 	R3	[R5+INPUT]
			AND		R3	%0001
			CMP		R3 	%0001
			BEQ		photosense
			
			LOAD 	R3	[R5+INPUT]
			AND		R3	%01000000
			CMP		R3 	%01000000
			BEQ		photosense2
						
			BRA		hello
;			
	waitbefore1:                             ;currently not in use (was supposed to increase reliability - but discovered that it is probz not needed)
			LOAD 	R3	[R5+TIMER]
			SUB		R3	1000
			
	waitbefore2:                             ;currently not in use
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		photosense
			BRA		waitbefore2
;__________________________________________________________________________________	
	photosense : ;Thrower - read the sensor
			LOAD	R3	%001        ; these two lines need to be taken out of the method
			STOR	R3	[GB+mode]
	
			LOAD 	R0 	[R5+INPUT]
			AND		R0 	%0010
			CMP		R0	%0010
			BEQ		startbutton
	
			LOAD 	R0  [R5+ADCONVS]  	;read 
			DIV 	R0	256				;erase the last 8 bits from the other analogue input                                             ;DIV = real PP2 photosensor, MOD = slider on emulator

			CMP		R0	8	 			;if the value read is lower than 6 = meaning the most light is coming in
			BMI	 	photosense			;just photosense again = so no motion when the bulb is on
			CMP		R0	251	 	     	;if its lower than 255
			BMI	 	setwhite			;jump to setting values for white

			BRA 	setblack			;otherwise just go to black (= the value was 255 = least light is coming in)
			  
;		
	setblack:
			LOAD	R3	slow			;set for black
			STOR 	R3	[GB+speed]  	;speed (=offset for being on is now 20)
			LOAD	R3	[GB+countb]
			ADD		R3	1
			STOR	R3	[GB+countb]
			BRS		displayblack
			BRA  	pushdisk
	
	setwhite: 
			LOAD	R3	fast		
			STOR 	R3	[GB+speed] 		 ;speed (=offset for being on is now 80)
			LOAD	R3	[GB+countw]
			ADD		R3	1
			STOR	R3	[GB+countw]
			BRS		displaywhite
			BRA  	pushdisk
;__________________________________________________________________________________________________________
	pushdisk: ;Thrower design - push slow or fast
			LOAD 	R0 	[R5+INPUT]
			AND		R0 	%0010
			CMP		R0	%0010
			BEQ		startbutton
	
			LOAD	R3 	[GB+oldinput] 	;what was the input before
			LOAD	R4	[R5+INPUT] 	  	;what is the input now
			STOR	R4 	[GB+oldinput]	;store the current input for the next generation
			XOR		R4 	R3				;(1) In two steps make R3 be 1 iff the stopswitch went from pressed to unpressed
			AND		R3	R4				;(2)
			AND 	R3 	%0100			;select just third bit (because that is the button under the revolving wheel)
			CMP		R3	%0100
			BEQ		returnfrompush			;iff the button went from pressed to unpressed => stop the revolving aka go to begin and wait for buttons
			BRA		on_set				;otherwise keep on revolving
			  

	on_set:	 							;method that sets the motor ON and stores the time to stop the waiting in R3
			LOAD  	R3  %010010	
			STOR  	R3  [R5+OUTPUT] 	;
			LOAD	R3	[R5+TIMER]
			LOAD 	R4 	[GB+speed] 		;set the waiting time 
			SUB 	R3	R4
			BRA 	on_wait
			
	on_wait:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		off_set
			BRA		on_wait
			
	off_set:							;method that sets the motor OFF and sets the correct variables for the waiting 
			LOAD  	R3  %010000			;set the motor off, and just the bulb stays on	
			STOR 	R3  [R5+OUTPUT]    	;
			LOAD	R3 	[GB+speed]  	;calculate the complement of speed (the waiting time to be off) for example with fast => load 81
			LOAD 	R4 	100
			SUB		R4  R3				;and store it R4, in the example its gonna be 19
			LOAD	R3	[R5+TIMER]
			SUB 	R3	R4				;set the waiting according to what was stored in the R4 (the waiting time to be off)
			BRA		off_wait
	
	off_wait:
			LOAD    R4  [R5+TIMER]      ; wait off for the time that was calculated before
			CMP 	R4	R3
			BMI		pushdisk				;just return to looping in PWM for the motor
			BRA		off_wait
			
	returnfrompush:
			LOAD	R3  [GB+mode]
			AND		R3	%001
			CMP		R3	%001
			BEQ 	photosense
			BRA		photosense2
	
;__________________________________________________________________________________________________________					
	hello: ; (=o_set)
			LOAD	R3	[R5+TIMER]
			SUB 	R3 	10
			LOAD  	R0  0
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %000001  ;  R1 := the bitpattern identifying Digit 1
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	o_wait ;
			
	o_wait:		
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		l1_set
			BRA		o_wait
;
	l1_set:
			LOAD	R3	[R5+TIMER]
			SUB 	R3 	10
			LOAD  	R0  17 																		;17 has to be changed if more letters are added in before L
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %000010  ;  R1 := the bitpattern identifying Digit 2
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	l1_wait ;
			
	l1_wait:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		l2_set
			BRA		l1_wait

	l2_set:
			LOAD	R3	[R5+TIMER]
			SUB 	R3 	10
			LOAD  	R0  17 																		;17 has to be changed if more letters are added in before L
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %000100  ;  R1 := the bitpattern identifying Digit 3
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	l2_wait ;
			
	l2_wait:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		e_set
			BRA		l2_wait
			
	e_set:
			LOAD	R3	[R5+TIMER]
			SUB 	R3 	10
			LOAD  	R0  14 																		
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %001000  ;  R1 := the bitpattern identifying Digit 4
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	e_wait ;
			
	e_wait:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		h_set
			BRA		e_wait
			
	h_set:
			LOAD	R3	[R5+TIMER]
			SUB 	R3 	10
			LOAD  	R0  16 																		;16 has to be changed if more letters are added in before L
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %010000  ;  R1 := the bitpattern identifying Digit 5
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	h_wait ;
			
	h_wait:
			LOAD    R4  [R5+TIMER]
			CMP 	R4	R3
			BMI		startbutton
			BRA		h_wait
			
;__________________________________________________________________________________________________________
	displayblack:
			LOAD  	R0  19
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
			;LOAD 	R1	%00011111
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %000001  ;  R1 := the bitpattern identifying Digit 1
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	pushdisk ;	
	
	displaywhite:
			LOAD  	R0  18
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %100000  ;  R1 := the bitpattern identifying Digit 1
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	pushdisk ;	
			
;__________________________________________________________________________________________________________

	photosense2:
			
			LOAD	R3	%0010        ; these two lines need to be taken out of the method
			STOR	R3	[GB+mode]
			
			LOAD 	R0 	[R5+INPUT]
			AND		R0 	%0010
			CMP		R0	%0010
			BEQ		startbutton
	
			LOAD 	R0  [R5+ADCONVS]  	;read 
			DIV  	R0	256				;erase the last 8 bits from the other analogue input                                             ;DIV = real PP2 photosensor, MOD = slider on emulator

			CMP		R0	8	 			;if the value read is lower than 8 = meaning the most light is coming in
			BMI	 	photosense2			;just photosense again = so no motion when the bulb is on
			CMP		R0	251	 	     	;if its lower than 255
			BMI	 	setwhite2			;jump to setting values for white (setwhite = initialposition)

			BRA 	setblack2			;otherwise just go to black (= the value was 255 = least light is coming in)

	setwhite2:
			BRS 	pulledposition
			LOAD	R3	slow			;set for black
			STOR 	R3	[GB+speed]  	;speed (=offset for being on is now 20)
			BRS		displaywhite
			BRA  	pushdisk
			
	setblack2:
			BRS 	initialposition
			LOAD	R3	slow			;set for black
			STOR 	R3	[GB+speed]  	;speed (=offset for being on is now 20)
			BRS		displayblack
			BRA  	pushdisk
	
	diplaycount:
			LOAD  	R0  16
			BRS 	Hex7Seg      ;  translate (value in) R0 into a display pattern
            STOR  	R1  [R5+DSPSEG] ; and place this in the Display Element
            LOAD  	R1  %000001  ;  R1 := the bitpattern identifying Digit 1
            STOR  	R1  [R5+DSPDIG] ; activate Display Element nr. 1
            BRA  	pushdisk ;
	
@END