.INCLUDE "m2560def.inc"

.def temp = r16
.def temp2 = r19
.def receive1 = r17
.def receive2 = r18

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

		;;;;;ldi temp, 0xFF				; Puerto B como salida
		;;;;;out DDRB, temp		
		
		call Usart_init				; Inicializo la USART
		sei							; Habilitacion global de interrupciones
		call SPI_MasterInit 		; Inicializo SPI
		
		call SPI_MasterReceive 		; Me voy a esperar datos de temperatura	
		call Temperature_convert	; Pongo los datos en un registro
		call Usart_Transmit			; Los envio por Bluetooth


HERE: 

		rjmp HERE



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SUBRUTINAS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;USART;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Usart_init:
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

Usart_Transmit:

		ldi temp, UCSR0A
		sbrs temp,UDRE0		
		rjmp Usart_Transmit		; Espero hasta que e buffer de transmision este vacio

		sts UDR0, receive2		; Envio el dato
		
		ret
			
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;INTERRUPCION USART;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Handler_Int_URXC0:

		lds temp, UDR0  ; Leo lo que recibi
		cpi temp, 1		; Lo comparo con un 1
		breq LED_ON		; Si es un 1 voy a prender el LED
		cpi temp, 0		; Lo comparo con un 0
		breq LED_OFF	; Si es un 0 voy a apagar el LED
	
		reti			; Fin de la interrupcion 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SPI;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;Estos deben estar como salida:	
;;;;							MOSI==PB2
;;;;							SCK==PB1
;;;;							#CS==PB0


SPI_MasterInit:

		ldi temp, 0x00			; SCK (PB1) and	#CS (PB0) output, all others input
		ldi temp,(1<<DDB1)|(1<<DDB0)|(1<<DDB7)
		out DDRB,temp
								; Enable SPI, Master, set clock rate fck/4, SPI mode 1
		ldi temp,(1<<SPE)|(1<<MSTR)|(1<<CPHA)
		;ldi temp,(1<<SPE)|(1<<MSTR)
		out SPCR,temp
		
		sbi portb, 0			; Pongo en alto el #CS
		cbi portb, 1			; Pongo en bajo SCK
		ret

SPI_MasterReceive:
		
		cbi portb,0     		; Habilito la lectura poniendo en 0 #CS (negado)
		
		nop						; Espero hasta que se estabilice en 0
		nop
sbi PORTB,7
		call	SPI_Receive
		mov receive1,temp		; Guardo el el dato que vuelve en R17    

		call	SPI_Receive		; Voy otra vez porque son 16 bits
		mov receive2,temp 		; Guardo el el dato que vuelve en R18

		sbi portb,0     		; Deshabilito la lectura poniendo en 1 #CS (negado)		

		ret

SPI_Receive:
		            			; Wait for reception complete
		
		in temp,SPSR
		call ME_LLEGO
		sbrs temp,SPIF			; Me fijo si se activo la interrupcion, es decir si termine de recibir
        rjmp SPI_Receive

		in temp,SPDR 			; Read received data and return
			
		ret

ME_LLEGO:
	in temp2, SPDR				;;;;;;;;;;;No me llega ningun dato del sensor
	sbrc temp2, 0
	cbi PORTB,7
	
	ret



LED_ON:

		sbi PORTB,7 	; Prendo el LED

		reti
		



LED_OFF:

		cbi PORTB,7 	; Apago el LED
	
		reti

Temperature_convert:			; Pone en un registro los bits del 12 al 5, que son los que contienen los valores del 0 al 256 (sin coma)
		
		clc 					; Limpio el Carry
		lsl receive2			; Corro hacia la izquierda
		rol receive1			; Corro hacia la izquiera con carry anterior. Necesito repetir 2 veces mas
		clc 					
		lsl receive2			
		rol receive1
		clc 					
		lsl receive2			
		rol receive1 			; Ahora tengo en receive2 la temperatura que me interesa
		clc

		ret		


