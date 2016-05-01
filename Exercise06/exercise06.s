            TTL Secure String I/O and Number Output
;****************************************************************
;A program to accept input and conditionally produce output.
;Name:  Alex Pfadenhauer
;Date:  March 1, 2016
;Class:  CMPE-250
;Section:  Lab Section 01 - Tuesdays, 2-4pm
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;April 3, 2015
;****************************************************************
;Assembler directives
            THUMB
            OPT    64            ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET    MKL46Z4.s     ;Included by start.s
            OPT    1             ;Turn on listing
;****************************************************************
;EQUates

MAX_STRING  EQU    79            ;Max number of string characters, including null character

DIVmil		EQU		1000000             ; needed for PutNumU
DIVhund		EQU		100000              ; needed for PutNumU
DIVten		EQU		10000               ; needed for PutNumU
DIVthou		EQU		1000                ; needed for PutNumU
	
PORT_PCR_SET_PTA1_UART0_RX  	EQU  	(PORT_PCR_ISF_MASK :OR: PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  	EQU 	(PORT_PCR_ISF_MASK :OR: PORT_PCR_MUX_SELECT_2_MASK)
SIM_SOPT2_UART0SRC_MCGPLLCLK 	EQU		(1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 	EQU 	(SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  		EQU 	(SIM_SOPT5_UART0ODE_MASK :OR: SIM_SOPT5_UART0RXSRC_MASK :OR: SIM_SOPT5_UART0TXSRC_MASK)
UART0_BDH_9600  				EQU 	0x01
UART0_BDL_9600  				EQU  	0x38
UART0_C1_8N1  					EQU  	0x00
UART0_C2_T_R  					EQU		(UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C3_NO_TXINV  				EQU  	0x00
UART0_C4_OSR_16           		EQU  	0x0F
UART0_C4_NO_MATCH_OSR_16  		EQU  	UART0_C4_OSR_16
UART0_C5_NO_DMA_SSR_SYNC  		EQU  	0x00
UART0_S1_CLEAR_FLAGS  			EQU  	0x1F
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  0xC0
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL46 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
			BL		Init_UART0_Polling      ; set up for data transmission/reception			
			;R0 holds the pointer to the string. It also at times holds the data being transmitted or recieved
			;R1 holds the pointer to the max size of the string allowed (buffer size)
mainloop    LDR     R0,=Instruct			; loads pointer to the instructions
			BL      PutStringSB				; prints the instructions
			LDR 	R0,=THESTRING			; Pointer to the memory variable that holds our string
			LDR 	R1,=MAX_STRING			; Pointer to MAX_STRING
getinstruct BL      GetChar    				; gets a character, stores in R0
			MOVS	R3,R0					; puts a copy of the character in R3 to chill out for a while (it will be used to print the original character)
			CMP		R0,#96					; check to see if it is lowercase
			BGT		skipconvert				; if it is lowercase, skip conversion
			ADDS	R0,R0,#32				; make it lowercase
skipconvert	CMP		R0,#103					; Is it a g?
			BEQ		gBranch					; then branch!
			CMP		R0,#105					; Is it an i?	
			BEQ		iBranch					; then branch!
			CMP		R0,#108					; Is it an l?
			BEQ		lBranch					; then branch!
			CMP		R0,#112					; is it a p?
			BEQ		pBranch					; then branch!
			B		getinstruct				; if it was not any of the acceptable characters, try again
;>>>>>   end main program code <<<<<
;Stay here
            B       .
;>>>>> begin subroutine code <<<<<
;-----------------------------------------------------------------------------------------------------------------------------
gBranch		
			;get a string from the keyboard and store it in the operational string
			;subroutines: PutChar, GetStringSB
			;Input: R3=the command character to be printed, R0=THESTRING pointer
			;Output: None
			;Modify: Saves string from terminal into memory at R0's address, R0
			MOVS	R0,R3					; get ready to print the character
			BL		PutChar					; print the input character
			BL		MoveNextLine            ; print a line feed and carriage return
			MOVS	R0,#60					; load a < character to be printed
			BL		PutChar					; print that bad boy
			LDR 	R0,=THESTRING			; Pointer to the memory variable that holds our string
			BL		GetStringSB				; load the string into memory
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------
iBranch		
			;initialize the operational string to an empty string
			;subroutines: PutChar
			;Input: R3=the command character to be printed, R0=THESTRING pointer
			;Output: None
			;Modify: changes first character of THESTRING in memory to a null terminator, R0, R2
			MOVS	R0,R3					; get ready to print the character
			BL		PutChar					; print the input character
			BL		MoveNextLine            ; print a line feed and carriage return
			LDR 	R0,=THESTRING			; Pointer to the memory variable that holds our string
			MOVS	R2,#0x00				; Loads 0 into R2 to be loaded as a null character
			STRB	R2,[R0,#0]				; Loads 0 into the first byte of THESTRING
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------
lBranch		
			;print the decimal length of the operational string to the terminal
			;subroutines: PutChar, PutStringSB, LengthStringSB, PutNumU
			;Input: R3=the command character to be printed, R0=THESTRING pointer
			;Output: prints length of string to terminal
			;Modify: Modifies memory for THESTRING, R0, R2 (modified by subroutine)	
			MOVS	R0,R3					; get ready to print the character
			BL		PutChar					; print the input character
			BL		MoveNextLine            ; print a line feed and carriage return
			LDR     R0,=Len					; loads pointer to "Length:"
			BL      PutStringSB				; prints "Length:"
			LDR 	R0,=THESTRING			; Pointer to the memory variable that holds our string
			BL		LengthStringSB			; Calculates the length and returns it in R2
			MOVS	R0,R2					; moves the result from LengthStringSB to R0 so it can be used by PutNumU		
			BL		PutNumU					; prints the text decimal representation of the number stored in R0
			BL		MoveNextLine            ; print a line feed and carriage return
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------	
pBranch		
			;print the operational string to the terminal
			;subroutines: PutChar, PutStringSB
			;Input: R3=the command character to be printed, R0=THESTRING pointer
			;Output: Prints string (THESTRING) to terminal
			;Modify: R0
			MOVS	R0,R3					; get ready to print the character
			BL		PutChar					; print the input character
			BL		MoveNextLine            ; print a line feed and carriage return
			MOVS	R0,#62					; load a > character to be printed
			BL		PutChar					; print that bad boy
			LDR 	R0,=THESTRING			; Pointer to the memory variable that holds our string
			BL		PutStringSB				; print the operational string
			MOVS	R0,#62					; load a > character to be printed
			BL		PutChar					; print that bad boy
			BL		MoveNextLine            ; print a line feed and carriage return
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------
GetChar     
			;Receives a single character from the terminal 
			;subroutines: None
			;Input:   None
			;Output:  R0 holds the character received from the terminal
			;Modify:  R0 only
			PUSH    {R5,R6,R7}                          ; push registers R5,R6,R7 so they will not be modified
			LDR		R6,=UART0_BASE
			MOVS	R5,#UART0_S1_RDRF_MASK
POLLRX      LDRB	R7,[R6,#UART0_S1_OFFSET]
			ANDS	R7,R7,R5                            
			BEQ		POLLRX                              ; keep looping until they are not equal, meaning a character is ready to be receieved
		;Recieve character and store in R0
			LDRB 	R0,[R6,#UART0_D_OFFSET]             ; store the character in R2
			POP		{R5,R6,R7}                          ; restore registers R5,R6,R7 to their original state
			BX		LR		                            ; return to where the branch was called from
;------------------------------------------------------------------------------------------------------------------------------ 		
PutChar     
			;Outputs a single character to the terminal
			;subroutines: None
			;Input:   R0 holds a single character to be transmitted
			;Output:  None (except in terminal)
			;Modify:  None
			PUSH    {R5,R6,R7}                          ; push registers R5,R6,R7 so they will not be modified
			LDR		R6,=UART0_BASE
			MOVS	R5, #UART0_S1_TDRE_MASK
POLLTX	    LDRB	R7,[R6, #UART0_S1_OFFSET]           
			ANDS	R7,R7,R5
			BEQ		POLLTX                              ; keep looping until they are not equal- meaning a character is ready to be sent
		;Transmit character stored in R0
			STRB    R0,[R6,#UART0_D_OFFSET]             ; transmit the character stored in R0
			POP		{R5,R6,R7}                          ; restore registers R5,R6,R7 to their original state
			BX		LR                                  ; return to where the branch was called from
;-----------------------------------------------------------------------------------------------------------------------------
MoveNextLine
            ;Description:   Prints carriage return and line feed characters to the terminal
			;subroutines:   PutChar
			;Input: 	    None
			;Output: 	    No registers, prints characters to terminal
			;Modify:        None
            PUSH    {R0,LR}                 ; preserve R0 and the LR
            MOVS	R0,#0x0D				; load a carriage return character to be printed
			BL		PutChar					; print that bad boy
			MOVS	R0,#0x0A				; load a line feed character to be printed
			BL		PutChar					; print that bad boy
            POP     {R0,PC}                 ; restore R0 and return to where it was called from
;------------------------------------------------------------------------------------------------------------------------------       
PutStringSB 
			;Displays a null-terminated string to the terminal screen
			;subroutines: PutChar
			;Input:  	R0 holds the address of the string that will be printed
			;Output: 	None (Except printed output in terminal)
			;Modify: 	None
			PUSH    {R0-R2,LR}		    				; stores registers to keep values from being overwritten (data & LR)
			MOVS	R2,#0								; clear R2 so it can be used as the incremental offset
			MOVS	R1,R0								; store the string address in R1 so that R0 can be overwritten
PSSBloop    LDRB    R0,[R1,R2]                          ; load the next value from the string into R0 to be printed
            CMP     R0,#0                               ; if it is a null character, we are at the end of the line
            BEQ     PSSBend                             ; if it is null character, quit
			;otherwise... print and keep looping
            BL      PutChar                             ; print the character stored at R0 to the terminal
            ADDS    R2,R2,#1                            ; add 1 to the number of bytes past R0
            B       PSSBloop                            ; keep looping
PSSBend     POP     {R0-R2,PC}		    				; restores registers, returns to where it was called from
;------------------------------------------------------------------------------------------------------------------------------ 
GetStringSB 
			;reads a string from terminal, prints on terminal and stores in memory
			;subroutines: PutChar, GetChar
			;Input: 	R0 is the pointer to where the string is stored, R1 holds the pointer to the max string length
			;Output: 	modifies the operational string
			;Modify: 	None
			PUSH    {R0-R3,LR}                 	     	; stores the contents of the registers so they won't be overwritten
            MOVS    R3,#0                               ; makes sure R3 initially holds 0 (byte incremental counter)
			MOVS	R2,R0								; stores address of string in R2 so that R0 is free for data
			SUBS	R1,R1,#1							; subtracts 1 from R1 so that it will compare correctly
            ;R2 holds starting address
            ;R1 holds buffer size
            ;R0 holds starting address, then current character
            ;R3 holds how far we have advanced
GSSBloop  	BL		GetChar                             ; gets character from terminal, stores in R0
			CMP     R3,R1                               ; compares the current size of our string to the max size allowed
            BGE     GSSBskip                            ; if we're overflowing, stop doing shit! keeps looping but does not store or display characters     
       ;if it gets this far, we haven't overflowed                          
            CMP     R0,#13                              ; if character is carriage return....
            BEQ     GSSBend                             ; quit! (it was already stored)
			CMP		R0,#127								; if character is a backspace...
			BEQ		GSSBbksp							; go back one byte and keep looping!
       ;if it gets this far, it wasn't a carriage return or backspace
            STRB    R0,[R2,R3]                          ; stores the character at address [base add=R2 + R3 bytes]
            ADDS    R3,R3,#1                            ; increments R3, so we are now 1 byte further away from R2 for the next character to be stored          
            BL		PutChar                             ; sends character in R0 to terminal
            B       GSSBloop							; keep looping!
GSSBskip    CMP     R0,#13                              ; if character is carriage return....
            BEQ     GSSBend                             ; then stop looping
            B		GSSBloop                            ; keep looping
GSSBend     MOVS	R0,#0								; loads R0 with 0 to represent null character, to terminate
            STRB    R0,[R2,R3]                          ; stores the null character
			MOVS	R0,#0x0D							; load a carriage return character to be printed
			BL		PutChar								; print that bad boy
			MOVS	R0,#0x0A							; load a line feed character to be printed
			BL		PutChar								; print that bad boy
            POP     {R0-R3,PC}          	            ; restores the contents of the registers to their original glory and returns to where it was called from
GSSBbksp	CMP		R3,#0								; make sure R3 isn't already at the starting address
			BEQ		GSSBloop							; if it is, just keep looping
			SUBS	R3,R3,#1							; otherwise, move it one byte back toward the starting address
			MOVS	R0,#127								; load backspace character to send to terminal
			BL		PutChar								; tell terminal to backspace
			B		GSSBloop							; then keep looping
;------------------------------------------------------------------------------------------------------------------------------ 
LengthStringSB      
			;determines how many characters are in the string stored in memory at R0
			;subroutines: None
			;Input: 	R0 holds pointer to string that is being checked
			;Output: 	R2 holds the number of characters in the string
			;Modify: 	R2
            PUSH    {R1}                                ; stores registers to keep values from being overwritten
            MOVS    R2,#0                               ; makes sure R2 is zero to start - this holds the number of characters
LSSBloop    LDRB    R1,[R0,R2]                          ; load the value to check into R1
            CMP     R1,#0                               ; if it is a null character, we are at the end of the line
            BEQ     LSSBexit                            ; if it is null character, quit
            ;otherwise... increment and keep looping
            ADDS    R2,R2,#1                            ; add 1 to the number of characters
            B       LSSBloop                            ; keep counting characters
LSSBexit    POP     {R1}
            BX      LR		                            ; restarts   
;------------------------------------------------------------------------------------------------------------------------------ 
DIVU		
            ;description:   Performs remainder division on dividend in R1 and divisor in R0
			;subroutines:   None
			;Input:         R0: divisor, R1: dividend
			;Output:        R0: Quotient, R1: Remainder
			;Modify:        R0, R1
			PUSH    {R5-R7}		; push R5-R7 onto the stack so the registers are freed up for calculations
			CMP		R0,#0		; compare divisor to 0
			BEQ		DIVUcont	; if divisor is 0, turn the carry bit on and quit.
			;otherwise...
			MOVS    R5,#0       ; makes sure R2 holds zero, to store the quotient
            MOVS    R6,#0       ; make sure R3 is cleared (holds 0)
DIVUloop    CMP     R1,R0       ; compares the dividend to the divisor
            BLO     DIVUend     ; if the dividend is less than the divisor, stop looping!
            ADDS    R5,R5,#1    ; increment the quotient by 1
			SUBS    R1,R1,R0    ; subtract the divisor from the dividend
            B       DIVUloop    ; continue looping
DIVUend     MOVS    R0,R5       ; moves the quotient to R0
			MRS     R5,APSR     ; loads APSR into R2
            MOVS    R6,#0x20    ; loads 00000000 00000000 00000000 00100000 into R3
            LSLS    R6,R6,#24   ; changes R3 to 00100000 00000000 00000000 00000000, so the bit corresponding with the carry bit is the only one on
            BICS    R5,R5,R6    ; clears any bits that are on in R3, leaves the rest unaltered. so it clears the carry bit
            MSR     APSR,R5     ; returns the modified APSR to the actual one, overwriting it
			B 		DIVUquit	; Quit
DIVUcont	MRS     R5,APSR     ; loads APSR into R2
            MOVS    R6,#0x20 	; loads 00000000 00000000 00000000 00100000 into R3
            LSLS    R6,R6,#24   ; changes R3 to 00100000 00000000 00000000 00000000, so the bit corresponding with the carry bit is the only one on
            ORRS    R5,R5,R6    ; turns on any bits that are on in R3, leaves the rest unaltered. so it turns on the carry bit
            MSR     APSR,R5     ; stores altered APSR
DIVUquit    POP     {R5-R7}     ; pop R5-R7 to return the registers to their initial values
    		BX		LR			; Quit
;-----------------------------------------------------------------------------------------------------------------------------
PutNumU
            ;description: converts hex number to decimal and outputs to terminal
			;subroutines: DIVU, PutChar
			;Input: 	R0=a hex number to be printed
			;Output: 	No registers, prints a decimal number to the terminal
			;Modify:	None
			PUSH	{R0-R2,LR}	; saves registers from being overwritten
			CMP		R0,#0		; is the number that is being printed zero?
			BEQ		PNUzero		; if so, just print zero and quit!
			MOVS	R2,#0		; R2 holds whether a non-zero number has been printed previously
			MOVS	R1,R0		; move the number being divided into the dividend spot		
PNUmil		LDR		R0,=DIVmil	; make 1,000,000 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
PNUhundth	LDR		R0,=DIVhund	; make 100,000 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
PNUtenth	LDR		R0,=DIVten	; make 10,000 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
PNUthou		LDR		R0,=DIVthou	; make 1,000 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
PNUhund		MOVS	R0,#100		; make 100 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
PNUten		MOVS	R0,#10		; make 10 the divisor
			BL		DIVU		; perform the division. Produces quotient in R0 and Remainder in R1
			BL		PNUprint	; print the number (or skip printing if digit is zero and no non-zero #s have been printed yet)
			MOVS	R0,R1		; move the remainder to R0 to be printed
			ADDS	R0,R0,#48	; convert the number to ASCII for printing
			BL		PutChar		; print the number (we don't have to check for 0 because this is last digit and we know whole number isn't 0)
			POP		{R0-R2,PC}	; restores registers and returns
PNUzero		MOVS	R0,#48		; put 0 in R0 to be printed		
			BL		PutChar		; print 0
			POP		{R0-R2,PC}	; restores registers and returns
;-----------------------------------------------------------------------------------------------------------------------------
PNUprint	
			;Description:   helper subroutine for PutNumU
			;subroutines:   PutChar
			;Input: 	    R2 = flag for non-zero already printed, R0 = number to print
			;Output: 	    no registers, prints character to terminal in certain cases
			;Modify:	    R2 in certain cases, R0 in certain cases
			PUSH	{LR}
			CMP		R2,#1		; has a non-zero number been printed already?
			BEQ		PNUprintit	; if so, you need to print!
			CMP		R0,#0		; is the number to print zero?
			BEQ		PNUreturn	; if so, don't print anything!
			MOVS	R2,#1		; set R2 to say a non-zero number has been printed
PNUprintit	ADDS	R0,R0,#48	; converts the number to ASCII
			BL		PutChar		; prints the number in R0
PNUreturn	POP		{PC}		; return to where it was called from 	
;-----------------------------------------------------------------------------------------------------------------------------
Init_UART0_Polling
			PUSH	{R0-R3}                                 ;store registers R0-R3 so they won't be modified
		;Select MCGPLLCLK / 2 as UART0 clock source
			LDR     R0,=SIM_SOPT2
			LDR     R1,=SIM_SOPT2_UART0SRC_MASK
			LDR     R2,[R0,#0]
			BICS    R2,R2,R1
			LDR     R1,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
			ORRS    R2,R2,R1
			STR     R2,[R0,#0]
		;Enable external connection for UART0
			LDR     R0,=SIM_SOPT5
			LDR     R1,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
			LDR     R2,[R0,#0]
			BICS    R2,R2,R1
			STR     R2,[R0,#0]
		;Enable clock for UART0 module 
			LDR     R0,=SIM_SCGC4
			LDR     R1,=SIM_SCGC4_UART0_MASK
			LDR     R2,[R0,#0]
			ORRS    R2,R2,R1
			STR     R2,[R0,#0]
		;Enable clock for Port A module
			LDR     R0,=SIM_SCGC5
			LDR     R1,=SIM_SCGC5_PORTA_MASK
			LDR     R2,[R0,#0]
			ORRS    R2,R2,R1
			STR     R2,[R0,#0]
		;Connect PORT A Pin 1 (PTA1) to UART0 Rx (J1 Pin 02)
			LDR     R0,=PORTA_PCR1
			LDR     R1,=PORT_PCR_SET_PTA1_UART0_RX
			STR     R1,[R0,#0]
		;Connect PORT A Pin 2 (PTA2) to UART0 Tx (J1 Pin 04)
			LDR     R0,=PORTA_PCR2
			LDR     R1,=PORT_PCR_SET_PTA2_UART0_TX
			STR     R1,[R0,#0] 
		;Disable UART0 receiver and transmitter
			LDR		R0,=UART0_BASE
			MOVS 	R1,#UART0_C2_T_R
			LDRB 	R2,[R0,#UART0_C2_OFFSET]
			BICS 	R2,R2,R1
			STRB 	R2,[R0,#UART0_C2_OFFSET]
	   ;Set UART0 for 9600 baud, 8N1 protocol
			MOVS 	R1,#UART0_BDH_9600
			STRB 	R1,[R0,#UART0_BDH_OFFSET]
			MOVS 	R1,#UART0_BDL_9600
			STRB 	R1,[R0,#UART0_BDL_OFFSET]
			MOVS 	R1,#UART0_C1_8N1
			STRB 	R1,[R0,#UART0_C1_OFFSET]
			MOVS 	R1,#UART0_C3_NO_TXINV
			STRB 	R1,[R0,#UART0_C3_OFFSET]
			MOVS 	R1,#UART0_C4_NO_MATCH_OSR_16
			STRB 	R1,[R0,#UART0_C4_OFFSET]
			MOVS 	R1,#UART0_C5_NO_DMA_SSR_SYNC
			STRB 	R1,[R0,#UART0_C5_OFFSET]
			MOVS 	R1,#UART0_S1_CLEAR_FLAGS
			STRB 	R1,[R0,#UART0_S1_OFFSET]
			MOVS 	R1,#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
			STRB 	R1,[R0,#UART0_S2_OFFSET]
		;Enable UART0 receiver and transmitter
			MOVS 	R1,#UART0_C2_T_R
			STRB 	R1,[R0,#UART0_C2_OFFSET]
			POP		{R0-R3}                             ;restore registers R0-R3 to their original state
			BX		LR                                  ;return to where the branch was called from
;------------------------------------------------------------------------------------------------------------------------------                       
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    Dummy_Handler      ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD    Dummy_Handler      ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    Dummy_Handler      ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<

Instruct    DCB     "Type a string command (g,i,l,p):", 0
Len         DCB     "Length:", 0

;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<

THESTRING	SPACE 	MAX_STRING

;>>>>>   end variables here <<<<<
            ALIGN
            END
