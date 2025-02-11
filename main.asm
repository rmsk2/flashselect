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
    jsr printAvailable

_restart
    jsr keyrepeat.init
    #load16BitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts


Entry_t .struct  selKey, kup, klen, desc, descLen
    selectionKey   .byte \selKey
    kupName        .word \kup
    kupLen         .byte \kLen
    description    .word \desc
    descriptionLen .byte \descLen
    reserved       .fill 1
.endstruct


TXT_SNAKE .text "A simple clone of the game snake", $0d, $0d
TXT_2048  .text "The well known block shifting game", $0d, $0d
TXT_15    .text "15 puzzle, the original block shifting game", $0d, $0d
TXT_LIFE  .text "Conway's game of life", $0d, $0d
TXT_FCCART .text "Program to write data to the flash cartridge", $0d, $0d

TXT_EXIT  .text "x. Exit to BASIC"

SNAKE   .text "snake", $00
F2048   .text "f256_2048", $00
F15     .text "f256_15", $00
LIFE    .text "f256_life", $00
FCCART  .text "fccart", $00

NULL .word 0

NUM_PROGS_FOUND .byte 5

REF_TABLE
CB .dstruct Entry_t, '1', SNAKE, len(SNAKE)-1, TXT_SNAKE, len(TXT_SNAKE)
A  .dstruct Entry_t, '2', F2048, len(F2048)-1, TXT_2048, len(TXT_2048)
B  .dstruct Entry_t, '3', F15, len(F15)-1, TXT_15, len(TXT_15)
C  .dstruct Entry_t, '4', LIFE, len(LIFE)-1, TXT_LIFE, len(TXT_LIFE)
D  .dstruct Entry_t, '5', FCCART, len(FCCART)-1, TXT_FCCART, len(TXT_FCCART)
E  .dstruct Entry_t, '6', NULL, 0, NULL, 0
F  .dstruct Entry_t, '7', NULL, 0, NULL, 0
G  .dstruct Entry_t, '9', NULL, 0, NULL, 0
H  .dstruct Entry_t, 'a', NULL, 0, NULL, 0
I  .dstruct Entry_t, 'b', NULL, 0, NULL, 0
J  .dstruct Entry_t, 'c', NULL, 0, NULL, 0
K  .dstruct Entry_t, 'd', NULL, 0, NULL, 0
L  .dstruct Entry_t, 'e', NULL, 0, NULL, 0
M  .dstruct Entry_t, 'g', NULL, 0, NULL, 0
N  .dstruct Entry_t, 'h', NULL, 0, NULL, 0
O  .dstruct Entry_t, 'i', NULL, 0, NULL, 0
P  .dstruct Entry_t, 'j', NULL, 0, NULL, 0
Q  .dstruct Entry_t, 'k', NULL, 0, NULL, 0
R  .dstruct Entry_t, 'l', NULL, 0, NULL, 0
S  .dstruct Entry_t, 'm', NULL, 0, NULL, 0
T  .dstruct Entry_t, 'n', NULL, 0, NULL, 0
U  .dstruct Entry_t, 'o', NULL, 0, NULL, 0
V  .dstruct Entry_t, 'p', NULL, 0, NULL, 0
W  .dstruct Entry_t, 'q', NULL, 0, NULL, 0
AX .dstruct Entry_t, 'r', NULL, 0, NULL, 0
AY .dstruct Entry_t, 's', NULL, 0, NULL, 0
Z  .dstruct Entry_t, 't', NULL, 0, NULL, 0
AA .dstruct Entry_t, 'u', NULL, 0, NULL, 0
BX .dstruct Entry_t, 'r', NULL, 0, NULL, 0
BY .dstruct Entry_t, 's', NULL, 0, NULL, 0
BZ .dstruct Entry_t, 't', NULL, 0, NULL, 0
BA .dstruct Entry_t, 'u', NULL, 0, NULL, 0


processKeyEvent
    sta ASCII_TEMP
    cmp #'x'
    bne _checkCursor
    clc
    rts
_checkCursor
    lda ASCII_TEMP
    cmp #CRSR_DOWN
    bne _checkUp
    inc CURRENT_ENTRY
    lda NUM_PROGS_FOUND
    ina
    cmp CURRENT_ENTRY
    bne _redraw
    stz CURRENT_ENTRY
_redraw
    jsr printAvailable
    bra _goOn
_checkUp
    cmp #CRSR_UP
    bne _checkStart
    dec CURRENT_ENTRY
    bpl _redraw2
    lda NUM_PROGS_FOUND
    sta CURRENT_ENTRY
_redraw2
    jsr printAvailable
    bra _goOn
_checkStart
    cmp #CARRIAGE_RETURN
    bne _checkCallProgram
    ; CR was pressed
    ; check if it was pressed on last entry
    lda NUM_PROGS_FOUND
    cmp CURRENT_ENTRY
    bne _notExit
    ; Return was pressed on the last entry which
    ; is used for exit
    clc 
    rts
_notExit
    jsr runEntry
    bra _goOn
_checkCallProgram
    ; a normal key was pressed. Test if this keys belongs to a
    ; KUP.
    jsr checkForAndStartProgram
_goOn
    sec
    rts


; Check if the value in ASCII_TEMP is the selection key of a program. If it is
; start the program
checkForAndStartProgram
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
    adc #Entry_t.selectionKey
    tax
    lda REF_TABLE, x
    jsr txtio.charOut
    lda #'.'
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut

    lda STRUCT_INDEX
    clc
    adc #Entry_t.kupName
    tax
    lda REF_TABLE, x
    sta TXT_PTR3
    inx
    lda REF_TABLE, x
    sta TXT_PTR3 + 1
    inx
    lda REF_TABLE, x
    jsr txtio.printStr

    lda #':'
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut

    lda STRUCT_INDEX
    clc
    adc #Entry_t.description
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
    lda NUM_PROGS_FOUND
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
; MMU_TEMP .byte 0
; checkFcart
;     lda 13
;     sta MMU_TEMP
;     lda #$80+$1f
;     sta 13
    
;     ; Check for KUP signature
;     lda $A000
;     cmp #$F2
;     bne _notFound

;     lda $A001
;     cmp #$56
;     bne _notFound

;     #load16BitImmediate FCCART, MEM_PTR1
;     #load16BitImmediate $A00A, MEM_PTR2
;     jsr strCmp
;     bcs _restoreMMU

;     #load16BitImmediate FCART, MEM_PTR1
;     #load16BitImmediate $A00A, MEM_PTR2
;     jsr strCmp
;     bcs _restoreMMU
; _notFound    
;     clc
; _restoreMMU
;     lda MMU_TEMP
;     sta 13
;     rts



