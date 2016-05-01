            TTL CMPE 250 Exercise Four
;****************************************************************
;A custom-written division subroutine (DIVU), with test material for functionality verification
;Name:  Alex Pfadenhauer
;Date:  2/16/2016
;Class:  CMPE-250
;Section:  L1 - Tuesday, 2-4pm
;---------------------------------------------------------------
;Keil Simulator Template for KL46
;R. W. Melton
;January 23, 2015
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;EQUates


MAX_DATA	EQU 25
	
;Vectors
VECTOR_TABLE_SIZE EQU 0x000000C0
VECTOR_SIZE       EQU 4           ;Bytes per vector
;Stack
SSTACK_SIZE EQU  0x00000100
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
Reset_Handler
main
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<		
	
			BL		InitData		; sets up for testing of DIVU
loop    	BL		LoadData		; loads next set of P and Q to test
			; if C is set here, program should quit
			BCS		exit		; C is set, so program is quitting
			; otherwise, initialize P and Q
            LDR		R1,=P			; Load P's address into R1
			LDR		R1,[R1,#0]		; Load contents of P into R1
			LDR		R0,=Q			; Load Q's address into R0
			LDR		R0,[R0,#0]		; Load contents of Q into R0
			BL		DIVU			; call DIVU to divide P by Q.  P / Q = R0 rem. R1
			; If C is clear, division was valid! Store P and Q. If Carry is set, then branch
			BCS		carry   		; if C is set, branch to carry to store 0xFFFFFFF
			;(If C is clear)
			LDR		R2,=P			; load address of P into R2
			STR		R0,[R2,#0]		; Store R0 in P
			LDR		R2,=Q			; load address of Q into R2
			STR		R1,[R2,#0]		; Store R1 in Q
			B		test		; continue running, go to testing results
			;(If C is set)
carry   	LDR		R2,=P			; load address of P into R2
			MOVS	R3,#0			; load 0 into R3
			MVNS	R3,R3			; change 0 to 0xFFFFFFFF (by inverting it)
			STR		R3,[R2,#0]		; store 0xFFFFFFFF in P
			LDR		R2,=Q			; load address of Q into R2
			STR		R3,[R2,#0]		; store 0xFFFFFFFF in Q
test    	BL		TestData		; now call TestData.
			B		loop    		; repeat from LoadData
exit
;>>>>>   end main program code <<<<<
;Stay here
            B       .			
;---------------------------------------------------------------
;>>>>> begin subroutine code <<<<<
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
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Machine code provided for Exercise Four
;R. W. Melton 9/14/2015
;Place at the end of your MyCode AREA
            AREA    |.ARM.__at_0x4000|,CODE,READONLY
InitData    DCI.W   0x26002700
            DCI     0x4770
LoadData    DCI.W   0xB40FA316
            DCI.W   0x19DBA13D
            DCI.W   0x428BD209
            DCI.W   0xCB034A10
            DCI.W   0x4B116010
            DCI.W   0x60193708
            DCI.W   0x20000840
            DCI.W   0xBC0F4770
            DCI.W   0x20010840
            DCI     0xE7FA
TestData    DCI.W   0xB40F480C
            DCI.W   0xA13419C0
            DCI.W   0x19C93808
            DCI.W   0x39084A07
            DCI.W   0x4B076812
            DCI.W   0x681BC00C
            DCI.W   0x68084290
            DCI.W   0xD1046848
            DCI.W   0x4298D101
            DCI.W   0xBC0F4770
            DCI.W   0x1C76E7FB
            ALIGN
PPtr        DCD     P
QPtr        DCD     Q
ResultsPtr  DCD     Results
            DCQ     0x0000000000000000,0x0000000000000001
            DCQ     0x0000000100000000,0x0000000100000010
            DCQ     0x0000000200000010,0x0000000400000010
            DCQ     0x0000000800000010,0x0000001000000010
            DCQ     0x0000002000000010,0x0000000100000007
            DCQ     0x0000000200000007,0x0000000300000007
            DCQ     0x0000000400000007,0x0000000500000007
            DCQ     0x0000000600000007,0x0000000700000007
            DCQ     0x0000000800000007,0x8000000080000000
            DCQ     0x8000000180000000,0x000F0000FFFFFFFF
            DCQ     0xFFFFFFFFFFFFFFFF,0xFFFFFFFFFFFFFFFF
            DCQ     0x0000000000000000,0x0000000000000010
            DCQ     0x0000000000000008,0x0000000000000004
            DCQ     0x0000000000000002,0x0000000000000001
            DCQ     0x0000001000000000,0x0000000000000007
            DCQ     0x0000000100000003,0x0000000100000002
            DCQ     0x0000000300000001,0x0000000200000001
            DCQ     0x0000000100000001,0x0000000000000001
            DCQ     0x0000000700000000,0x0000000000000001
            DCQ     0x8000000000000000,0x0000FFFF00001111
            ALIGN
;****************************************************************
				
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
__Vectors 
                                      ;ARM core vectors 
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;reset vector
            SPACE  (VECTOR_TABLE_SIZE - (2 * VECTOR_SIZE))
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
;>>>>>   end constants here <<<<<
;****************************************************************
            AREA    |.ARM.__at_0x1FFFE000|,DATA,READWRITE,ALIGN=3
            EXPORT  __initial_sp
;Allocate system stack
            IF      :LNOT::DEF:SSTACK_SIZE
SSTACK_SIZE EQU     0x00000100
            ENDIF
Stack_Mem   SPACE   SSTACK_SIZE
__initial_sp
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<

P       SPACE   4               ; word variable, 4 byte size
Q       SPACE   4               ; word variable, 4 byte size
Results SPACE   2*MAX_DATA*4    ; word array, 4 byte size * MAX_DATA * 2 (for P and Q)
    
;>>>>>   end variables here <<<<<
            END
