.INCLUDE "m2560def.inc"

.def temp = r16
.def receive = r17

.cseg

.org 0x00
		jmp MAIN

.org URXC0addr			;vector de interrupcion de usart
	rjmp	Handler_Int_URXC0

.org INT_VECTORS_SIZE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;PROGRAMA PRINCIPAL;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


MAIN: 
						; Incializo el stack pointer al final de la RAM
		ldi temp, low(RAMEND)
		out spl, temp
		ldi temp, high(RAMEND)
		out sph, temp	

		ldi temp, 0xFF	; Puerto B como salida
		out DDRB, temp		
		
		call USART_INIT	; Inicializo la USART
		sei				; Habiitacion global de interrupciones
		
		call SPI_MasterInit
		
	

		
HERE: 

		rjmp HERE



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SUBRUTINAS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;INICIALIZACION UART;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
USART_INIT:
						; Seteo velocidad de transmision 9600 b/s
		ldi temp, high((16000000/(8*9600) - 1))
		sts UBRR0H, temp
		ldi temp, low((16000000/(8*9600) - 1))
		sts UBRR0L, temp
						; Doble velocidad
		ldi temp, (1<<U2X0)
		sts UCSR0A, temp
						; Habilito receptor y transmisor 
		ldi temp, (1<<RXCIE0)|(1<<RXEN0)|(1<<TXEN0) ;El primero es para interrupcion por recepcion
		sts UCSR0B,temp
						; Seteo formato: trama de 8bits, 1 bite de stop
		ldi temp, (1<<UCSZ01)|(1<<UCSZ00)
		sts UCSR0C,temp

		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;INCIALIZACION SPI;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SPI_MasterInit:
		ldi temp, 0x00			; Set MOSI (PB2) and SCK (PB1) output, all others input
		ldi temp,(1<<DDB2)|(1<<DDB1)
		out DDRB,temp
								; Enable SPI, Master, set clock rate fck/16, SPI mode 1
		ldi temp,(1<<SPE)|(1<<MSTR)|(1<<SPR0)|(1<<CPHA)
		out SPCR,temp
		
		ret

SPI_MasterReceive:
		
		ldi temp, 0x00
		ldi temp, ~(1<<DDB0)    ; Habilito la lectura poniendo en 0 #CS (negado)
		out DDRB, temp
		in	receive,SPDR		
		
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;INTERRUPCION USART;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Handler_Int_URXC0:

		lds temp, UDR0  ; Leo lo que recibi
		cpi temp, 1		; Lo comparo con un 1
		breq LED_ON		; Si es un 1 voy a prender el LED
		cpi temp, 0		; Lo comparo con un 0
		breq LED_OFF	; Si es un 0 voy a apagar el LED
	
		reti			; Fin de la interrupcion 



LED_ON:

		sbi PORTB,7 	; Prendo el LED
	
		reti
		



LED_OFF:

		cbi PORTB,7 	; Apago el LED
	
		reti



