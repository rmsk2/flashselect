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

TXT_AST         .text "****                                        ****", $0d
TXT_MSG         .text "**** Select program to start from cartridge ****", $0d
TXT_STARS       .text "************************************************", $0d
TXT_SELECT_INFO .text "Start entry by typing the corresponding character or select", $0d
TXT_SEL_INFO2   .text "entry with cursor keys and press return to start it"

COL = $10 
REV_COL = $01
CRSR_UP = 16
CRSR_DOWN = 14

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
CURRENT_ENTRY .byte 0

main
    jsr setup.mmu
    jsr clut.init
    jsr initEvents
    jsr txtio.init80x60
    ;jsr txtio.cursorOn

    lda #$10
    sta CURSOR_STATE.col 
    jsr txtio.clear    

    stz CURRENT_ENTRY
    stz FCART_PRESENT
    jsr checkFcart
    bcc _notPresent
    inc FCART_PRESENT
_notPresent
    jsr printAvailable

_restart
    jsr keyrepeat.init
    #load16BitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts


Entry_t .struct  cmd, addr, txt, len
    command  .byte \cmd
    ref      .word \addr
    text     .word \txt
    textLen  .byte \len
    reserved .fill 2
.endstruct

NUM_PROGS_FOUND .byte 4

TXT_SNAKE .text "Snake: A simple clone of the game snake", $0d, $0d
TXT_2048  .text "2048: The well known block shifting game", $0d, $0d
TXT_15    .text "15 Puzzle: The original block shifting game", $0d, $0d
TXT_LIFE  .text "Conway's game of life", $0d, $0d
TXT_FCART .text "f. fcart: Program to write data to the flash cartridge", $0d, $0d
TXT_EXIT  .text "x. Exit to BASIC"

REF_TABLE
A .dstruct Entry_t, '1', SNAKE, TXT_SNAKE, len(TXT_SNAKE)
B .dstruct Entry_t, '2', F2048, TXT_2048, len(TXT_2048)
C .dstruct Entry_t, '3', F15, TXT_15, len(TXT_15)
D .dstruct Entry_t, '4', LIFE, TXT_LIFE, len(TXT_LIFE)


processKeyEvent
    sta ASCII_TEMP
    cmp #'x'
    bne _checkFcart
    clc
    rts
_checkFcart
    jsr checkCallFcart
    bcs _checkCursor
    bra _goOn
_checkCursor
    lda ASCII_TEMP
    cmp #CRSR_DOWN
    bne _checkDown
    inc CURRENT_ENTRY
    clc
    lda NUM_PROGS_FOUND
    adc FCART_PRESENT
    ina
    cmp CURRENT_ENTRY
    bne _redraw
    stz CURRENT_ENTRY
_redraw
    jsr printAvailable
    bra _goOn
_checkDown
    cmp #CRSR_UP
    bne _checkStart
    dec CURRENT_ENTRY
    bpl _redraw2
    clc
    lda NUM_PROGS_FOUND
    adc FCART_PRESENT
    sta CURRENT_ENTRY
_redraw2
    jsr printAvailable
    bra _goOn
_checkStart
    cmp #CARRIAGE_RETURN
    bne _checkCallProgram
    clc
    lda NUM_PROGS_FOUND
    adc FCART_PRESENT
    cmp CURRENT_ENTRY
    bne _notExit
    clc 
    rts
_notExit
    lda FCART_PRESENT
    beq _runEntry
    lda NUM_PROGS_FOUND
    cmp CURRENT_ENTRY
    bne _runEntry
    jsr callFcart
    bra _goOn
_runEntry
    jsr runEntry
    bra _goOn
_checkCallProgram
    jsr checkProgram
_goOn
    sec
    rts
    


checkCallFcart
    lda FCART_PRESENT
    beq endNotFound
    lda ASCII_TEMP
    cmp #'f'
    bne endNotFound
callFcart
    #load16BitImmediate FCCART, kernel.args.buf
    jsr kernel.RunNamed
    #load16BitImmediate FCART, kernel.args.buf
    jsr kernel.RunNamed
    clc
    rts
endNotFound
    sec
    rts


checkProgram   
    ldy #0
    ldx #0
_loopAllowed
    cpy NUM_PROGS_FOUND
    beq _goOn
    tya
    asl
    asl
    asl
    tax
    lda ASCII_TEMP
    cmp REF_TABLE, x
    beq _start
    iny
    bra _loopAllowed
_start
    inx
    lda REF_TABLE, x
    sta kernel.args.buf
    inx    
    lda REF_TABLE, x
    sta kernel.args.buf + 1
    jsr kernel.RunNamed
_goOn
    rts


runEntry
    lda CURRENT_ENTRY
    asl
    asl
    asl
_special
    tay
    iny
    lda REF_TABLE, y
    sta kernel.args.buf
    iny
    lda REF_TABLE, y
    sta kernel.args.buf + 1
    jsr kernel.RunNamed
    rts


STRUCT_INDEX .byte 0
printAvailable
    jsr txtio.home
    #printString TXT_STARS, len(TXT_STARS)
    #printString TXT_AST, len(TXT_AST)
    #printString TXT_MSG, len(TXT_MSG)
    #printString TXT_AST, len(TXT_AST)
    #printString TXT_STARS, len(TXT_STARS)
    jsr txtio.newLine
    jsr txtio.newLine

    ldy #0
_loopAllowed
    cpy NUM_PROGS_FOUND
    beq _done
    cpy CURRENT_ENTRY
    bne _noHighlight
    #toRev
_noHighlight    
    phy
    tya
    asl
    asl
    asl
    sta STRUCT_INDEX
    clc
    adc #Entry_t.command
    tax
    lda REF_TABLE, x
    jsr txtio.charOut
    lda #'.'
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut
    lda STRUCT_INDEX
    clc
    adc #Entry_t.text
    tax
    lda REF_TABLE, x
    sta TXT_PTR3
    inx
    lda REF_TABLE, x
    sta TXT_PTR3 + 1
    inx
    lda REF_TABLE, x
    jsr txtio.printStr
    #noRev
    ply
    iny
    bra _loopAllowed
_done
    lda FCART_PRESENT
    beq _noFcart
    clc
    lda NUM_PROGS_FOUND
    cmp CURRENT_ENTRY
    bne _l1
    #toRev
_l1
    #printString TXT_FCART, len(TXT_FCART)
    #noRev
_noFcart
    clc
    lda NUM_PROGS_FOUND
    adc FCART_PRESENT
    cmp CURRENT_ENTRY
    bne _l2
    #toRev
_l2
    #printString TXT_EXIT, len(TXT_EXIT)
    #noRev
    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_SELECT_INFO, len(TXT_SELECT_INFO)
    #printString TXT_SEL_INFO2, len(TXT_SEL_INFO2)
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

    #load16BitImmediate FCCART, MEM_PTR1
    #load16BitImmediate $A00A, MEM_PTR2
    jsr strCmp
    bcs _restoreMMU

    #load16BitImmediate FCART, MEM_PTR1
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
LIFE    .text "f256_life", $00
FCART   .text "fcart", $00
FCCART  .text "fccart", $00
