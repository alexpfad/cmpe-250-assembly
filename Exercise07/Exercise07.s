              TTL Circular FIFO Queue Operations
;****************************************************************
;A program which uses subroutines to enqueue and dequeue characters.
;Name:  Alex Pfadenhauer
;Date:  March 8, 2016
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
    
IN_PTR      EQU     0
OUT_PTR     EQU     4
BUF_STRT    EQU     8
BUF_PAST    EQU     12
BUF_SIZE    EQU     16
NUM_ENQD    EQU     17    
    
DIVmil		EQU		1000000             ; needed for PutNumU
DIVhund		EQU		100000              ; needed for PutNumU
DIVten		EQU		10000               ; needed for PutNumU
DIVthou		EQU		1000                ; needed for PutNumU    
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
			LDR     R0,=QueueBuffer         ; loads address of QueueBuffer for InitQueue
            LDR     R1,=QueueRecord         ; loads address of QueueRecord for InitQueue
            MOVS    R2,#4                   ; loads the size of the buffer for InitQueue
            BL      InitQueue               ; set up the queue
            ; R0 holds the queue buffer address
            ; R1 holds the queue record structure address
            ; R2 holds the queue buffer size (character capacity)
mainloop    PUSH    {R0}                    ; preserve R0
            LDR     R0,=Instruct			; loads pointer to the instructions
			BL      PutStringSB				; prints the instructions
            POP     {R0}                    ; restore R0
getinstruct PUSH    {R0}                    ; preserve R0
            BL      GetChar    				; gets a character, stores in R0
			MOVS	R3,R0					; puts a copy of the character in R3 to chill out for a while (it will be used to print the original character)
            MOVS    R4,R0                   ; moves the character to R4 so we can use it for comparison
            POP     {R0}                    ; restore R0
			CMP		R4,#96					; check to see if it is lowercase
			BGT		skipconvert				; if it is lowercase, skip conversion
			ADDS	R4,R4,#32				; make it lowercase
skipconvert	CMP		R4,#'h'					; Is it a h?
			BEQ		hBranch					; then branch!
			CMP		R4,#'s'					; Is it an s?	
			BEQ		sBranch					; then branch!
			CMP		R4,#'d'					; Is it an d?
			BEQ		dBranch					; then branch!
            CMP		R4,#'e'					; Is it an e?
			BEQ		eBranch					; then branch!
			CMP		R4,#'p'					; is it a p?
			BEQ		pBranch					; then branch!
			B		getinstruct				; if it was not any of the acceptable characters, try again
;-----------------------------------------------------------------------------------------------------------------------------
hBranch		
            ;description:   Prints help instructions consisting of each command option
			;subroutines:   PrintInputChar, MoveNextLine, PutStringSB
			;Input:         R3 holds command character, used by PrintInputChar
			;Output:        No registers, prints help instructions to terminal
			;Modify:        None
			BL      PrintInputChar          ; print the input character
			BL      MoveNextLine            ; print a carriage return and line feed
			PUSH    {R0}                    ; Preserve R0
            LDR     R0,=helpprint			; loads pointer to the help instructions
			BL      PutStringSB				; prints the help instructions
            POP     {R0}                    ; restore R0
            BL      MoveNextLine            ; print a carriage return and line feed
			B		mainloop				; start over!            
;-----------------------------------------------------------------------------------------------------------------------------
sBranch		
            ;description:   Prints the queue's current InPointer, OutPointer, and NumberEnqueued
			;subroutines:   MoveNextLine, PrintInputChar, PutStringSB, PrintStatus
			;Input:         R3 = command char to print, R0 = buffer address, R1 = record struct address, R2 = buffer size 
			;Output:        No registers, prints to terminal
			;Modify:        None
			BL      PrintInputChar          ; print the input character
			BL      MoveNextLine            ; print a carriage return and line feed
            PUSH    {R0}                    ; preserve R0
            LDR     R0,=statusPrint         ; load string to print
            BL      PutStringSB             ; print "Status:"
            POP     {R0}                    ; restore R0
            BL      PrintStatus             ; print the status
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------	
pBranch		
            ;description:   prints the queued characters from the queue buffer to the terminal screen, in order from first in to last in 
			;subroutines:   PutChar, MoveNextLine, PrintInputChar
			;Input:         R1 = queue record structure address, R3 = command character to print
			;Output:        No registers, output to terminal 
			;Modify:        None
			BL      PrintInputChar          ; print the input character
			BL      MoveNextLine            ; print a carriage return and line feed
			PUSH    {R0}                    ; preserve R0
            MOVS    R0,#'>'                 ; store > in R0 to be printed
            BL      PutChar                 ; print >
            POP     {R0}                    ; restore R0
            PUSH    {R0,R3-R6}              ; preserves registers
            LDR     R4,[R1,#OUT_PTR]        ; stores the out pointer in R4
            LDR     R5,[R1,#BUF_PAST]       ; stores the bufferPast address in R5
            LDRB    R3,[R1,#NUM_ENQD]       ; store the number of enqueued characters in R3
            MOVS    R6,#0                   ; initialize R6 to 0 to hold number of characters printed
ploop       CMP     R6,R3                   ; compare the number of printed characters to the number of enqueued characters
            BEQ     pexit                   ; if we have printed all the characters, quit!
            LDRB    R0,[R4,#0]              ; loads the character at the OutPointer into R0
            BL      PutChar                 ; prints the character in R0
            ADDS    R6,R6,#1                ; increments the number of printed characters
            ADDS    R4,R4,#1                ; increments OutPointer
            CMP     R4,R5                   ; compares the current OutPointer to BuffPast
            BLT     ploop                   ; if the OutPointer is not past the end of the buffer, keep looping
            LDR     R4,[R1,#BUF_STRT]       ; otherwise, reset the OutPointer to the buffer start address!
            b       ploop                   ; keep looping
pexit       POP     {R0,R3-R6}              ; restores registers
            PUSH    {R0}                    ; preserve R0
            MOVS    R0,#'<'                 ; store < in R0 to be printed
            BL      PutChar                 ; print <
            POP     {R0}                    ; restore R0
            BL      MoveNextLine            ; print a carriage return and line feed
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------
dBranch		
            ;description:   Dequeue a character from the queue
			;subroutines:   PrintInputChar, MoveNextLine, Dequeue, PutChar, PutStringSB, PrintStatus
			;Input:         R1 = queue record structure address, R3 = command character to print
			;Output:        No registers, prints to terminal
			;Modify:        No registers, memory
			BL      PrintInputChar          ; print the input character
			BL      MoveNextLine            ; print a carriage return and line feed
            PUSH    {R0}                    ; preserves R0 
            BL      Dequeue                 ; dequeue a character from the queue, if possible
            BCS     dquefail                ; if the carry flag is set, this means the dequeue failed, so branch to dquefail
            ;otherwise, dequeue was successful!
            BL      PutChar                 ; print the character that was dequeued
            MOVS    R0,#':'                 ; moves : into R0 to be printed
            BL      PutChar                 ; prints :
            LDR     R0,=spacePrint          ; load spaces for formatting
            BL      PutStringSB             ; print spaces for formatting
            B       dquequit                ; print status and quit
dquefail    LDR     R0,=failPrint           ; loads string to print
            BL      PutStringSB             ; prints "Failure:"
dquequit    POP     {R0}                    ; restores R0   
            BL      PrintStatus             ; print the status                
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------
eBranch		
            ;description:   enqueue a character to the queue (Prompt to enter a character, and then enqueue it)
			;subroutines:   MoveNextLine, PrintInputChar, PutStringSB, GetChar, PutChar, Enqueue, PrintStatus
			;Input:         R1 = queue record structure address, R3 = command character to print
			;Output:        No registers, prints to terminal
			;Modify:        No Registers, memory
			BL      PrintInputChar          ; print the input character
			BL      MoveNextLine            ; print a carriage return and line feed
            PUSH    {R0}                    ; preserves R0
            LDR     R0,=equPrint            ; loads the instructions to print
            BL      PutStringSB             ; prints the instructions
            BL      GetChar                 ; accepts the character to enqueue and stores in R0
            BL      PutChar                 ; prints the character to be enqueued
            BL      MoveNextLine            ; prints a carriage return and line feed
            BL      Enqueue                 ; enqueues the character in R0
            BCS     equefail                ; if the carry flag is set (enqueue failed), branch to equefail
            LDR     R0,=succPrint           ; loads the string to print
            BL      PutStringSB             ; prints "Success:"
            B       equequit                ; print status and return to mainloop
equefail    LDR     R0,=failPrint           ; loads the string to print
            BL      PutStringSB             ; prints "Failure:"
equequit    POP     {R0}                    ; restores R0
            BL      PrintStatus             ; print status
			B		mainloop				; start over!
;-----------------------------------------------------------------------------------------------------------------------------	
;>>>>>   end main program code <<<<<
;Stay here
            B       .
;>>>>> begin subroutine code <<<<<
;------------------------------------------------------------------------------------------------------------------------------ 
Dequeue  
            ;description:   Removes a character from the queue if possible and sets the carry flag accordingly
			;subroutines:   None
			;Input:         R1 = address of queue record structure
			;Output:        PSR carry flag (0 = success, 1 = failure), R0 = Dequeued character
			;Modify:        No registers, PSR
            PUSH    {R3-R6}                 ; preserves the registers
            LDRB    R3,[R1,#NUM_ENQD]       ; loads the NumEnqueued into R3
            CMP     R3,#0                   ; compares the number enqueued to 0
            BEQ     DEQcarry                ; if nothing is enqueued, set the carry flag and quit
            LDR     R5,[R1,#OUT_PTR]        ; loads OutPointer into R5
            LDR     R6,[R1,#BUF_PAST]       ; loads BufferPast into R6
            LDRB    R0,[R5,#0]              ; Dequeues the character (gets it from address specified by OutPointer)
            SUBS    R3,R3,#1                ; decrements NumEnqueued
            STRB    R3,[R1,#NUM_ENQD]       ; stores the new NumEnqueued
            ADDS    R5,R5,#1                ; increments OutPointer
            CMP     R5,R6                   ; compares OutPointer to BuffPast
            BLO     DEQskiprst              ; if the OutPointer is less than BuffPast, skip resetting it to BuffStart
            LDR     R5,[R1,#BUF_STRT]       ; otherwise, reset the InPointer to BuffStart
DEQskiprst  STR     R5,[R1,#OUT_PTR]        ; store the new InPointer
            MRS     R3,APSR                 ; loads APSR into R3
            MOVS    R4,#0x20                ; loads binary 00100000 into R4 (for ORRS)
            LSLS    R4,R4,#24               ; shifts so that it is most significant
            BICS    R3,R3,R4                ; turns off carry flag
            MSR     APSR,R3                 ; sets the status register     
            B       DEQquit                 ; exit
DEQcarry    MRS     R3,APSR                 ; loads APSR into R2
            MOVS    R4,#0x20                ; loads binary 00100000 into R4 (for ORRS)
            LSLS    R4,R4,#24               ; shifts so that it is most significant
            ORRS    R3,R3,R4                ; turns on carry flag
            MSR     APSR,R3                 ; sets the status register
DEQquit     POP     {R3-R6}                 ; restores the registers 
            BX      LR                      ; returns to where it was called from
;------------------------------------------------------------------------------------------------------------------------------ 
Enqueue
            ;description:   Enqueues the input character if possible and sets the carry flag accordingly
			;subroutines:   None
			;Input:         R0 = character to enqueue, R1 = address of queue record structure
			;Output:        PSR carry flag (0 = success, 1 = failure)
			;Modify:        No registers, PSR
            PUSH    {R3-R6}                 ; preserves the registers
            LDRB    R3,[R1,#NUM_ENQD]       ; loads the NumEnqueued into R3
            LDRB    R4,[R1,#BUF_SIZE]       ; loads the buffer size into R4
            CMP     R3,R4                   ; compares the number enqueued to the buffer size
            BGE     ENcarry                 ; if number enqueued is greater or equal to buffer size, set carry flag and quit
            LDR     R5,[R1,#IN_PTR]         ; loads InPointer into R5
            LDR     R6,[R1,#BUF_PAST]       ; loads BufferPast into R6
            STRB    R0,[R5,#0]              ; Enqueues the character (stores it at address specified by InPointer)
            ADDS    R3,R3,#1                ; increments NumEnqueued
            STRB    R3,[R1,#NUM_ENQD]       ; stores the new NumEnqueued
            ADDS    R5,R5,#1                ; increments InPointer
            CMP     R5,R6                   ; compares InPointer to BuffPast
            BLO     ENskiprst               ; if the InPointer is less than BuffPast, skip resetting it to BuffStart
            LDR     R5,[R1,#BUF_STRT]       ; otherwise, reset the InPointer to BuffStart
ENskiprst   STR     R5,[R1,#IN_PTR]         ; store the new InPointer
            MRS     R3,APSR                 ; loads APSR into R3
            MOVS    R4,#0x20                ; loads binary 00100000 into R4 (for ORRS)
            LSLS    R4,R4,#24               ; shifts so that it is most significant
            BICS    R3,R3,R4                ; turns off carry flag
            MSR     APSR,R3                 ; sets the status register     
            B       ENquit                  ; exit
ENcarry     MRS     R3,APSR                 ; loads APSR into R2
            MOVS    R4,#0x20                ; loads binary 00100000 into R4 (for ORRS)
            LSLS    R4,R4,#24               ; shifts so that it is most significant
            ORRS    R3,R3,R4                ; turns on carry flag
            MSR     APSR,R3                 ; sets the status register
ENquit      POP     {R3-R6}                 ; restores the registers 
            BX      LR                      ; returns to where it was called from
;------------------------------------------------------------------------------------------------------------------------------ 
PutNumHex
            ;description:   prints a hex address to the terminal
			;subroutines:   PutChar
			;Input:     R0=Unsigned word value to print in hex    
			;Output:    No registers, prints to terminal
			;Modify:    No Registers, PSR
            PUSH        {R0,R1,R7,LR}   ; preserve registers
            MOVS        R7,R0           ; moves value to R7 so we have a copy to restore later
            MOVS        R1,#0           ; the amount to left shift   
PNHloop     MOVS        R0,R7           ; restore the number to keep working 
            LSLS        R0,R0,R1        ; Left shift to trim the excess number
            LSRS        R0,R0,#28       ; Right shift to trim the excess number
            CMP         R0,#10          ; is it single digit or double digit?
            BGE         PNHhex          ; if it is double digit decimal, it is a hex letter and should be converted differently
            ADDS        R0,R0,#48       ; if it is a single digit number, we convert to ascii accordingly
            B           PNHprint        ; print the character!
PNHhex      ADDS        R0,R0,#55       ; if it is a double digit number, we convert to ascii accordingly
PNHprint    BL          PutChar         ; print it!
            ADDS        R1,R1,#4        ; add 4 to the left shift amount
            CMP         R1,#32          ; compares the left shift amount to see if we are done
            BEQ         PNHend          ; if we are done, then quit!
            B           PNHloop         ; otherwise, keep looping!
PNHend      POP         {R0,R1,R7,PC}  ; restore registers and return to where it was called from          
;------------------------------------------------------------------------------------------------------------------------------ 
PrintStatus
            ;description:   Prints the InPointer, OutPointer, and NumEnqueued
			;subroutines:   PutNumHex, PutStringSB, MoveNextLine, PutNumU 
			;Input:         R1 = queue record structure address
			;Output:        No registers, output printed to terminal
			;Modify:        None
            PUSH        {R0,LR}             ; preserve registers
            LDR         R0,=inPrint         ; load string to be printed
            BL          PutStringSB         ; print "In=0x"
            LDR         R0,[R1,#IN_PTR]     ; load the InPointer
            BL          PutNumHex           ; print the address
            LDR         R0,=outPrint        ; load string to be printed
            BL          PutStringSB         ; print "Out=0x"
            LDR         R0,[R1,#OUT_PTR]    ; load the OutPointer
            BL          PutNumHex           ; print the address
            LDR         R0,=numPrint        ; load string to be printed
            BL          PutStringSB         ; print "Num="
            LDRB        R0,[R1,#NUM_ENQD]   ; load the NumberEnqueued into R0 to be printed
            BL          PutNumU             ; print the number
            BL          MoveNextLine        ; print a carriage return and line feed
            POP         {R0,PC}             ; restore registers and return to where it was called from
;------------------------------------------------------------------------------------------------------------------------------ 
InitQueue   
            ;description:   Initializes the queue record and queue buffer
			;subroutines:   None
			;Input:     R0 = buffer address, R1 = record struct address, R2 = buffer size
			;Output:    None   
			;Modify:    No registers
            PUSH    {R3}                    ; Preserve R3
            STR     R0,[R1,#IN_PTR]         ; makes the InPointer the starting address of the queue buffer
            STR     R0,[R1,#OUT_PTR]        ; makes the OutPointer the starting address of the queue buffer
            STR     R0,[R1,#BUF_STRT]       ; makes the buffer starting point the starting address of the queue buffer
            ADDS    R3,R0,R2                ; BufferPast = BufferStart + BufferSize
            STR     R3,[R1,#BUF_PAST]       ; stores the buffer past address, as calculated in R3
            STR     R2,[R1,#BUF_SIZE]       ; makes the buffer size 4
            MOVS    R3,#0                   ; loads 0 to be stored
            STRB    R3,[R1,#NUM_ENQD]       ; makes the inital number enqueued zero
            POP     {R3}                    ; restores R3
            BX      LR                      ; returns to where it was called from
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
			BEQ		PNUreturn	; if so, don't print anything!
			CMP		R0,#0		; is the number to print zero?
			BEQ		PNUreturn	; if so, don't print anything!
			MOVS	R2,#1		; set R2 to say a non-zero number has been printed
			ADDS	R0,R0,#48	; converts the number to ASCII
			BL		PutChar		; prints the number in R0
PNUreturn	POP		{PC}		; return to where it was called from 	
;-----------------------------------------------------------------------------------------------------------------------------
PrintInputChar
            ;Description:       Prints the command character accepted as input during the mainloop
			;subroutines:       PutChar
			;Input: 	        R3 = the character to print
			;Output: 	        No registers, prints character to terminal
			;Modify:            None
            PUSH    {R0,LR}                 ; preserve R0 and link register
            MOVS	R0,R3					; get ready to print the character (loads character into R0 from R3)
			BL		PutChar					; print the input character
            POP     {R0,PC}                 ; restore R0 and return to where it was called from
;------------------------------------------------------------------------------------------------------------------------------       
PutStringSB 
			;Displays a null-terminated string to the terminal screen
			;subroutines: PutChar
			;Input:  	R0 holds the string that will be printed
			;Output: 	None (Except printed output in terminal)
			;Modify: 	None
			PUSH    {R0,R2,R3,LR}						; stores registers to keep values from being overwritten (data & LR)
			MOVS	R2,#0								; clear R2 so it can be used as the incremental offset
			MOVS	R3,R0								; store the string address in R1 so that R0 can be overwritten
PSSBloop    LDRB    R0,[R3,R2]                          ; load the next value from the string into R0 to be printed
            CMP     R0,#0                               ; if it is a null character, we are at the end of the line
            BEQ     PSSBend                             ; if it is null character, quit
			;otherwise... print and keep looping
            BL      PutChar                             ; print the character stored at R0 to the terminal
            ADDS    R2,R2,#1                            ; add 1 to the number of bytes past R0
            B       PSSBloop                            ; keep looping
PSSBend     POP     {R0,R2,R3,PC}						; restores registers, returns to where it was called from
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
			MOVS	R5,#UART0_S1_TDRE_MASK
POLLTX	    LDRB	R7,[R6,#UART0_S1_OFFSET]           
			ANDS	R7,R7,R5
			BEQ		POLLTX                              ; keep looping until they are not equal- meaning a character is ready to be sent
		;Transmit character stored in R0
			STRB    R0,[R6,#UART0_D_OFFSET]             ; transmit the character stored in R0
			POP		{R5,R6,R7}                          ; restore registers R5,R6,R7 to their original state
			BX		LR                                  ; return to where the branch was called from
;-----------------------------------------------------------------------------------------------------------------------------
Init_UART0_Polling
            ;description:   initializes for terminal polling
			;subroutines: None
			;Input:   None
			;Output:  None
			;Modify:  None
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
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect; low-voltage warning
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

Instruct    DCB     "Type a queue command (d,e,h,p,s): ", 0   ; needed for mainloop
helpprint   DCB     "d (dequeue), e (enqueue), h (help), p (print), s (status)", 0    ; used to print help output
statusPrint DCB     "Status: ",0         ; used to print status
equPrint    DCB     "Character to Enqueue: ",0      ; used for enqueue command
inPrint     DCB     "  In=0x",0      ; used to print status 
outPrint    DCB     "  Out=0x",0     ; used to print status 
numPrint    DCB     "  Num=",0     ; used to print status 
failPrint   DCB     "Failure:",0     ; used to print enqueue results
succPrint   DCB     "Success:",0     ; used to print enqueue results
spacePrint  DCB     "      ",0       ; used for print formatting

;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<

;THESTRING	SPACE 	MAX_SIZE

QueueBuffer SPACE   4       ; 4 objects in the queue at one time
QueueRecord SPACE   18      ; add all offset equates for queue management record to find total size
    
;>>>>>   end variables here <<<<<
            ALIGN
            END
