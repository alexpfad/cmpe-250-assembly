            TTL KL46Z Bare Metal Assembly Startup
;****************************************************************
;* Flash configuration image for area at 0x400-0x40F(+)
;* SystemInit subroutine (++)
;* SetClock48MHz subroutine (+++)
;+:Following Freescale startup_MKL46Z4.s
;     CMSIS Cortex-M0plus Core Device Startup File for the MKL46Z4
;     v1.4, 11/22/2012
;++:Following [1].1.1.4.2 Startup routines and [2]
;+++:Following [1].4.1 Clocking
;[1] Freescale Semiconductor, <B>Kinetis L Peripheral Module Quick
;    Reference</B>, KLQRUG, Rev. 0, 9/2012.
;[2] ARM, <B>Application Note 48 Scatter Loading</B>, ARM DAI 0048A,
;    Jan. 1998
;Name:  R. W. Melton
;Date:  April 17, 2015
;Class:  CMPE 250
;Section:  All sections
;****************************************************************
;Include files
;  MKL46Z4.s
            GET  MKL46Z4.s
;****************************************************************
            AREA    Start,CODE,READONLY
            EXPORT  Startup
;---------------------------------------------------------------
Startup
;****************************************************************
;Performs the following startup tasks
;* System initialization
;* Mask interrupts
;* Configure 48-MHz system clock
;****************************************************************
;Save return address
            PUSH    {LR}
;Initialize system
            BL      SystemInit
;Mask interrupts
            CPSID   I
;Configure 48-MHz system clock
            BL      SetClock48MHz
;Return
            POP     {PC}  
;---------------------------------------------------------------
SystemInit
;****************************************************************
;Performs the following system initialization tasks.
;* Mask interrupts
;* Disable watchdog timer (+)
;* Load initial RAM image from end of loaded flash image (++) [2]
;* Initialize registers to known state for debugger
;+:Following [1].1.1.4.2 Startup routines: 1 Disable watchdog
;++:Step suggested [1].1.1.4.2 Startup routtines: 2 Initialize RAM
;[1] Freescale Semiconductor, <B>Kinetis L Peripheral Module Quick
;    Reference</B>, KLQRUG, Rev. 0, 9/2012.
;[2] ARM, <B>Application Note 48 Scatter Loading</B>, ARM DAI 0048A,
;    Jan. 1998
;****************************************************************
;Mask interrupts
            CPSID   I
;Disable watchdog timer
            LDR     R0,=SIM_COPC
            MOVS    R1,#COP_DISABLE
            STR     R1,[R0,#0]
;Put return on stack
            PUSH    {LR}
;Initialize registers
            LDR     R1,=0x11111111
            ADDS    R2,R1,R1
            ADDS    R3,R2,R1
            ADDS    R4,R3,R1
            ADDS    R5,R4,R1
            ADDS    R6,R5,R1
            ADDS    R7,R6,R1
            ADDS    R0,R7,R1
            MOV     R8,R0
            ADDS    R0,R0,R1
            MOV     R9,R0
            ADDS    R0,R0,R1
            MOV     R10,R0
            ADDS    R0,R0,R1
            MOV     R11,R0
            ADDS    R0,R0,R1
            MOV     R12,R0
            ADDS    R0,R0,R1
            ADDS    R0,R0,R1
            MOV     R14,R0
            MOVS    R0,#0
            POP     {PC}
SetClock48MHz
;****************************************************************
;Establishes 96-MHz PLL clock from 8-MHz external oscillator.
;Follows [1].4.1 Clocking 3: Configuration examples
;[1] Freescale Semiconductor, <B>Kinetis L Peripheral Module Quick
;    Reference</B>, KLQRUG, Rev. 0, 9/2012.
;Modifies:  condition flags
;****************************************************************
            PUSH    {R0-R3}
    ;Establish FLL bypassed external mode (FBE)
    ;First configure oscillator settings in MCG_C2
    ;RANGE is determined from external frequency
    ;Since RANGE affects FRDIV, it must be set
    ;correctly even with an external clock
            LDR     R0,=MCG_BASE
            MOVS    R1,#MCG_C2_HF_LP_OSC
            STRB    R1,[R0,#MCG_C2_OFFSET]
    ;FRDIV set to keep FLL ref clock within
    ;  correct range, determined by ref clock.
    ;For 8-MHz ref, need divide by 256
    ;CLKS must be set to 2_10 to select
    ;  external reference clock
    ;Clearing IREFS selects and enables
    ;  external oscillator
            MOVS    R1,#MCG_C1_EXT_DIV256
            STRB    R1,[R0,#MCG_C1_OFFSET]
    ;Wait for OSCINIT to set after switching
    ;  to external oscillator, or time out
            MOVS    R1,#MCG_S_OSCINIT0_MASK
            LDR     R3,=20000
__MCG_Wait_OSCINIT0
            LDRB    R2,[R0,#MCG_S_OFFSET]
            TST     R1,R2
            BNE     __MCG_OSCINIT0
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_OSCINIT0
__MCG_OSCINIT0
    ;Wait for reference clock status to clear,
    ;  or time out
            MOVS    R1,#MCG_S_IREFST_MASK
            LDR     R3,=2000
__MCG_Wait_IREFST_Clear
            LDRB    R2,[R0,#MCG_S_OFFSET]
            TST     R1,R2
            BEQ     __MCG_IREFST_Clear
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_IREFST_Clear
__MCG_IREFST_Clear
    ;Wait for clock status to show
    ;  external reference clock source,
    ;  or time out
            MOVS    R1,#MCG_S_CLKST_MASK
            LDR     R3,=2000
__MCG_Wait_CLKST_EXT
            LDRB    R2,[R0,#MCG_S_OFFSET]
            ANDS    R2,R2,R1
            CMP     R2,#MCG_S_CLKST_EXT_MASK
            BEQ     __MCG_CLKST_EXT
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_CLKST_EXT
__MCG_CLKST_EXT
  ;Enable clock monitor when using external clock
            MOVS    R1,#MCG_C6_CME0_MASK
            LDRB    R2,[R0,#MCG_C6_OFFSET]
            ORRS    R2,R2,R1
            STRB    R2,[R0,#MCG_C6_OFFSET]
  ;Enable PLL and move to PLL bypassed external mode
  ;  to allow PLL lock while still clocking from
  ;  external reference clock (PBE mode)
    ;Set PLL reference clock to right frequency
            MOVS    R1,#MCG_C5_PRDIV0_MASK
            MVNS    R1,R1
            MOVS    R3,#MCG_C5_PRDIV0_DIV2
            LDRB    R2,[R0,#MCG_C5_OFFSET]
            ANDS    R2,R2,R1
            ORRS    R2,R2,R3
            STRB    R2,[R0,#MCG_C5_OFFSET]
    ;Set PLL multiplier and enable PLL
            MOVS    R1,#MCG_C6_VDIV0_MASK
            MVNS    R1,R1
            MOVS    R3,#MCG_C6_PLL_MUL24
            LDRB    R2,[R0,#MCG_C6_OFFSET]
            ANDS    R2,R2,R1
            ORRS    R2,R2,R3
            STRB    R2,[R0,#MCG_C6_OFFSET]
    ;Wait for PLLST status bit to set,
    ;  or time out
            MOVS    R1,#MCG_S_PLLST_MASK
            LDR     R3,=2000
__MCG_Wait_PLLST
            LDRB    R2,[R0,#MCG_S_OFFSET]
            TST     R1,R2
            BNE     __MCG_PLLST
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_PLLST
__MCG_PLLST
    ;Wait for LOCK0 status bit to set,
    ;  or time out
            MOVS    R1,#MCG_S_LOCK0_MASK
            LDR     R3,=4000
__MCG_Wait_LOCK0
            LDRB    R2,[R0,#MCG_S_OFFSET]
            TST     R1,R2
            BNE     __MCG_LOCK0
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_LOCK0
__MCG_LOCK0
  ;With PLL now enabled and locked,
  ;  MCGOUTCLK can be switched to PLL output
  ;Before switching to this higher frequency clock,
  ;  system clock dividers must be set to keep 
  ;  frequencies within specifications
            LDR     R1,=SIM_CLKDIV1
            LDR     R2,=SIM_CORE_DIV2_BUS_DIV2
            STR     R2,[R1,#0]
  ;Switch to PLL (PEE mode)
    ;Clear CLKS to select PLL as MCGCLKOUT
            MOVS    R1,#MCG_C1_CLKS_MASK
            MVNS    R1,R1
            LDRB    R2,[R0,#MCG_C1_OFFSET]
            ANDS    R2,R2,R1
            STRB    R2,[R0,#MCG_C1_OFFSET]
    ;Wait for clock status to show
    ;  external reference clock source,
    ;  or time out
            MOVS    R1,#MCG_S_CLKST_MASK
            LDR     R3,=2000
__MCG_Wait_CLKST_PLL
            LDRB    R2,[R0,#MCG_S_OFFSET]
            ANDS    R2,R2,R1
            CMP     R2,#MCG_S_CLKST_PLL_MASK
            BEQ     __MCG_CLKST_PLL
            SUBS    R3,R3,#1
            BNE     __MCG_Wait_CLKST_PLL
__MCG_CLKST_PLL            
            POP     {R0-R3}
            BX      LR
;****************************************************************
            ALIGN
;Program template for CMPE-250 uses main as "Reset_Handler"
;           EXPORT  Reset_Handler
;Reset_Handler
;****************************************************************
;Goto main
;****************************************************************
;           LDR     R0,=main
;           BX      R0
            EXPORT  Dummy_Handler
Dummy_Handler
;****************************************************************
;Dummy exception handler (infinite loop)
;****************************************************************
            B       .
;---------------------------------------------------------------
            ALIGN
;****************************************************************
            AREA    |.ARM.__at_0xC0|,DATA,NOALLOC,READONLY
;Program once field:  0xC0-0xFF
            SPACE   0x40
;****************************************************************
            IF      :LNOT::DEF:RAM_TARGET
            AREA    |.ARM.__at_0x400|,CODE,READONLY
            DCB     FCF_BACKDOOR_KEY0,FCF_BACKDOOR_KEY1
            DCB     FCF_BACKDOOR_KEY2,FCF_BACKDOOR_KEY3
            DCB     FCF_BACKDOOR_KEY4,FCF_BACKDOOR_KEY5
            DCB     FCF_BACKDOOR_KEY6,FCF_BACKDOOR_KEY7
            DCB     FCF_FPROT0,FCF_FPROT1,FCF_FPROT2,FCF_FPROT3
            DCB     FCF_FSEC,FCF_FOPT,0xFF,0xFF
            ENDIF
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
            END
