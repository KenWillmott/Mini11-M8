; KBUG V 1.04
; Monitor program for the HD6303Y EVB board

; K. Willmott 2023
; tested, working

; minibug originally modified for NMIS-0021

; 2023-03-01 adapt for 6303Y
; 2023-05-18 first clean up, add some comments
; 2023-05-20 add feedback text, write "W", exec command "X"
; 2023-05-21 fixed stack initialization error
; 2023-05-22 add CPU vector jump table
; 2023-05-25 add primitive RAM test
; 2023-06-18 add external baud clock for 3MHz operation
; 2023-06-19 make alpha input case insensitive
; 2023-06-22 add clock stretching
; 2023=07-14 code formatting clean up
; 2023-10-20 add S record address relocation

; *******************************
; 2024-07-03 adapt for 68HC11A1
; *******************************

; 2024-07-04 add CPU vectors
; 2024-07-11 maintenance
; 2024-07-14 convert to disk loaded

; based on the original source
; COPYWRITE 1973, MOTOROLA INC
; REV 004 (USED WITH MIKBUG)

;***************
;   SYSTEM HARDWARE SPECIFIC EQUATES   *
;***************

; configuration:

FENCE	EQU	$EC00	; lowest free RAM, 768 byte stack is above
APPSIZ	EQU	$0400	; slightly larger than the KBUG monitor
VECTAB	EQU	$EFC4	; CPU vector jump table
STKINI	EQU	$EF7F	; initial stack pointer

; standard routines in ROM:

GETCH	EQU	$FB46	; print char
OUTCH	EQU	$FB2E	; input char, no echo
PRSTRN	EQU	$FB3A	; print string
PHEX	EQU	$FB1C	; print hex pair
DHEX	EQU	$FB26	; print hex digit
PRDIG	EQU	$FB2C	; print decimal digit

; more

RAMBS		equ	$0000		; start of system ram
RAMEND		equ	FENCE-APPSIZ		;memory limit

IRAMBS		equ	$F000               ; start of internal ram
IRAMND		equ	$F100               ; end of internal ram
REGBS		equ	$F000               ; start of registers (0,x)
ROMBS		equ	$F800               ; start of rom
MEMLAT		EQU	ROMBS		; shared, ROM and write latch

; Address of boot or test code, RTS to return to monitor
XCALL		equ	$0000		;call test code here

NUMVEC		equ	20	; number of CPU vectors to create
NUMREG		equ	11	; number of CPU registers

; Register flag definitions:

TDRE	equ	$80
RDRF	equ	$20


; MC68HC11A1 register definitions:
; from buf25.asm buffalo source
; existing defines added

PORTA	EQU	$00
		; $01 reserved
PIOC	EQU	$02
PORTC	EQU	$03
PORTB	EQU	$04
PORTCL	EQU	$05
		; $06 reserved
DDRC	EQU	$07
PORTD	EQU	$08
DDRD	EQU	$09
PORTE	equ	$0A           ; port e
CFORC	EQU	$0B
OC1M	EQU	$0C
OC1D	EQU	$0D
TCNT	equ	$0E           ; timer count
TIC1	EQU	$10
TIC2	EQU	$12
TIC3	EQU	$14
TOC1	EQU	$16
TOC2	EQU	$18
TOC3	EQU	$1A
TOC4	EQU	$1C
TOC5	equ	$1E           ; oc5 reg
TCTL1	equ	$20           ; timer control 1
TCTL2	equ	$21           ; timer control 2
TMSK1	equ	$22           ; timer mask 1
TFLG1	equ	$23           ; timer flag 1
TMSK2	equ	$24           ; timer mask 2
PACTL	EQU	$26
PACNT	EQU	$27
SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
BAUD	equ	$2B           ; sci baud reg
SCCR1	equ	$2C           ; sci control1 reg
SCCR2	equ	$2D           ; sci control2 reg
SCSR	equ	$2E           ; sci status reg
SCDR	equ	$2F           ; sci data reg
ADCTL	EQU	$30
ADR1	EQU	$31
ADR2	EQU	$32
ADR3	EQU	$33
ADR4	EQU	$34
		; $35-$38 reserved
OPTION	equ	$39           ; option reg
COPRST	equ	$3A           ; cop reset reg
PPROG	equ	$3B           ; ee prog reg
HPRIO	equ	$3C           ; hprio reg
INIT	equ	$3D           ; RAM and IO mapping reg
TEST1	EQU	$3E
CONFIG	equ	$3F           ; config register

; start of code area

	org	RAMEND

; ENTER POWER ON SequENCE

START:

	;	point X to the RAM/IO space
	LDX	#$F000

; end of hardware initialization
; exit conditions:
; X = $F000 pointer to I/O and IRAM
; S = high RAM below system scratchpad
; contiguous SRAM configured from $0000 to FENCE if installed

; run main program

	jmp	KBUG

; Utility routines follow
;

; Make input case insensitive
; From p.718 Hitachi HD6301-3 Handbook

TPR:	cmpa	#'a'	;Entry point
	bcs	TPR1
	cmpa	#'z'
	bhi	TPR1
	anda	#$DF	;Convert lowercase to uppercase
TPR1:	rts

; Input a character with output echo

INCH:	jsr	GETCH
	bsr	TPR
	cmpa	#$0D
	beq	NOECHO
	JSR	OUTCH
NOECHO: RTS

; boot time memory test

MEMTST:	ldy	#RAMBS
	sty	memtop

loop:	ldaa	0,y	; get byte
	coma		; invert bits
	tab		; save inverted copy in B

	staa	0,y	; save complement same place
	cmpb	0,y
	bne	done	; read not same as written

	coma		; invert again
	staa	0,y	; save original value same place

	iny		; look at next byte
	cpy	#RAMEND
	beq	done
	bra	loop

done:	sty	memtop
	rts
;
; end utility routines


; Monitor code begins
;

; INPUT HEX CHAR
;

INHEX:	bsr	INCH
	cmpa	#'0'
	bmi	C1       ;NOT HEX
	cmpa	#'9'
	ble	IN1HG    ;IS HEX
	cmpa	#'A'
	bmi	C1       ;NOT HEX
	cmpa	#'F'
	bgt	C1       ;NOT HEX
	suba	#'A'-'9'-1    ;MAKE VALUES CONTIGUOUS
IN1HG:	rts

; S-record loader
;

LOAD:	bsr	INCH
	cmpa	#'S'
	bne	LOAD    ;1ST CHAR NOT (S)
	bsr	INCH
	cmpa	#'9'
	beq	C1
	cmpa	#'1'
	bne	LOAD    ;2ND CHAR NOT (1)
	clr	CKSM     ;ZERO CHECKSUM
	bsr	BYTE     ;READ BYTE
	suba	#2
	staa	BYTECT   ;BYTE COUNT

; BUILD ADDRESS
	bsr	BADOFF

; STORE DATA
LOAD11:	bsr	BYTE
	dec	BYTECT
	beq	LOAD15   ;ZERO BYTE COUNT
	staa	,y        ;STORE DATA
	iny
	bra	LOAD11

LOAD15:	inc	CKSM
	beq	LOAD
LOAD19:	ldaa	#'?'      ;PRINT QUESTION MARK

	jsr	OUTCH
C1:	jmp	CONTRL

; BUILD ADDRESS
;

BADOFF:	bsr	BYTE     ;READ 2 FRAMES
	adda	srecof	; add high order address offset
	bra	BAD2

BADDR:	bsr	BYTE     ;READ 2 FRAMES
BAD2:	staa	XHI
	bsr	BYTE
	staa	XLOW
	ldy	XHI      ;Y := ADDRESS WE BUILT
	rts

; INPUT BYTE (TWO FRAMES)
;

BYTE:	bsr	INHEX    ;GET HEX CHAR
	asla
	asla
	asla
	asla
	tab
	bsr	INHEX
	anda	#$0F     ;MASK TO 4 BITS
	aba
	tab
	addb	CKSM
	stab	CKSM
	rts

; CHANGE MEMORY (M AAAA DD NN)
;

CHANGE:	bsr	BADDR    ;BUILD ADDRESS
	bsr	OUTS     ;PRINT SPACE
	bsr	OUT2HS
	bsr	BYTE
	dey
	staa	,y
	cmpa	,y
	bne	LOAD19   ;MEMORY DID NOT CHANGE
	bra	CONTRL

; WRITE MEMORY (M AAAA NN)
;

MWRITE:	bsr	BADDR    ;BUILD ADDRESS
	bsr	OUTS     ;PRINT SPACE
	bsr	BYTE
	staa	,y
	bra	CONTRL

;  formatted output entry points
;

OUTHL:	lsra	;OUT HEX LEFT BCD DIGIT
	lsra
	lsra
	lsra

OUTHR:	anda	#$F	;OUT HEX RIGHT BCD DIGIT
	adda	#$30
	cmpa	#$39
	bhi	ISALF
	jmp	OUTCH

ISALF:	adda	#$7
	jmp	OUTCH

OUT2H:	ldaa	0,y      ;OUTPUT 2 HEX CHAR
	bsr	OUTHL    ;OUT LEFT HEX CHAR
	ldaa	0,y
	bsr	OUTHR    ;OUT RIGHT HEX VHAR
	iny
	rts

OUT2HS:	bsr	OUT2H    ;OUTPUT 2 HEX CHAR + SPACE
OUTS:	ldaa	#$20     ;SPACE
	jmp	OUTCH    ;(bsr & rts)

; Monitor startup
;

KBUG:	jsr	MEMTST	;check memory

	ldy	#MOTD		;Print start up message
	jsr	PRSTRN

	ldy	#MMSG1	;Print memtest results
	jsr	PRSTRN
	ldy	#memtop
	jsr	OUT2H
	jsr	OUT2H
	ldy	#MMSG2
	jsr	PRSTRN

	ldy	#cmdhlp   ;Print commands message
	jsr	PRSTRN

	clra
	staa	srecof	;initialize S record offset

	bra	CONTRL


; PRINT CONTENTS OF STACK

PRINT:	ldy	#REGHDR   ;Print register titles
	jsr	PRSTRN
	tsy
	sty	SP       ;SAVE STACK POINTER
	ldab	#11
PRINT2:	bsr	OUT2HS   ;OUT 2 HEX & SPACE
	DECB
	bne	PRINT2

CONTRL:	LDS	#STACK   ;SET STACK POINTER
	ldaa	#$0D      ;CARRIAGE RETURN
	jsr	OUTCH
	ldaa	#$0A      ;LINE FEED
	jsr	OUTCH
	ldy	#PROMPT   ;Print start up message
	jsr	PRSTRN

	jsr	INCH     ;READ CHARACTER
	tab
	jsr	OUTS     ;PRINT SPACE

	cmpb	#'X'		;Execute stored program
	bne	NOTQ
	jsr	XCALL
	jmp	KBUG

NOTQ:	cmpb	#'L'		;Load S-record
	bne	NOTL
	jmp	LOAD

NOTL:	cmpb	#'M'		;Modify
	bne	NOTM
	jmp	CHANGE

NOTM:	cmpb	#'W'		;Write
	bne	NOTW
	jmp	MWRITE

NOTW:	cmpb	#'P'		;Print
	beq	PRINT
	cmpb	#'G'		;Go
	bne	CONTRL
	rti			;Load registers and run

; Constant data section

MOTD:	.fcb $0D,$0A
	.fcc "*** Kbug Monitor for Mini11/M8 ***"
	.fcb $0D,$0A
	.fcc "firmware 1.04 built on "
	.fcc DATE
	.fcb $0D,$0A,0

cmdhlp:	.fcc "G(o),L(oad),P(roc),M(od),W(rite),X(ecute)?:"
       	.fcb $0D,$0A,0

PROMPT:	.fcc "KBUG->"
	.fcb 0

REGHDR:	.fcb $0D,$0A
	.fcc "CC B  A  XH XL YH YL PH PL SH SL"
	.fcb $0D,$0A,0

MMSG1:	.fcc "RAM test passed to $"
	.fcb 0

MMSG2:	.fcc "."
	.fcb $0D,$0A,0

; Data Section

memtop:	.rmb	2
srecof:	.rmb	1
; END REGISTERS FOR GO command

CKSM:	.rmb	1        ;CHECKSUM
BYTECT:	.rmb	1        ;BYTE COUNT
XHI:	.rmb	1        ;XREG HIGH
XLOW:	.rmb	1        ;XREG LOW


	org	STKINI	; initial stack

	; 16 locations begin
STACK:	.rmb	1        ;STACK POINTER = next available byte on stack

; REGISTERS FOR GO command

	.rmb	1        ;CONDITION CODES
	.rmb	1        ;B ACCUMULATOR
	.rmb	1        ;A
	.rmb	1        ;X-HIGH
	.rmb	1        ;X-LOW
	.rmb	1        ;Y-HIGH
	.rmb	1        ;Y-LOW
	.rmb	1        ;P-HIGH
	.rmb	1        ;P-LOW
SP:	.rmb	1        ;S-HIGH
	.rmb	1        ;S-LOW

; CPU vector jump table
; must be in RAM to be alterable

	org	VECTAB

VSCI:	.rmb	3
VSPI:	.rmb	3
VPAII:	.rmb	3
VPAOF:	.rmb	3
VTOF:	.rmb	3

VI4O5:	.rmb	3
VTOC4:	.rmb	3
VTOC3:	.rmb	3
VTOC2:	.rmb	3
VTOC1:   .rmb	3

VTIC3:	.rmb	3
VTIC2:	.rmb	3
VTIC1:   .rmb	3
VRTI:    .rmb	3
VIRQ:    .rmb	3

VXIRQ:    .rmb	3
VSWI:    .rmb	3
VILLEG:   .rmb	3
VCOPF:    .rmb	3
VCMF:    .rmb	3

HERE	.equ	*

	.END
