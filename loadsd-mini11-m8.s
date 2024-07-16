; loadsd-mini11-m8.s
;
; application loader for Mini11/M8
; 2024-07-13 make generic configurable loader

;
;	The SD boot code hands us
;	A = card type
;	X = I/O base ($F000)
;	Y = our base
;	S = high RAM at EF7F
;	P = interrupts off
;
;	IO at F000, IRAM at F040
;	System variables at EF80
;	CPU vector jump table at EFC4

; configuration:

BLKSIZ	EQU	512
FENCE	EQU	$EC00	; lowest free RAM, 768 byte stack is above

; edit these variables to specify the application load address
; and size in number of 512 byte blocks.

APPSIZ	EQU	$0400	; slightly larger than the KBUG monitor
APPBKS	EQU	$0400/BLKSIZ	; slightly larger than the KBUG monitor

APPLOD	EQU	FENCE-APPSIZ

; loader definitions

CTMMC	EQU	1
CTSD2	EQU	2
CTSDBLK	EQU	3
CTSD1	EQU	4

SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
PDDR	EQU	$08
DDRD	EQU	$09

; must be on zero page for the bootloader

	ORG	0

	FDB	$6811	; disk validation token
START:
	BRA GO

LBAINC:	FDB	$0200	; default is byte mode addressing
CARDTYPE:
	FCB	$00
CMD17:
	FCB $51,0,0,0,0,$01	; initialized to $0200 now to follow loader

GO:
	; Block or byte LBA - set LBAINC accordingly
	STAA CARDTYPE
	CMPA #CTSDBLK
	BNE BYTEMODE
	LDD #1
	STD LBAINC
BYTEMODE:
	LDAA #$50		; SPI on master, faster
	STAA SPCR,X

	LDY #APPLOD		; load destination address
	LDAA #APPBKS		; number of blocks to load

LOADLOOP:
	PSHA			; Save count
	PSHY			; Save pointer whist we do the command

	LDY #CMD17
	LDD 3,Y			; Update the offset or LBA number
	ADDD LBAINC
	STD 3,Y
	JSR SENDCMD		; Send a read command
	BNE SDFAIL
WAITDATA:
	BSR SENDFF		; Wait for the FE marker
	CMPB #$FE
	BNE WAITDATA
				; Move on an LBA block
	PULY			; recover data pointer
	CLRA			; Copy count (256*2 = 512 bytes)
DATALOOP:
	BSR SENDFF
	STAB ,Y
	INY
	BSR SENDFF
	STAB ,Y
	INY

	DECA
	BNE DATALOOP

	BSR CSRAISE		; End command
	LDAA #'.'
	BSR OUTCH

	PULA			; Recover counter
	DECA
	BNE LOADLOOP		; Done ?

	LDAA #$0D
	BSR OUTCH
	LDAA #$0A
	BSR OUTCH

	JMP APPLOD		; And run the application

SDFAIL: LDAA #'E'
FAULT:	BSR OUTCH
STOPB:	BRA STOPB

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
LO:	ADDA #'0'
OUTCH:
	BRCLR $2E,X $80 OUTCH
	STAA $2F,X
	RTS

CSLOWER:
	BCLR PDDR,X $20
	RTS
;
;	This lot must preserve A
;
CSRAISE:
	BSET PDDR,X $20
SENDFF:
	LDAB #$FF
SEND:
	STAB SPDR,X
SENDW:
	BRCLR SPSR,X $80 SENDW
	LDAB SPDR,X
	RTS

SENDCMD:
	BSR CSRAISE
	BSR CSLOWER
WAITFF:
	BSR SENDFF
	INCB
	BNE WAITFF
NOWAITFF:
	; Command, 4 bytes data, CRC all preformatted
	LDAA #6
SENDLP:
	LDAB ,Y
	BSR SEND
	INY
	DECA
	BNE SENDLP
	BSR SENDFF
WAITRET:
	BSR SENDFF
	BITB #$80
	BNE WAITRET
	CMPB #$00
	RTS

; debug add ons

PRY:
	pshy			; print data pointer
	psha
	pshb
	xgdy
	bsr	PHEX
	tba
	bsr	PHEX
	LDAA #' '
	BSR OUTCH
	pulb
	pula
	puly
	rts

PRB:
	psha
	tba
	bsr	PHEX
	LDAA #' '
	BSR OUTCH
	pula
	rts

	; force object code size multiple of 512
	ORG	$01FE
	FDB	$6811

	.end
