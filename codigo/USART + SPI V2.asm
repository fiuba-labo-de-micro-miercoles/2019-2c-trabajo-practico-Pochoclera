.INCLUDE "m2560def.inc"

.def temp 		= r16
.def receive1 	= r17
.def receive2 	= r18
.def cant_shift = r19
.def cont1 		= r20 
.def cont2 		= r21

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

		
HERE:
		
		call Usart_init				; Inicializo la USART
		sei							; Habilitacion global de interrupciones

		call Var_init				; Incializo variables varias

		ldi receive1, 0				; Inicializo
		ldi receive2, 0				;
		ldi temp, 0					;

		call SPI_MasterInit 		; Inicializo SPI
		call SPI_MasterReceive 		; Me voy a esperar datos de temperatura	
		call Temperature_convert	; Pongo los datos en un registro
		call Usart_Transmit			; Los envio por Bluetooth

		ldi r30, 255				; Contador
		call Delay_1s		

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

;		ldi temp, UCSR0A
;		sbrs temp,UDRE0
;		rjmp Usart_Transmit		; Espero hasta que e buffer de transmision este vacio


		sts UDR0, receive2		; Envio el dato
		sts UDR0, receive1

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
		;ldi temp,(1<<SPE)|(1<<MSTR)|(1<<CPHA)
		;out SPCR,temp
		
		sbi portb, 0			; Pongo en alto el #CS
		call Var_init
		call delay_1ms

		clt						; Limpio el flag T		

		ret

SPI_MasterReceive:
		
		cbi portb,0     		; Habilito la lectura poniendo en 0 #CS (negado)
		call Var_init
		call delay_1ms			; Espero a que se estabilice

		ldi cant_shift, 7
		call	SPI_Read
		mov receive1,temp		; Guardo el dato que vuelve en R17    
		
		ldi cant_shift, 7
		ldi temp, 0
		call	SPI_Read		; Voy otra vez porque son 16 bits
		mov receive2,temp 		; Guardo el dato que vuelve en R18

		sbi portb,0     		; Deshabilito la lectura poniendo en 1 #CS (negado)		
				

		ret

SPI_Read:
			
		cbi portb, 1			; Pono en bajo el clock
		call Var_init
		call Delay_1ms			; Espero 1ms

		sbic pinb, 3			; Salto de linea si en miso me llego un 0		
		set						; Seteo el flag T

		bld temp, 0				; Coloco lo que tengo en flag T en el bit 0 de receive1
		lsl temp				; Shifteo

		sbi portb, 1			; Pongo en alto el clock
		call Var_init
		call Delay_1ms			; Espero 1ms
		
		dec cant_shift			; Contador, lo quiero hacer 7 veces
		clt
		brne SPI_read
			
		ret

LED_ON:

		sbi PORTB,7 	; Prendo el LED

		reti
		



LED_OFF:

		cbi PORTB,7 	; Apago el LED
	
		reti

Temperature_convert:
		
		cbr receive2, 7 		; Limpio los ultimos 3bits
		
		clc 					; Limpio el Carry
		lsl receive2			; Corro hacia la izquierda
		rol receive1			; Corro hacia la izquiera con carry anterior.
		clc 					
	
		ret		

Delay_1ms: 

		ldi cont2, 20	;1		
		dec cont1		;1    
		brne loop		;2	
		    	
		ret				;1		

loop:		
		dec cont2 		;1			
		brne loop		;2		
		jmp Delay_1ms	;3	


Var_init:
	
		ldi cont1, 243			; Contador para delay

		ret


Delay_250ms:
	
		call Delay_1ms
		dec r30
		brne Delay_250ms
		
		ret

Delay_1s:
		call Delay_250ms			;
		call Delay_250ms			;
		call Delay_250ms			
		call Delay_250ms
		
		ret
