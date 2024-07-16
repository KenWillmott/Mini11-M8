;
;	Mini 11/M8 Bootstrap
;

; modified by Ken Willmott from Mini11 Bootstrap by Alan Cox
;
; 2024-06-29 change baud rate for 7.3278 Mhz crystal
; 2024-07-10 Add full system initialization
; 2024-07-12 make serial routines stand alone in ROM

ROM	EQU	$F800
MEMLAT	EQU	ROM	; shared, read ROM and write latch
CPUBAS	EQU	$F000
SYSVAR	EQU	CPUBAS-$80
STKBAS	EQU	SYSVAR-1

; existing defines

TMSK2	EQU	$24
PACTL	EQU	$26
SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
BAUD	EQU	$2B
SCCR1	EQU	$2C
SCCR2	EQU	$2D
SCSR	EQU	$2E
SCDR	EQU	$2F

PDDR	EQU	$08
DDRD	EQU	$09
PORTA	EQU	$00

CTMMC	EQU	1
CTSD2	EQU	2
CTSDBLK	EQU	3
CTSD1	EQU	4

; new definitions

INIT	equ	$3D           ; RAM and IO mapping reg
OPTION	EQU	$39
CONFIG	equ	$3F           ; config register


NUMVEC	equ	20	; number of CPU vectors to create
NUMREG	equ	11	; number of CPU registers

; Register flag definitions:

TDRE	equ	$80
RDRF	equ	$20

	ORG ROM

START:
	;	Put the internal RAM at F040-F0FF
	;	and I/O at F000-F03F. This costs us 64bits of IRAM
	;	but gives us a nicer contiguous addressing map.
	LDAA	#$FF
	STAA  	$1000+INIT

	;	X = base of CPU registers
	LDX	#CPUBAS

	LDAA	#$13
	STAA	OPTION,X	;COP slow, clock startup DLY still on

	;	Free running timer on divide by 16
	LDAA	TMSK2,X
	ORAA    #3
	STAA	TMSK2,X

	;	Set up the memory for 64k contiguous RAM
	;	bank 0 = block 0, bank 1 = block 1
	LDAA	#$10
	STAA	MEMLAT

	;	Ensure CS1 high
	;	regardless of any surprises at reset
	LDAA	#$80
	STAA	PORTA,X
	BSET	PACTL,X $80

	;	configure serial
	;	Serial is 115200 8N1 for the 7.3728MHz crystal
	LDAA	#$00
	STAA	BAUD,X	; BAUD
	LDAA	#$00
	STAA	SCCR1,X	; SCCR1
	LDAA	#$0C
	STAA	SCCR2,X	; SCCR2

	; set up default vector jump table
	lds	#SYSVAR-1   ;SET STACK POINTER
	ldab	#NUMVEC
	ldaa	#$7E		;JMP INSTRUCTION
	ldy	#VECERR
NEXTVC:	pshy
	psha
	decb
	bne	NEXTVC

   	;SET STACK POINTER
   	lds	#STKBAS-1

; start up messages

	LDY	#INIT1
	JSR	STROUT

	LDAA	CONFIG,X
	JSR	PHEX	; Display CPU config

	LDY	#INIT2
	JSR	STROUT

;
;	Probe for an SD card and set it up as tightly as we can
;

	LDAA #$38	; SPI outputs on
	STAA DDRD,X
	LDAA #$52	; SPI on, master, mode 0, slow (125Khz)
	STAA SPCR,X

	;	Raise CS send clocks
	JSR  CSRAISE
	LDAA #200	; Time for SD to stabilize
CSLOOP:
	JSR  SENDFF
	DECA
	BNE CSLOOP
	LDY #CMD0
	BSR  SENDCMD
	DECB	; 1 ?
	BNE SDFAILB
	LDY #CMD8
	JSR SENDCMD
	DECB
	BEQ NEWCARD
	JMP OLDCARD
NEWCARD:
	BSR GET4
	LDD BUF+2
	CMPD #$01AA
	BNE SDFAILD
WAIT41:
	LDY #ACMD41
	JSR SENDACMD
	BNE WAIT41
	LDY #CMD58
	JSR SENDCMD
	BNE SDFAILB
	BSR GET4
	LDAA BUF
	ANDA #$40
	BNE BLOCKSD2
	LDAA #CTSD2
INITOK:
	STAA CARDTYPE
	JMP LOADER

GET4:
	LDAA #4
	LDY #BUF
GET4L:
	JSR SENDFF
	STAB ,Y
	INY
	DECA
	BNE GET4L
	RTS

SDFAILD:
	JSR PHEX
SDFAILB:
	TBA
SDFAILA:
	JSR PHEX
	LDY #ERROR
	JMP FAULT

SENDACMD:
	PSHY
	LDY #CMD55
	JSR SENDCMD
	PULY
SENDCMD:
	JSR CSRAISE
	BSR CSLOWER
	CMPY #CMD0
	BEQ NOWAITFF
WAITFF:
	JSR SENDFF
	INCB
	BNE WAITFF
NOWAITFF:
	; Command, 4 bytes data, CRC all preformatted
	LDAA #6
SENDLP:
	LDAB ,Y
	JSR SEND
	INY
	DECA
	BNE SENDLP
	JSR SENDFF
WAITRET:
	JSR SENDFF
	BITB #$80
	BNE WAITRET
	CMPB #$00
	RTS

SDFAIL2:
	BRA SDFAILB

CSLOWER:
	BCLR PDDR,X $20
	RTS
BLOCKSD2:
	LDAA #CTSDBLK
	JMP INITOK
OLDCARD:
	LDY #ACMD41_0	; FIXME _0 check ?
	JSR SENDACMD
	CMPB #2
	BHS MMC
WAIT41_0:
	LDY #ACMD41_0
	JSR SENDACMD
	BNE WAIT41_0
	LDAA #CTSD1
	STAA CARDTYPE
	BRA SECSIZE
MMC:
	LDY #CMD1
	JSR SENDCMD
	BNE MMC
	LDAA #CTMMC
	STAA CARDTYPE
SECSIZE:
	LDY #CMD16
	JSR SENDCMD
	BNE SDFAIL2
LOADER:
	BSR CSRAISE
	LDY #CMD17
	JSR SENDCMD
	BNE SDFAIL2
WAITDATA:
	JSR SENDFF
	CMPB #$FE
	BNE WAITDATA
	LDY #$0
	CLRA
DATALOOP:
	JSR SENDFF
	STAB ,Y
	JSR SENDFF
	STAB 1,Y
	INY
	INY
	DECA
	BNE DATALOOP

;	Done transfer disk to page zero
	LDY	#INIT3
	JSR	STROUT

	BSR CSRAISE
	LDY #$0
	LDD ,Y
	CPD #$6811
	BNE NOBOOT

;	Jump to loader that we installed
	LDAA CARDTYPE
	JMP 2,Y

;
;	This lot must preserve A
;
CSRAISE:
	BSET PDDR,X $20
SENDFF:
	LDAB #$FF
SEND:
	STAB SPDR,X
SENDW:	BRCLR SPSR,X $80 SENDW
	LDAB SPDR,X
	RTS

;
;	Commands
;
CMD0:
	FCB $40,0,0,0,0,$95
CMD1:
	FCB $41,0,0,0,0,$01
CMD8:
	FCB $48,0,0,$01,$AA,$87
CMD16:
	FCB $50,0,0,2,0,$01
CMD17:
	FCB $51,0,0,0,0,$01
CMD55:	
	FCB $77,0,0,0,0,$01
CMD58:
	FCB $7A,0,0,0,0,$01
ACMD41_0:
	FCB $69,0,0,0,0,$01
ACMD41:
	FCB $69,$40,0,0,0,$01

NOBOOT: LDY	#NOBMSG
FAULT:	JSR	STROUT
STOPB:	BRA	STOPB

INIT1:
	FCC	'*** Mini11/M8 System Boot (C) 2024 Ken Willmott ***'
	FCB	$0D,$0A
	FCC	'based on '
	FCC	'Mini11 68HC11 System, (C) 2019-2023 Alan Cox'
	FCB	$0D,$0A
	FCC	'SD Boot Loader Version 1.1 built on '
	FCC	DATE
	FCB	$0D,$0A
	FCC	'CPU config register: '
	FCB	0

INIT2:
	FCB	$0D,$0A
	FCC	'Attempting to boot from SD: '
	FCB	0

INIT3:
	FCC	'SD boot successful.'
	FCB	13,10,0

ERROR:
	FCC	'Error - SD not functional'
	FCB	13,10,0

NOBMSG: FCC	'Invalid boot signature'
	FCB	13,10,0

ERROUT:	.fcb $0D,$0A
	.fcc "Error - CPU vector table entry not initialized"
	.fcb $0D,$0A,0

	;
	;	Serial I/O
	;

; print a hex digit in A
PHEX:	PSHA
	LSRA
	LSRA
	LSRA
	LSRA
	BSR	HEXDIGIT
	PULA
	ANDA #$0F
HEXDIGIT:
	CMPA #10
	BMI LO
	ADDA #7

; print value in A as a numeral
LO:	ADDA #'0'

CHOUT:	PSHX
	LDX	#CPUBAS
CHOUTL:	BRCLR	SCSR,X TDRE CHOUTL
	STAA	SCDR,X
	PULX
	RTS

; print a string
STROUT:	LDAA	,Y
	BEQ	STRDONE
	BSR	CHOUT
	INY
	BRA	STROUT
STRDONE: RTS

; INPUT ONE CHAR INTO A-REGISTER with no echo
GETCH:	PSHX
	LDX	#CPUBAS
GETCHL:	BRCLR	SCSR,X RDRF GETCHL	; wait for char available
	LDAA	SCDR,X
	CMPA	#$7F
	BEQ	GETCH		; ignore rubout character
	PULX
	RTS


; Report vector problem

VECERR:	ldy	#ERROUT
	jsr	STROUT
FREEZE:	bra	FREEZE     ;Suspend via endless loop

	; Processor hardware vectors
; There are twenty, not including CPU Reset

	org	$10000-(NUMVEC+1)*2	; below end of ROM

	.fdb	VSCI	; SCI Event
	.fdb	VSPI	; SPI Transfer Complete
	.fdb	VPAII	; Pulse Accumulator Input Edge
	.fdb	VPAOF	; Pulse Accumulator Overflow
	.fdb	VTOF	; Timer Overflow

	.fdb	VI4O5	; Timer IC4/OC5
	.fdb	VTOC4	; Timer Output Compare 4
	.fdb	VTOC3	; Timer Output Compare 3
	.fdb	VTOC2	; Timer Output Compare 2
	.fdb	VTOC1	; Timer Output Compare 1

	.fdb	VTIC3	; Timer Input Capture 3
	.fdb	VTIC2	; Timer Input Capture 2
	.fdb	VTIC1	; Timer Input Capture 1
	.fdb	VRTI	; Real Time Interrupt
	.fdb	VIRQ	; IRQ pin

	.fdb	VXIRQ	; XIRQ pin
	.fdb	VSWI	; Software Interrupt
	.fdb	VILLEG	; Illegal Op Code Trap
	.fdb	VCOPF	; COP Failure
	.fdb	VCMF	; COP Clock Monitor Fail

	.fdb	START	; RESET

; Data Section
; located in main RAM

	org	SYSVAR		; system variables block at top page of RAM
					; stack just below

CARDTYPE:	RMB	1
BUF:		RMB	8

	org	CPUBAS-(NUMVEC*3)	; below end of main RAM

; CPU vector jump table
; must be in RAM to be alterable

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
