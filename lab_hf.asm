;**********************************************************************
;**********************************************************************
;**                                                                  **
;**         Mérés Laboratórium II. - 2. mérés - házi feladat         **
;**                                                                  **
;**   Leírás:         Q3(M). Fényorgona visszajátszás funkcióval     **
;**                       bõvebb leírásért lásd: dokumentacio.pdf    **
;**   Szerzõ:         Martinka Mátyás (EJJKIN)                       **
;**                   Trombitás Péter (G08HLM)                       **
;**   Mérõcsoport:    CDE4 kurzus, 6. mérõcsoport                    **
;**   Készült:        2013/2014. II. félév                           **
;**                   2014. 04. 11.                                  **
;**                                                                  **
;**********************************************************************
;**********************************************************************



;*** DEFINÍCIÓK ***

; ATMega 128 definíciós fájl betöltése
.nolist
	.include "m128def.inc" 
.list

; Regiszterkiosztás
.def	temp	= r16			; általános segédregiszter
.def	temp2	= r17			; általános segédregiszter
.def	sstate	= r18			; SW0 aktuális állapota
.def	sprev	= r19			; SW0 elõzõ állapota
.def	pos		= r20			; visszajátszás aktuális pozíciója
.def	tconst	= r21			; idõzítéshez használt regiszter

; SRAM foglalása
.dseg
	pattern:	.byte	256		; Az eltárolt minták helye
	count:		.byte	1		; Az eltárolt minták száma



;*** RESET ÉS IT VEKTORTÁBLA ***

.cseg 
.org	0x0000		; Kódszegmens kezdõcíme 

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



;*** FÕPROGRAM, INICIALIZÁCIÓK ***

.org	0x0046
main:

	; stack inicializálása
	ldi		temp,LOW(RAMEND)	; RAMEND = RAM végcíme
	out		SPL,temp			; (ld."m128def.inc") 
	ldi		temp,HIGH(RAMEND)
	out		SPH,temp

	; LED0-7 inicializálása
	ldi		temp, 0xFF			; portbitek kimenetek
	out		DDRC, temp			; PORTC kimenet

	; SW0 inicializálása
	ldi		temp, 0x00			; portbitek bemenetek
	sts		DDRG, temp			; PORTG bemenet
	ldi		temp, 0xFF			; pull-up engedélyezve
	sts		PORTG, temp			; PORTG bemenetein

	; SW0 alapállapotának betöltése
	lds		sprev, PING
	andi	sprev, 0x01			; PING LSB SW0 állapota 

	; BTN0-2 inicializálása
	ldi		temp, 0x00			; portbitek bemenetek
	out		DDRE, temp			; PORTE bemenet
	ldi		temp, 0xFF			; pull-up engedélyezve
	out		PORTE, temp			; PORTE bemenetein

	; BNT3 inicializálása
	ldi		temp, 0x00			; portbitek bemenetek
	out		DDRB, temp			; PORTB bemenet
	ldi		temp, 0xFF			; pull-up engedélyezve
	out		PORTB, temp			; PORTB bemenetein

	; potméter inicializálása
	ldi		temp,0b00000000		; portbitek bemenetek
	sts		DDRF,temp			; PORTF bemenet
	ldi 	temp, 0b01100011 	; ADMUX: 5V ref, balra igazított, potméter
				  ; 01...... 	    REFS = 01 (referenciafeszültség: 5V VCC) 
				  ; ..1..... 	    ADLAR = 1 (balra igazított) 
				  ; ...00011 	    ADMUX = 00011 (potméter) 
	out ADMUX, temp 
	ldi 	temp, 0b11100111 	; ADCSRA: folyamatos futás, IT, 128-as elõosztó 
				  ; 1....... 	    ADEN = 1 (A/D engedélyezése) 
				  ; .1...... 	    ADSC = 1 (start conversion) 
				  ; ..1..... 	    ADFR = 1 (free running / folyamatos konverzió) 
				  ; ...0.... 	    ADIF (nem töröljük a megszakításjelzõ flaget) 
				  ; ....0... 	    ADIE = 1 (megszakítások engedélyezése) 
				  ; .....111 	    ADPS = 111 (128-as elõosztó) 
	out ADCSRA, temp
	
	; SRAM-ban és regiszterben a számlálók kinullázása
	ldi		pos, 0x00
	sts		count, pos


	; 10ms idõzítõ inicializálása

	ldi		tconst, 25			; idõzítési konstans (T = 25*10 ms = 250ms)
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

	sei							; globális IT engedélyezve



;*** FÕPROGRAM, VÉGTELEN CIKLUS ***
		
loop:	lds		sstate,PING				; kapcsolók állaptának beolvasása
		andi	sstate, 0x01			; maszkolás -> csak sw0 állapota tárolódik, sstate LSB-jén
		mov		temp, sstate			
		eor		temp, sprev				; jelen és elõzõ állapot összehasonlítása
		brne	sw0it					; ha nem egyezik a két állapot, kapcslás volt SW0-n -> kezeljük
		carry_on:
			mov		sprev, sstate		; aktuális állapot betöltése a köv. ciklusban való összehasonlításhoz
			jmp		loop				; végtelen hurok 



;*** SW0 INTERRUPT ***

sw0it:
	ldi		XL, LOW(SRAM_START)		; pointer vissza az SRAM elejére
	ldi		XH, HIGH(SRAM_START)
	ldi		temp, 0x00
	out		PORTC, temp				; LED-ek elsötétítése
	sbrs	sstate, 0				; SW0 aktív ?
	jmp		rec_mode_it				; SW0 = 1, felvétel mód
	jmp		play_mode_it			; SW0 = 0, lejátszás mód

rec_mode_it:						; 'interrupt', felvétel mód inicializálása
	ldi		temp, 0
	sts		count, temp
	jmp		carry_on				; visszatérés az 'interrupt'-ból
		
play_mode_it:						; 'interrupt', lejátszási mód inicializálása
	ldi		pos, 0
	jmp		carry_on				; visszatérés az 'interrupt'-ból



;*** 10ms TIMER INTERRUPT ***

.dseg
	c_timer:	.byte	1		; c_timer számláló, 1 byte helyfoglalás RAM-ban 

.cseg

t0it:
	push	temp				; segédregiszter mentése
	in		temp, SREG			; státusz mentése
	push	temp
	lds		temp, c_timer		; c_timer számláló
	dec		temp				; csökkentése
	sts		c_timer, temp		; és tárolása
	brne	t0ite				; ugrás, ha nem járt le
	mov		temp, tconst		; számláló visszaállítása
	sts		c_timer, temp
	sbrs	sstate, 0			; SW0 aktív ?
	jmp		rec					; SW0 = 1, felvétel mód
	jmp		play				; SW0 = 0, lejátszás mód


; FELVÉTEL MÓD
rec:
	ldi		tconst, 25			; idõzítés rendbe szedése

	; gombok beolvasása
	in 		temp, PINE			; BTN0-2
	in 		temp2, PINB			; BTN3

	; Az 5-7 biteket átpakoljuk a 0-2 helyekre
	bst		temp, 7
	bld 	temp, 2
	bst		temp, 6
	bld		temp, 1
	bst		temp, 5
	bld		temp, 0

	bst 	temp2, 7			; BTN3 értéke a transzfer regiszterbe
	bld		temp, 3				; visszatöltés a jó helyre (temp-ben most BTN0-3 bent van)

	; negáljuk a gombok állapotát, mert lenyomva 0, de a LED 1-es állapotban világít
	ldi		temp2, 0xFF
	eor		temp, temp2
	andi 	temp, 0x0F

	lds		temp2, count		; számláló növelése
	inc 	temp2

	breq	rec_overflow		; túlcsordulás kezelése

	sts		count, temp2		; számláló visszaírása
	st		X+, temp			; aktuális minta tárolása SRAM-ban
	push	temp				; temp tárolása a stack-en

	; jobb oszlopban lévõ LED-ek villogtatása
	in		temp2,PORTC			; LED állapot beolvasása
	ldi		temp, 0xFF			; negálás, a villogtatáshoz
	eor		temp2, temp
	andi	temp2, 0xF0

	pop		temp				; temp visszaolvasása a stack-rõl
	or		temp, temp2			; bal oszlopban az aktuális gombminta, jobb oszlop villog
	jmp		leds

; felvétel mód túlcsordulásának kezelése
rec_overflow:
	ldi		temp, 0xFF 			; minden LED világít
	jmp	 	leds


; LEJÁTSZÁS MÓD
play:
	in 		temp, ADCH			; potméter beolvasása

	; 8 állás meghatározása
	andi	temp, 0xE0			; csak a 3 felsõ bit érdekes
	lsr		temp				; 4-gyel osztás, idõzítés kezeléséhez
	lsr 		temp
	inc		temp
	mov		tconst, temp		; tconst beállítása arra az idõzítésre, amit a potméter mutat

	; aktuális mentett minta visszaolvasása
	ld		temp, X+
	inc 	pos

	; ha körbeértünk, újrakezdjük
	lds		temp2, count
	sub		temp2, pos
	breq	play_loop

	jmp 	leds


; lejátszás végén ismétlés
play_loop:
	ldi		XL, LOW(SRAM_START)		; pointer vissza az SRAM elejére
	ldi		XH, HIGH(SRAM_START)
	ldi		pos, 0					; pozíció regiszter nullázása
	jmp		leds


; LED-sor a regiszterbõl a kimenetre
leds:
	out		PORTC, temp


; Timer IT vége
t0ite:
	pop		temp					; regiszterek visszaállítása
	out		SREG, temp
	pop		temp

; Visszatérés az IT-ból
dummy:
	reti