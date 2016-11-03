;**********************************************************************
;**********************************************************************
;**                                                                  **
;**         M�r�s Laborat�rium II. - 2. m�r�s - h�zi feladat         **
;**                                                                  **
;**   Le�r�s:         Q3(M). F�nyorgona visszaj�tsz�s funkci�val     **
;**                       b�vebb le�r�s�rt l�sd: dokumentacio.pdf    **
;**   Szerz�:         Martinka M�ty�s (EJJKIN)                       **
;**                   Trombit�s P�ter (G08HLM)                       **
;**   M�r�csoport:    CDE4 kurzus, 6. m�r�csoport                    **
;**   K�sz�lt:        2013/2014. II. f�l�v                           **
;**                   2014. 04. 11.                                  **
;**                                                                  **
;**********************************************************************
;**********************************************************************



;*** DEFIN�CI�K ***

; ATMega 128 defin�ci�s f�jl bet�lt�se
.nolist
	.include "m128def.inc" 
.list

; Regiszterkioszt�s
.def	temp	= r16			; �ltal�nos seg�dregiszter
.def	temp2	= r17			; �ltal�nos seg�dregiszter
.def	sstate	= r18			; SW0 aktu�lis �llapota
.def	sprev	= r19			; SW0 el�z� �llapota
.def	pos		= r20			; visszaj�tsz�s aktu�lis poz�ci�ja
.def	tconst	= r21			; id�z�t�shez haszn�lt regiszter

; SRAM foglal�sa
.dseg
	pattern:	.byte	256		; Az elt�rolt mint�k helye
	count:		.byte	1		; Az elt�rolt mint�k sz�ma



;*** RESET �S IT VEKTORT�BLA ***

.cseg 
.org	0x0000		; K�dszegmens kezd�c�me 

jmp		main		; Reset vektor 
jmp		dummy		; EXTINT0 Handler
jmp		dummy		; EXTINT1 Handler
jmp		dummy		; EXTINT2 Handler
jmp		dummy		; EXTINT3 Handler
jmp		dummy		; EXTINT4 Handler (INT gomb)
jmp		dummy		; EXTINT5 Handler
jmp		dummy		; EXTINT6 Handler
jmp		dummy		; EXTINT7 Handler
jmp		dummy		; Timer2 Compare Match Handler 
jmp		dummy		; Timer2 Overflow Handler 
jmp		dummy		; Timer1 Capture Event Handler 
jmp		dummy		; Timer1 Compare Match A Handler 
jmp		dummy		; Timer1 Compare Match B Handler 
jmp		dummy		; Timer1 Overflow Handler 
jmp		t0it		; Timer0 Compare Match Handler 
jmp		dummy		; Timer0 Overflow Handler 
jmp		dummy		; SPI Transfer Complete Handler 
jmp		dummy		; USART0 RX Complete Handler 
jmp		dummy		; USART0 Data Register Empty Hanlder 
jmp		dummy		; USART0 TX Complete Handler 
jmp		dummy		; ADC Conversion Complete Handler 
jmp		dummy		; EEPROM Ready Hanlder 
jmp		dummy		; Analog Comparator Handler 
jmp		dummy		; Timer1 Compare Match C Handler 
jmp		dummy		; Timer3 Capture Event Handler 
jmp		dummy		; Timer3 Compare Match A Handler 
jmp		dummy		; Timer3 Compare Match B Handler 
jmp		dummy		; Timer3 Compare Match C Handler 
jmp		dummy		; Timer3 Overflow Handler 
jmp		dummy		; USART1 RX Complete Handler 
jmp		dummy		; USART1 Data Register Empty Hanlder 
jmp		dummy		; USART1 TX Complete Handler 
jmp		dummy		; Two-wire Serial Interface Handler 
jmp		dummy		; Store Program Memory Ready Handler 



;*** F�PROGRAM, INICIALIZ�CI�K ***

.org	0x0046
main:

	; stack inicializ�l�sa
	ldi		temp,LOW(RAMEND)	; RAMEND = RAM v�gc�me
	out		SPL,temp			; (ld."m128def.inc") 
	ldi		temp,HIGH(RAMEND)
	out		SPH,temp

	; LED0-7 inicializ�l�sa
	ldi		temp, 0xFF			; portbitek kimenetek
	out		DDRC, temp			; PORTC kimenet

	; SW0 inicializ�l�sa
	ldi		temp, 0x00			; portbitek bemenetek
	sts		DDRG, temp			; PORTG bemenet
	ldi		temp, 0xFF			; pull-up enged�lyezve
	sts		PORTG, temp			; PORTG bemenetein

	; SW0 alap�llapot�nak bet�lt�se
	lds		sprev, PING
	andi	sprev, 0x01			; PING LSB SW0 �llapota 

	; BTN0-2 inicializ�l�sa
	ldi		temp, 0x00			; portbitek bemenetek
	out		DDRE, temp			; PORTE bemenet
	ldi		temp, 0xFF			; pull-up enged�lyezve
	out		PORTE, temp			; PORTE bemenetein

	; BNT3 inicializ�l�sa
	ldi		temp, 0x00			; portbitek bemenetek
	out		DDRB, temp			; PORTB bemenet
	ldi		temp, 0xFF			; pull-up enged�lyezve
	out		PORTB, temp			; PORTB bemenetein

	; potm�ter inicializ�l�sa
	ldi		temp,0b00000000		; portbitek bemenetek
	sts		DDRF,temp			; PORTF bemenet
	ldi 	temp, 0b01100011 	; ADMUX: 5V ref, balra igaz�tott, potm�ter
				  ; 01...... 	    REFS = 01 (referenciafesz�lts�g: 5V VCC) 
				  ; ..1..... 	    ADLAR = 1 (balra igaz�tott) 
				  ; ...00011 	    ADMUX = 00011 (potm�ter) 
	out ADMUX, temp 
	ldi 	temp, 0b11100111 	; ADCSRA: folyamatos fut�s, IT, 128-as el�oszt� 
				  ; 1....... 	    ADEN = 1 (A/D enged�lyez�se) 
				  ; .1...... 	    ADSC = 1 (start conversion) 
				  ; ..1..... 	    ADFR = 1 (free running / folyamatos konverzi�) 
				  ; ...0.... 	    ADIF (nem t�r�lj�k a megszak�t�sjelz� flaget) 
				  ; ....0... 	    ADIE = 1 (megszak�t�sok enged�lyez�se) 
				  ; .....111 	    ADPS = 111 (128-as el�oszt�) 
	out ADCSRA, temp
	
	; SRAM-ban �s regiszterben a sz�ml�l�k kinull�z�sa
	ldi		pos, 0x00
	sts		count, pos


	; 10ms id�z�t� inicializ�l�sa

	ldi		tconst, 25			; id�z�t�si konstans (T = 25*10 ms = 250ms)
	ldi		temp, 0b00001111	; Timer 0 TCCR0 regiszter
				  ;	0.......	    FOC=0
				  ;	.0..1...		WGM=10 (CTC mod)
				  ;	..00....		COM=00 (kimenet tiltva)
				  ;	.....111		CS0=111 (CLK/1024)
	out		TCCR0, temp

	ldi		temp, 108			; 11059200Hz/1024 = 108*100
	out		OCR0, temp			; Timer 0 OCR0 regiszter

	ldi		temp, 0b00000010	; Timer IT Mask regiszter
				  ; 000000..		Timer2,1 IT tiltva
				  ; ......1.		OCIE0=1
				  ; .......0		TOIE0=0
	out		TIMSK, temp

	sei							; glob�lis IT enged�lyezve



;*** F�PROGRAM, V�GTELEN CIKLUS ***
		
loop:	lds		sstate,PING				; kapcsol�k �llapt�nak beolvas�sa
		andi	sstate, 0x01			; maszkol�s -> csak sw0 �llapota t�rol�dik, sstate LSB-j�n
		mov		temp, sstate			
		eor		temp, sprev				; jelen �s el�z� �llapot �sszehasonl�t�sa
		brne	sw0it					; ha nem egyezik a k�t �llapot, kapcsl�s volt SW0-n -> kezelj�k
		carry_on:
			mov		sprev, sstate		; aktu�lis �llapot bet�lt�se a k�v. ciklusban val� �sszehasonl�t�shoz
			jmp		loop				; v�gtelen hurok 



;*** SW0 INTERRUPT ***

sw0it:
	ldi		XL, LOW(SRAM_START)		; pointer vissza az SRAM elej�re
	ldi		XH, HIGH(SRAM_START)
	ldi		temp, 0x00
	out		PORTC, temp				; LED-ek els�t�t�t�se
	sbrs	sstate, 0				; SW0 akt�v ?
	jmp		rec_mode_it				; SW0 = 1, felv�tel m�d
	jmp		play_mode_it			; SW0 = 0, lej�tsz�s m�d

rec_mode_it:						; 'interrupt', felv�tel m�d inicializ�l�sa
	ldi		temp, 0
	sts		count, temp
	jmp		carry_on				; visszat�r�s az 'interrupt'-b�l
		
play_mode_it:						; 'interrupt', lej�tsz�si m�d inicializ�l�sa
	ldi		pos, 0
	jmp		carry_on				; visszat�r�s az 'interrupt'-b�l



;*** 10ms TIMER INTERRUPT ***

.dseg
	c_timer:	.byte	1		; c_timer sz�ml�l�, 1 byte helyfoglal�s RAM-ban 

.cseg

t0it:
	push	temp				; seg�dregiszter ment�se
	in		temp, SREG			; st�tusz ment�se
	push	temp
	lds		temp, c_timer		; c_timer sz�ml�l�
	dec		temp				; cs�kkent�se
	sts		c_timer, temp		; �s t�rol�sa
	brne	t0ite				; ugr�s, ha nem j�rt le
	mov		temp, tconst		; sz�ml�l� vissza�ll�t�sa
	sts		c_timer, temp
	sbrs	sstate, 0			; SW0 akt�v ?
	jmp		rec					; SW0 = 1, felv�tel m�d
	jmp		play				; SW0 = 0, lej�tsz�s m�d


; FELV�TEL M�D
rec:
	ldi		tconst, 25			; id�z�t�s rendbe szed�se

	; gombok beolvas�sa
	in 		temp, PINE			; BTN0-2
	in 		temp2, PINB			; BTN3

	; Az 5-7 biteket �tpakoljuk a 0-2 helyekre
	bst		temp, 7
	bld 	temp, 2
	bst		temp, 6
	bld		temp, 1
	bst		temp, 5
	bld		temp, 0

	bst 	temp2, 7			; BTN3 �rt�ke a transzfer regiszterbe
	bld		temp, 3				; visszat�lt�s a j� helyre (temp-ben most BTN0-3 bent van)

	; neg�ljuk a gombok �llapot�t, mert lenyomva 0, de a LED 1-es �llapotban vil�g�t
	ldi		temp2, 0xFF
	eor		temp, temp2
	andi 	temp, 0x0F

	lds		temp2, count		; sz�ml�l� n�vel�se
	inc 	temp2

	breq	rec_overflow		; t�lcsordul�s kezel�se

	sts		count, temp2		; sz�ml�l� vissza�r�sa
	st		X+, temp			; aktu�lis minta t�rol�sa SRAM-ban
	push	temp				; temp t�rol�sa a stack-en

	; jobb oszlopban l�v� LED-ek villogtat�sa
	in		temp2,PORTC			; LED �llapot beolvas�sa
	ldi		temp, 0xFF			; neg�l�s, a villogtat�shoz
	eor		temp2, temp
	andi	temp2, 0xF0

	pop		temp				; temp visszaolvas�sa a stack-r�l
	or		temp, temp2			; bal oszlopban az aktu�lis gombminta, jobb oszlop villog
	jmp		leds

; felv�tel m�d t�lcsordul�s�nak kezel�se
rec_overflow:
	ldi		temp, 0xFF 			; minden LED vil�g�t
	jmp	 	leds


; LEJ�TSZ�S M�D
play:
	in 		temp, ADCH			; potm�ter beolvas�sa

	; 8 �ll�s meghat�roz�sa
	andi	temp, 0xE0			; csak a 3 fels� bit �rdekes
	lsr		temp				; 4-gyel oszt�s, id�z�t�s kezel�s�hez
	lsr 		temp
	inc		temp
	mov		tconst, temp		; tconst be�ll�t�sa arra az id�z�t�sre, amit a potm�ter mutat

	; aktu�lis mentett minta visszaolvas�sa
	ld		temp, X+
	inc 	pos

	; ha k�rbe�rt�nk, �jrakezdj�k
	lds		temp2, count
	sub		temp2, pos
	breq	play_loop

	jmp 	leds


; lej�tsz�s v�g�n ism�tl�s
play_loop:
	ldi		XL, LOW(SRAM_START)		; pointer vissza az SRAM elej�re
	ldi		XH, HIGH(SRAM_START)
	ldi		pos, 0					; poz�ci� regiszter null�z�sa
	jmp		leds


; LED-sor a regiszterb�l a kimenetre
leds:
	out		PORTC, temp


; Timer IT v�ge
t0ite:
	pop		temp					; regiszterek vissza�ll�t�sa
	out		SREG, temp
	pop		temp

; Visszat�r�s az IT-b�l
dummy:
	reti