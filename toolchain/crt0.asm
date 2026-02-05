; Pokemon Mini Startup Code
; TASKING E0C88 Assembler - S1C88 CPU
; Based on c88-pokemini helloworld example

$CASE ON

; ============================================================================
; Macro for far jumps in vector table (6 bytes each)
; ============================================================================
JP_FAR  MACRO   lbl
        LD      NB, #@CPAG(lbl)
        JRL     lbl
        ENDM

; ============================================================================
; ROM Header at 0x2100 (0xD0 bytes = 208 bytes)
; ============================================================================

        DEFSECT ".min_header", CODE AT 2100H
        SECT    ".min_header"
        
        ; 0x2100: "MN" marker (2 bytes)
        ASCII   "MN"
        
        ; 0x2102: Reset vector (6 bytes)
        JP_FAR  __START
        
        ; 0x2108-0x21A3: IRQ vectors (26 vectors x 6 bytes = 156 bytes)
        JP_FAR  _irq_dummy      ; PRC Frame Copy
        JP_FAR  _irq_dummy      ; PRC Render Done  
        JP_FAR  _irq_dummy      ; Timer 2 Hi
        JP_FAR  _irq_dummy      ; Timer 2 Lo
        JP_FAR  _irq_dummy      ; Timer 1 Hi
        JP_FAR  _irq_dummy      ; Timer 1 Lo
        JP_FAR  _irq_dummy      ; Timer 3 Hi
        JP_FAR  _irq_dummy      ; Timer 3 Pivot
        JP_FAR  _irq_dummy      ; 32Hz
        JP_FAR  _irq_dummy      ; 8Hz
        JP_FAR  _irq_dummy      ; 2Hz
        JP_FAR  _irq_dummy      ; 1Hz
        JP_FAR  _irq_dummy      ; IR Receiver
        JP_FAR  _irq_dummy      ; Shake Sensor
        JP_FAR  _irq_dummy      ; Power Key
        JP_FAR  _irq_dummy      ; Right Key
        JP_FAR  _irq_dummy      ; Left Key
        JP_FAR  _irq_dummy      ; Down Key
        JP_FAR  _irq_dummy      ; Up Key
        JP_FAR  _irq_dummy      ; C Key
        JP_FAR  _irq_dummy      ; B Key
        JP_FAR  _irq_dummy      ; A Key
        JP_FAR  _irq_dummy      ; Unknown 1
        JP_FAR  _irq_dummy      ; Unknown 2
        JP_FAR  _irq_dummy      ; Unknown 3
        JP_FAR  _irq_dummy      ; Cartridge IRQ
        
        ; 0x21A4: "NINTENDO" (8 bytes) - REQUIRED!
        ASCII   "NINTENDO"

; ============================================================================
; Header tail at 0x21BC
; ============================================================================

        DEFSECT ".min_header_tail", CODE AT 21BCH
        SECT    ".min_header_tail"
        ASCII   "2P"
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ============================================================================
; Startup code section (SHORT for relative calls)
; ============================================================================

        DEFSECT ".startup", CODE, SHORT
        SECT    ".startup"

__start_cpt:
__START:
        ; Initialize stack pointer (top of RAM, before I/O area)
        LD      SP, #02000H
        
        ; Set BR to I/O register base (0x20xx)
        LD      BR, #020H
        
        ; Initialize PRC (Program Readable Counter)
        LD      [BR:21H], #0CH
        LD      [BR:25H], #080H
        LD      [BR:80H], #08H
        LD      [BR:81H], #08H
        
        ; Clear SC (status/control)
        LD      SC, #0H
        
        ; Disable all interrupts
        LD      [BR:27H], #0FFH
        LD      [BR:28H], #0FFH
        LD      [BR:29H], #0FFH
        LD      [BR:2AH], #0FFH
        
        ; Call main program (we skip copytable - no static initializers used)
        CARL    _main

_halt_loop:
        ; If main returns, infinite loop
        JRL     _halt_loop

        GLOBAL  __start_cpt
        GLOBAL  __START
        EXTERN  (CODE) _main
        CALLS   '_start_cpt', 'main'

; Provide __exit for library compatibility
        GLOBAL  __exit
__exit:
        JRL     _halt_loop
        
; Provide empty __copytable for library compatibility
        GLOBAL  __copytable
__copytable:
        RET

; ============================================================================
; Dummy IRQ handler
; ============================================================================

        DEFSECT ".text", CODE
        SECT    ".text"

        GLOBAL  _irq_dummy
_irq_dummy:
        RETE

        END
