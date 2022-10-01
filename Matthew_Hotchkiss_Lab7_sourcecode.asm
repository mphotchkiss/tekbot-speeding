;***********************************************************
;*
;*	This is the skeleton file for Lab 7 of ECE 375
;*
;*	 Author: Matthew Hotchkiss
;*	   Date: 2/17/2022
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	speed = r17				; register to store the current speed of the bot
.def	zero = r18				; store the value $00
.def	full = r19				; store the value $FF
.def	seventeen = r25			; store the decimal value 17 (scale for speed - 255/16 = 17)

.equ	EngEnR = 4				; right Engine Enable Bit
.equ	EngEnL = 7				; left Engine Enable Bit
.equ	EngDirR = 5				; right Engine Direction Bit
.equ	EngDirL = 6				; left Engine Direction Bit

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)		;value for both engine directions forward (bits above)

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org	$0002
		rcall	DecSpeed		; button 0 for decrease speed
		reti

.org	$0004
		rcall	IncSpeed		; button 1 for increase speed
		reti

.org	$0006
		rcall	ZeroSpeed		; button 2 for zero speed
		reti

.org	$0008
		rcall	MaxSpeed		; button 3 for max speed 
		reti

.org	$0012					; set the interrupt after the timer/counter0 interrupt
		reti					; rest of the work is done already with LEDs connected to it

.org	$001E					; set the interrupt after the timer/counter2 interrupt
		reti					; rest of the work is done already with LEDs connected to it

.org	$0046					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi		ZL, low(RAMEND)	
		ldi		ZH, high(RAMEND)
		out		SPH, ZH
		out		SPL, ZL

		; Configure registers
		clr		zero			; $00
		ser		full			; $FF
		ldi		seventeen, 17	; 17

		; Initialize Port B for output
		mov		mpr, full		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		mov		mpr, zero		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

		; Initialize Port D for input
		mov		mpr, zero		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		mov		mpr, full		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Configure External Interrupts

		; Initialize external interrupts
		ldi		mpr, $AA		; set to 10101010 to signal falling edge (10) for INT3-0
		sts		EICRA, mpr
		; Set the Interrupt Sense Control to falling edge

		; Configure the External Interrupt Mask
		ldi		mpr, $0F		; set the first 4 bits to 1, activating bits 0 - 3 of interrupt
		out		EIMSK, mpr

		; Configure 8-bit Timer/Counters
		ldi		mpr, 0b01101001	; 1101 => PMW and compare output mode: clear OC0 on cp match and set @ bottom
		out		TCCR2, mpr		; configure timer/counter 0 AND 2 with same settings
		out		TCCR0, mpr

		out		OCR0, full		; start the duty @ 255/255
		out		OCR2, full

		ldi		mpr, 0b10000010	; enable the 2 timer/counter interrupt flags
		out		TIMSK, mpr

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL)
		ldi		mpr, MovFwd		; load into mpr then write to the port to light LEDs
		out		PORTB, mpr

		; Set initial speed, display on Port B pins 3:0
		rcall	ZeroSpeed		; set the speed to zero to start

		; Turn on interrupts
		sei
		; NOTE: This must be the last thing to do in the INIT function


;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp	MAIN			; just loop! Everything interrupts

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	IncSpeed
; Desc:	increase the speed of the bot by 1/16 if not maxed out
;-----------------------------------------------------------
IncSpeed:
		cpi		speed, 0b00001111	; is the speed maxed out already?
		breq	ExitInc				; if so, exit
		inc		speed				; otherwise, speed up
		rcall	updateSpeed			; and update the speed display
ExitInc:
		rcall	ClrEIFR				; clear any queued interrupts
		ret							; always return

;-----------------------------------------------------------
; Func:	DecSpeed
; Desc:	decrease the speed of the bot by 1/16 if not min'ed
;-----------------------------------------------------------
DecSpeed:
		cpi		speed, 0b00000000	; is the speed min'd out already?
		breq	ExitDec				; if so, exit
		dec		speed				; otherwise, slow down
		rcall	updateSpeed			; and update the speed display
ExitDec:
		rcall	ClrEIFR				; clear any queued interrupts
		ret							; always return

;-----------------------------------------------------------
; Func:	ZeroSpeed
; Desc:	set the speed to zero
;-----------------------------------------------------------
ZeroSpeed:
		clr		speed				; clear the speed
		rcall	updateSpeed			; same as above - update, clear queue, return
		rcall	ClrEIFR
		ret

;-----------------------------------------------------------
; Func:	MaxSpeed
; Desc:	max out the speed
;-----------------------------------------------------------
MaxSpeed:
		ser		speed				; set all bits
		andi	speed, 0b00001111	; clear the top 4
		rcall	updateSpeed			; same as above
		rcall	ClrEIFR
		ret

;-----------------------------------------------------------
; Func:	ClrEIFR
; Desc:	clear the EIFR register (interrupt queue)
;-----------------------------------------------------------
ClrEIFR:
		rcall	waitABit			; before we do anything, wait a bit so the interrupt doesn't trigger multiple times from 1 press
		mov		mpr, full			; $FF
		out		EIFR, mpr			; $FF clears EIFR
		ret							; always return 

;-----------------------------------------------------------
; Func:	updateSpeed
; Desc:	update the speed display and output compare registers to reflect changes in the speed
;-----------------------------------------------------------
updateSpeed:
		mov		mpr, speed			; copy stored speed
		com		mpr					; flip the bits (engine is active low so high values of speed correlate to low values of duty)
		andi	mpr, 0b00001111		; higher 4 bit should be cleared
		mul		mpr, seventeen		; multiply by 17 for scale
		out		OCR0, r0			; write low byte of multiplication result to both output compare registers
		out		OCR2, r0
		in		mpr, PORTB			; read the port values
		andi	mpr, 0b11110000		; clear the bottom 4 bits
		or		mpr, speed			; or with the speed
		out		PORTB, mpr			; write back to the port
		ret							; always return

;-----------------------------------------------------------
; Func:	waitABit
; Desc:	waits for a "bit" to avoid triggering the interrupt two times with one button press
;-----------------------------------------------------------
waitABit:
		mov		r20, full			; $FF
		clr		r21					; $00
		clr		r22					; $00
		clr		r23					; $00
		ldi		r24, $10			; $10
waitLoop:
		inc		r21				; increment r21
		cp		r21, r20		; is it $FF?
		brne	waitLoop		; if not, loop
		clr		r21				; otherwise reset it
		inc		r22				; and add to r22
		cp		r22, r20		; is r22 $FF?
		brne	waitLoop		; if not, loop
		clr		r22				; otherwise, reset it
		inc		r23				; and add to r23
		cp		r23, r24		; is r23 $10?
		brne	waitLoop		; if not, loop
		ret						; otherwise, the allotted time has passed