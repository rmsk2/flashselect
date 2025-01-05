* = $0300
.cpu "w65c02"


jmp main
; put some data structures in zero page
.include "zp_data.asm"


.include "api.asm"
.include "zeropage.asm"
.include "setup.asm"
.include "clut.asm"
.include "arith16.asm"
.include "txtio.asm"
.include "khelp.asm"
.include "key_repeat.asm"

TXT_MSG   .text "**** Select program to start from cartridge ****", $0d, $0d, $0d
TXT_SNAKE .text "1. Snake", $0d, $0d
TXT_2048  .text "2. 2048", $0d, $0d
TXT_15    .text "3. 15 Puzzle", $0d, $0d
TXT_EXIT  .text "4. Exit to BASIC"
TXT_FCART .text "f. fcart", $0d, $0d

COL = $12 
REV_COL = $21

toRev .macro
    pha
    lda #REV_COL
    sta CURSOR_STATE.col
    pla
.endmacro

noRev .macro
    pha
    lda #COL
    sta CURSOR_STATE.col
    pla
.endmacro

FCART_PRESENT .byte 0

main
    jsr setup.mmu
    jsr clut.init
    jsr initEvents
    jsr txtio.init80x60
    ;jsr txtio.cursorOn

    lda #$12
    sta CURSOR_STATE.col 
    jsr txtio.clear

    #printString TXT_MSG, len(TXT_MSG)
    #printString TXT_SNAKE, len(TXT_SNAKE)
    #printString TXT_2048, len(TXT_2048)
    #printString TXT_15, len(TXT_15)
    stz FCART_PRESENT
    jsr checkFcart
    bcc _exitBasic
    inc FCART_PRESENT
    #printString TXT_FCART, len(TXT_FCART)
_exitBasic
    #printString TXT_EXIT, len(TXT_EXIT)

_restart
    jsr keyrepeat.init
    #load16BitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts


processKeyEvent
    sta ASCII_TEMP
    lda FCART_PRESENT
    beq _checkNumeric
    lda ASCII_TEMP
    cmp #'f'
    bne _checkNumeric
    #load16BitImmediate FCCART, kernel.args.buf
    jsr kernel.RunNamed
    #load16BitImmediate FCART, kernel.args.buf
    jsr kernel.RunNamed
    bra _goOn
_checkNumeric
    lda ASCII_TEMP
    cmp #'1'
    bcc _goOn
    cmp #'5'
    bcs _goOn

    cmp #'1'
    bne _test2
    #load16BitImmediate SNAKE, kernel.args.buf
    jsr kernel.RunNamed
    bra _goOn
_test2
    cmp #'2'
    bne _test3
    #load16BitImmediate F2048, kernel.args.buf
    jsr kernel.RunNamed
    bra _goOn
_test3
    cmp #'3'
    bne _exit
    #load16BitImmediate F15, kernel.args.buf
    jsr kernel.RunNamed
    bra _goOn
; _test4
;     cmp #'4'
;     bne _exit
;     #load16BitImmediate FCCART, kernel.args.buf
;     jsr kernel.RunNamed
;     #load16BitImmediate FCART, kernel.args.buf
;     jsr kernel.RunNamed
;     bra _goOn
_exit
    clc
    rts
_goOn
    sec
    rts


; carry is set if strings are equal. String 1 in MEM_PTR1, the other has to
; be in MEM_PTR2.
strCmp
    ldy #0
_loop
    lda (MEM_PTR1), y
    cmp (MEM_PTR2), y
    bne _notFound
    cmp #0
    beq _found
    iny
    beq _notFound
    bra _loop
_notFound
    clc
    rts
_found
    sec
    rts


; carry is set if the last block of the cartridge contains fcart, else carry is clear.
MMU_TEMP .byte 0
checkFcart
    lda 13
    sta MMU_TEMP
    lda #$80+$1f
    sta 13
    
    ; Check for KUP signature
    lda $A000
    cmp #$F2
    bne _notFound

    lda $A001
    cmp #$56
    bne _notFound

    #load16BitImmediate FCART, MEM_PTR1
    #load16BitImmediate $A00A, MEM_PTR2
    jsr strCmp
    bcs _restoreMMU

    #load16BitImmediate FCCART, MEM_PTR1
    #load16BitImmediate $A00A, MEM_PTR2
    jsr strCmp
    bcs _restoreMMU
_notFound    
    clc
_restoreMMU
    lda MMU_TEMP
    sta 13
    rts


SNAKE   .text "snake", $00
F2048   .text "f256_2048", $00
F15     .text "f256_15", $00
FCART   .text "fcart", $00
FCCART  .text "fccart", $00
