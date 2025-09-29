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

TXT_MSG          .text "                 Select program to start from cartridge (v1.2.6)                "
TXT_SELECT_INFO  .text "           Start entry by typing the corresponding character or select          "
TXT_SEL_INFO2    .text "               entry with cursor keys and press return to start it              "
TXT_NO_KUP_FOUND .text "              Only loader found on cartridge. Press any key to exit.            "

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

UPPER_LINE  .fill 80
LOWER_LINE  .fill 80
MIDDLE_LINE .fill 80
NORMAL_LINE .fill 80

makeStr .macro addr, val
    lda #\val
    ldx #0
_loop1
    sta \addr, x
    inx
    cpx #80
    bne _loop1
.endmacro


prepareStrings
    #makeStr UPPER_LINE, 173
    #makeStr LOWER_LINE, 173
    #makeStr MIDDLE_LINE, 173
    #makeStr NORMAL_LINE, ' '

    lda #169
    sta UPPER_LINE
    lda #170
    sta UPPER_LINE + 79

    lda #171
    sta LOWER_LINE
    lda #172
    sta LOWER_LINE +  79

    lda #164
    sta MIDDLE_LINE
    lda #168
    sta MIDDLE_LINE + 79

    lda #174
    sta NORMAL_LINE
    sta NORMAL_LINE + 79

    lda #174
    sta TXT_SELECT_INFO
    sta TXT_SELECT_INFO + 79
    sta TXT_SEL_INFO2
    sta TXT_SEL_INFO2 + 79
    sta TXT_MSG
    sta TXT_MSG + 79
    sta TXT_NO_KUP_FOUND
    sta TXT_NO_KUP_FOUND + 79

    rts


main
    jsr setup.mmu
    jsr clut.init
    jsr prepareStrings
    jsr txtio.init80x60
    ;jsr txtio.cursorOn

    lda #$10
    sta CURSOR_STATE.col 
    jsr txtio.clear
    jsr initEvents

    jsr discoverContents
    bne _otherKUPFound

    jsr printHeader
    #printString TXT_NO_KUP_FOUND, len(TXT_NO_KUP_FOUND)
    #printString NORMAL_LINE, 80
    #printString LOWER_LINE, 80
    jsr waitForKey
    bra _toBasic

_otherKUPFound
    stz CURRENT_ENTRY
    jsr printAvailable

_restart
    jsr keyrepeat.init
    #load16BitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

_toBasic
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


TXT_EXIT  .text "x. Exit to BASIC"

NULL .word 0

NUM_PROGS_FOUND .byte 0

REF_TABLE
CB .dstruct Entry_t, '1', NULL, 0, NULL, 0
A  .dstruct Entry_t, '2', NULL, 0, NULL, 0
B  .dstruct Entry_t, '3', NULL, 0, NULL, 0
C  .dstruct Entry_t, '4', NULL, 0, NULL, 0
D  .dstruct Entry_t, '5', NULL, 0, NULL, 0
E  .dstruct Entry_t, '6', NULL, 0, NULL, 0
F  .dstruct Entry_t, '7', NULL, 0, NULL, 0
BA .dstruct Entry_t, '8', NULL, 0, NULL, 0
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
BX .dstruct Entry_t, 'v', NULL, 0, NULL, 0
BY .dstruct Entry_t, 'w', NULL, 0, NULL, 0
BZ .dstruct Entry_t, 'y', NULL, 0, NULL, 0

MMU_TEMP .byte 0
CURRENT_BLOCK .byte 0
PROG_LEN .byte 0

discoverContents
    #load16BitImmediate STR_DATA, MEM_PTR2
    stz NUM_PROGS_FOUND

    ldx #$FF
    ldy #0
    sty PROG_LEN

    lda 13
    sta MMU_TEMP

    ldy #0
    lda #$81
    sta CURRENT_BLOCK
_blockLoop
    cpy #32
    beq _restoreMMU

    lda PROG_LEN
    beq _lookAtBlock
    dec PROG_LEN
    lda PROG_LEN
    beq _lookAtBlock
    bra _nextBlock

_lookAtBlock
    lda CURRENT_BLOCK
    sta 13

    lda $A000
    cmp #$F2
    bne _nextBlock

    lda $A001
    cmp #$56
    bne _nextBlock

    inx
    jsr copyNameAndInfo
    lda $A002
    sta PROG_LEN

_nextBlock
    iny
    inc CURRENT_BLOCK
    bra _blockLoop

_restoreMMU
    lda MMU_TEMP
    sta 13

    inx
    stx NUM_PROGS_FOUND
    lda NUM_PROGS_FOUND

    rts


FOUND_TEMP .byte 0
copyNameAndInfo
    phx
    phy
    stx FOUND_TEMP

    ; set MEM_PTR3 to REF_TABLE entry
    txa
    asl
    asl
    asl
    clc
    adc #<REF_TABLE
    sta MEM_PTR3
    lda #0
    adc #>REF_TABLE
    sta MEM_PTR3+1

    #load16BitImmediate $A00A, MEM_PTR1

    ldy #Entry_t.kupName
    lda MEM_PTR2
    sta (MEM_PTR3), y
    iny
    lda MEM_PTR2+1
    sta (MEM_PTR3), y

    jsr strCopy
    ldy #Entry_t.kupLen
    sta (MEM_PTR3), y

    jsr strSkip

    ldy #Entry_t.description
    lda MEM_PTR2
    sta (MEM_PTR3), y
    iny
    lda MEM_PTR2+1
    sta (MEM_PTR3), y

    jsr strCopy
    ldy #Entry_t.descriptionLen
    sta (MEM_PTR3), y

    ply
    plx

    rts


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
    ; a normal key was pressed. Test if this key belongs to a
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


moveToEnd
    lda #79
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
    rts


L_ARROW    .text 174, " ", 151, "> "
L_BLANKS   .text 174,"    "
R_ARROW    .text " <", 151, " "
R_BLANKS   .text "    "

printLineStart
    phy
    ldy DO_HIGHLIGHT
    bne _arrow
    #printString L_BLANKS, len(L_BLANKS)
    bra _endArrow
_arrow
    #printString L_ARROW, len(L_ARROW)
_endArrow
    ply
    rts


printLineEnd
    ldy DO_HIGHLIGHT
    bne _arrow
    #printString R_BLANKS, len(R_BLANKS)
    bra _endArrow
_arrow
    #printString R_ARROW, len(R_ARROW)
_endArrow
    jsr moveToEnd
    lda #174
    jsr txtio.charOut
    rts


printHeader
    jsr txtio.home
    #printString UPPER_LINE, 80
    #printString NORMAL_LINE, 80
    #printString TXT_MSG, len(TXT_MSG)
    #printString NORMAL_LINE, 80
    #printString MIDDLE_LINE, 80
    #printString NORMAL_LINE, 80
    rts


printFooter
    #printString NORMAL_LINE, 80
    #printString MIDDLE_LINE, 80
    #printString NORMAL_LINE, 80
    #printString TXT_SELECT_INFO, len(TXT_SELECT_INFO)
    #printString TXT_SEL_INFO2, len(TXT_SEL_INFO2)
    #printString NORMAL_LINE, 80
    #printString LOWER_LINE, 80
    rts



HELP_LEN .word 0
ORG_LEN  .byte 0
TEMP     .byte len(R_ARROW) + 1
SCR_MAX  .word 80
calcProperDescLen
    sta ORG_LEN
    sta HELP_LEN
    stz HELP_LEN + 1
    #add16BitByte CURSOR_STATE.xPos, HELP_LEN
    #add16BitByte TEMP, HELP_LEN
    #cmp16BitImmediate 80, HELP_LEN
    bcs _noCorrection
    #load16BitImmediate 80, SCR_MAX
    #load16BitImmediate len(R_ARROW) + 1, HELP_LEN
    #add16BitByte CURSOR_STATE.xPos, HELP_LEN
    #sub16Bit HELP_LEN, SCR_MAX
    lda SCR_MAX
    bra _returnCorrectedLength
_noCorrection
    lda ORG_LEN
_returnCorrectedLength
    rts


; y-reg has to contain number of entry
printEntryLine
    jsr printLineStart
    tya
    asl
    asl
    asl
    sta STRUCT_INDEX
    clc
    adc #Entry_t.selectionKey
    tax
    lda REF_TABLE, x
    ldy DO_HIGHLIGHT
    beq _noReverse
    #toRev
_noReverse
    jsr txtio.charOut
    lda #'.'
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut

    ; load address of program name
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
    ; load length of program name
    lda REF_TABLE, x
    jsr txtio.printStr

    ; load length of description
    lda STRUCT_INDEX
    clc
    adc #Entry_t.descriptionLen
    tax
    lda REF_TABLE, x
    sta DESC_LEN
    beq _skipDesc

    lda #':'
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut

    ; load address of description
    lda STRUCT_INDEX
    clc
    adc #Entry_t.description
    tax
    lda REF_TABLE, x
    sta TXT_PTR3
    inx
    lda REF_TABLE, x
    sta TXT_PTR3 + 1
    ; test if the description fits on the screen
    lda DESC_LEN
    jsr calcProperDescLen
    jsr txtio.printStr
_skipDesc
    #noRev
    jsr printLineEnd
    #printString NORMAL_LINE, 80
    rts


printExitLine
    jsr printLineStart
    lda DO_HIGHLIGHT
    beq _noReverse2
    #toRev
_noReverse2    
    #printString TXT_EXIT, len(TXT_EXIT)
    #noRev
    jsr printLineEnd
    rts


; y-reg has to contain number of entry
testHighlight
    stz DO_HIGHLIGHT
    cpy CURRENT_ENTRY
    bne _noHighlight
    inc DO_HIGHLIGHT
_noHighlight    
    rts


DO_HIGHLIGHT .byte 0
STRUCT_INDEX .byte 0
DESC_LEN .byte 0
printAvailable
    jsr printHeader
    ldy #0
_loopAllowed
    cpy NUM_PROGS_FOUND
    bne _next
    bra _done
_next
    jsr testHighlight
    phy
    jsr printEntryLine
    ply
    iny
    bra _loopAllowed
_done
    jsr testHighlight
    jsr printExitLine
    jsr printFooter
    rts


; String in MEM_PTR1. MEM_PTR1 is set to first byte after
; the string.
strSkip
    ldy #0
_loop
    lda (MEM_PTR1), y
    beq _done
    iny
    bra _loop
_done
    iny
    tya
    clc
    adc MEM_PTR1
    sta MEM_PTR1
    lda #0
    adc MEM_PTR1 + 1
    sta MEM_PTR1 + 1
    rts


LEN_TEMP .byte 0
; String in MEM_PTR1, target in MEM_PTR2. MEM_PTR2 is moved to next free byte.
; MEM_PTR1 is moved to next string. accu contains length of string.
strCopy
    ldy #0
_loop
    lda (MEM_PTR1), y
    sta (MEM_PTR2), y
    beq _done
    iny
    bra _loop
_done
    sty LEN_TEMP
    iny

    tya
    clc
    adc MEM_PTR2
    sta MEM_PTR2
    lda #0
    adc MEM_PTR2 + 1
    sta MEM_PTR2 + 1

    tya
    clc
    adc MEM_PTR1
    sta MEM_PTR1
    lda #0
    adc MEM_PTR1 + 1
    sta MEM_PTR1 + 1

    lda LEN_TEMP

    rts


STR_DATA .byte ?

