

keyrepeat .namespace

MEASUREMENT_TIMEOUT = 30
REPEAT_TIMEOUT = 3
COOKIE_MEASUREMENT_TIMER = $10
COOKIE_REPEAT_TIMER = $11
IMPOSSIBLE_KEY = 0

SHIFT_LEFT_RAW = 0  ; The same on C64 keyboard operated on a Jr.
SHIFT_RIGHT_RAW = 1 ; The same on C64 keyboard operated on a Jr.
CTRL_RAW  = 2       ; The same on C64 keyboard operated on a Jr.
ALT_RAW   = 4       ; Also Commodore key on C64 keyboard operated on a Jr.
ALTGR_RAW = 5
FNX_RAW   = 6

SET_CTRL  = %00000001
SET_ALT   = %00000010
SET_FNX   = %00000100
SET_SHIFT = %00001000
CLR_CTRL  = %11111110
CLR_ALT   = %11111101
CLR_FNX   = %11111011
CLR_SHIFT = %11110111

init
    stz TRACKING.numMeasureTimersInFlight 
    stz TRACKING.numRepeatTimersInFlight 
    stz TRACKING.lastKeyPressed
    stz TRACKING.keyUpDownCount
    lda #IMPOSSIBLE_KEY
    sta TRACKING.lastKeyReleased
    stz TRACKING.metaState
    rts

FOCUS_VECTOR .word dummyCallBack

makeTimer .macro interval, cookie
    lda #\interval
    sta TIMER_HELP.interval
    lda #\cookie
    sta TIMER_HELP.cookie
    jsr setTimer60thSeconds
.endmacro


; set a timer that fires after the number of 1/60 th seconds
setTimer60thSeconds
    ; get current value of timer
    lda #kernel.args.timer.FRAMES | kernel.args.timer.QUERY
    sta kernel.args.timer.units
    jsr kernel.Clock.SetTimer
    ; carry should be clear here as previous jsr clears it, when no error occurred
    ; make a timer which fires interval units from now
    adc TIMER_HELP.interval
    sta kernel.args.timer.absolute
    lda #kernel.args.timer.FRAMES
    sta kernel.args.timer.units
    lda TIMER_HELP.cookie
    sta kernel.args.timer.cookie
    ; Create timer
    jsr kernel.Clock.SetTimer 
    rts


keyEventLoop
    ; Peek at the queue to see if anything is pending
    lda kernel.args.events.pending ; Negated count
    bpl keyEventLoop
    ; Get the next event.
    jsr kernel.NextEvent
    bcs keyEventLoop
    ; Handle the event
    lda myEvent.type    
    cmp #kernel.event.key.PRESSED
    bne _checkKeyRelease
    jsr handleKeyPressEvent
    bcs keyEventLoop
    jsr processKeyPress
    bcs keyEventLoop
    rts
_checkKeyRelease
    cmp #kernel.event.key.RELEASED
    bne _checkTimer
    jsr handleKeyReleaseEvent
    bra keyEventLoop
_checkTimer
    cmp #kernel.event.timer.EXPIRED
    bne keyEventLoop
    jsr handleTimerEvent
    bcs keyEventLoop
    jsr processKeyPress
    bcs keyEventLoop
    rts


processKeyPress
    jmp (FOCUS_VECTOR)


handleKeyPressEvent
    lda myEvent.key.flags 
    and #myEvent.key.META
    beq _isAscii
    lda myEvent.key.raw
    jsr testForFKey
    bcs _handleFKey
    cmp #SHIFT_RIGHT_RAW
    bne _shiftLeft
    lda TRACKING.metaState
    ora #SET_SHIFT
    sta TRACKING.metaState
    bra _done
_shiftLeft
    cmp #SHIFT_LEFT_RAW
    bne _ctrl
    lda TRACKING.metaState
    ora #SET_SHIFT
    sta TRACKING.metaState
    bra _done
_ctrl
    cmp #CTRL_RAW
    bne _fnx
    lda TRACKING.metaState
    ora #SET_CTRL
    sta TRACKING.metaState
    bra _done
_fnx
    cmp #FNX_RAW
    bne _alt1
    lda TRACKING.metaState
    ora #SET_FNX
    sta TRACKING.metaState
    bra _done
_alt1
    cmp #ALT_RAW
    bne _alt2
    lda TRACKING.metaState
    ora #SET_ALT
    sta TRACKING.metaState
    bra _done
_alt2
    cmp #ALTGR_RAW
    bne _done
    lda TRACKING.metaState
    ora #SET_ALT
    sta TRACKING.metaState
_done
    sec                                            ; we did not recognize the key. Make another loop iteration in keyEventLoop
    rts
_handleFKey
    lda myEvent.key.ascii    
    bra _startMeasureTimer
_isAscii
    lda myEvent.key.ascii
_startMeasureTimer
    sta TRACKING.lastKeyPressed
    #makeTimer MEASUREMENT_TIMEOUT, COOKIE_MEASUREMENT_TIMER
    inc TRACKING.numMeasureTimersInFlight
    inc TRACKING.keyUpDownCount
    lda TRACKING.lastKeyPressed
    clc                                            ; The user pressed a key. Stop iteration in keyEventLoop and return key code.
    rts


handleKeyReleaseEvent
    lda myEvent.key.flags 
    and #myEvent.key.META
    beq _isAscii
    lda myEvent.key.raw
    jsr testForFKey
    bcs _handleFKey
    cmp #SHIFT_RIGHT_RAW
    bne _shiftLeft
    lda TRACKING.metaState
    and #CLR_SHIFT
    sta TRACKING.metaState
    bra _done
_shiftLeft
    cmp #SHIFT_LEFT_RAW
    bne _ctrl
    lda TRACKING.metaState
    and #CLR_SHIFT
    sta TRACKING.metaState
    bra _done
_ctrl
    cmp #CTRL_RAW
    bne _fnx
    lda TRACKING.metaState
    and #CLR_CTRL
    sta TRACKING.metaState
    bra _metaEnd
_fnx
    cmp #FNX_RAW
    bne _alt1
    lda TRACKING.metaState
    and #CLR_FNX
    sta TRACKING.metaState
    bra _metaEnd
_alt1
    cmp #ALT_RAW
    bne _alt2
    lda TRACKING.metaState
    and #CLR_ALT
    sta TRACKING.metaState
    bra _metaEnd
_alt2
    cmp #ALTGR_RAW
    bne _metaEnd
    lda TRACKING.metaState
    and #CLR_ALT
    sta TRACKING.metaState
_metaEnd
    rts
_handleFKey
    ldx myEvent.key.raw
    bra _updateTracking
_isAscii
    ldx myEvent.key.ascii
_updateTracking
    lda TRACKING.keyUpDownCount
    beq _done                                      ; counter is already zero => we have missed an event. Do not activate repeat. In essence ignore event.
    dec TRACKING.keyUpDownCount
    bne _continue
    ldx #IMPOSSIBLE_KEY                            ; counter was zero, this means that we can allow last key pressed == last key released
    stz TRACKING.numRepeatTimersInFlight           ; cancel all repeat timers which are in flight
_continue
    stx TRACKING.lastKeyReleased                   ; State seems to be consistent. Save code of released key.
_done
    rts


handleTimerEvent
    lda myEvent.timer.cookie
    cmp #COOKIE_MEASUREMENT_TIMER
    bne _checkRepeatTimer
    jsr handleMeasurementTimer
    rts
_checkRepeatTimer
    cmp #COOKIE_REPEAT_TIMER
    bne _wrongTimer
    jsr handleRepeatTimer
    rts
_wrongTimer
    sec
    rts


handleMeasurementTimer
    lda TRACKING.keyUpDownCount
    cmp #1                                         ; There should be exactly one key still being pressed
    beq _testForNumInFlight
    lda TRACKING.numMeasureTimersInFlight
    beq _noRepeat                                  ; don't decrement if already zero. We seem to have missed some events.
    dec TRACKING.numMeasureTimersInFlight
    bra _noRepeat                                  ; No key or several keys currently pressed => do nothing. Cause another loop iteration in keyEventLoop
_testForNumInFlight
    lda TRACKING.numMeasureTimersInFlight
    beq _noRepeat                                  ; counter is already zero => we have missed an event. Do not activate repeat
    dec TRACKING.numMeasureTimersInFlight
    bne _noRepeat                                  ; zero flag not set => There is at least one other timer in flight, so the one which arrived was not the last to be created
    lda TRACKING.lastKeyPressed
    cmp TRACKING.lastKeyReleased
    beq _noRepeat                                  ; last key pressed and released are are the same *and* there is one key pressed. This can't be right ...
    #makeTimer REPEAT_TIMEOUT, COOKIE_REPEAT_TIMER ; start repeat timer
    inc TRACKING.numRepeatTimersInFlight
    lda TRACKING.lastKeyPressed                    ; return key press to caller => Stop iteration in keyEventLoop
    clc
    rts
_noRepeat
    sec                                            ; Cause another loop iteration in keyEventLoop
    rts


handleRepeatTimer
    lda TRACKING.numRepeatTimersInFlight
    beq _noRepeat                                  ; We received a timer event even though we did not record the timer creation => something went wrong or timer was cancelled
    cmp #1
    beq _continue                                  ; Exactly one timer in flight, i.e. this is the one we received
    dec TRACKING.numRepeatTimersInFlight           ; More than one are in flight => We wait for the youngest and ignore this one
    bra _noRepeat
_continue
    dec TRACKING.numRepeatTimersInFlight
    lda TRACKING.keyUpDownCount
    cmp #1                                         ; There should be exactly one key still being pressed
    beq _testRestartRepeat
    bra _noRepeat                                  ; No key or several keys currently pressed => do nothing. Cause another loop iteration in keyEventLoop
_testRestartRepeat
    lda TRACKING.lastKeyPressed
    cmp TRACKING.lastKeyReleased
    beq _noRepeat                                  ; last key pressed and released are are the same *and* there is one key pressed. This can't be right ...
    #makeTimer REPEAT_TIMEOUT, COOKIE_REPEAT_TIMER ; start repeat timer
    inc TRACKING.numRepeatTimersInFlight
    lda TRACKING.lastKeyPressed                    ; return key press to caller => Stop iteration in keyEventLoop
    clc    
    rts
_noRepeat
    sec                                            ; Cause another loop iteration in keyEventLoop
    rts

.endnamespace