;
;  utes.s        -   math routines, Forth/OS utilities, sound init/core
;
.debuginfo
.segment "UTES"
;
; usually ends up at $E400 (see os_rom_C02.cfg)
;
;-----------------------------------------------------------------------
;SOUND_INIT, YM_LOADPATCH, YM_WRITE
;
; zero out all YM-2151 registers $28-$FF
;
;
SOUND_INIT:
                pha
                phx
                lda         #0
                ldx         #$14        ; turn off the clocks
                jsr         YM_WRITE
                ldx         #$28

@write_z:
                jsr         YM_WRITE
                bcs         @error
                inx
                bne         @write_z
                ldx         #IRQ_NUMBER_ONBOARD_SOUND
                lda         #<SOUND_IRQ_HANDLER
                ldy         #>SOUND_IRQ_HANDLER
                jsr         IRQ_SET_VECTOR
                clc

@error:
                plx
                pla
                rts


SOUND_IRQ_HANDLER:
                ; check which
                rti
;
;         zero page stuff for sound, in zero.s
;YMN0L = ZP_TEMP_VEC3
;YMN0H = YMN0L + 1
;YMN1L = ZP_TEMP_VEC4
;YMN1H = YMN1L + 1
;
;AZP0L = ZP_TEMP_VEC
;AZP0H = AZP0L + 1
;YMTMP1 = ZP_TEMP_VEC2
;YMTMP2 = YMTMP1 + 1
;
YM_TIMEOUT = 64

; Write value in A to YM-2151 register in X
YM_WRITE:
                sei
                phy
                ldy         #YM_TIMEOUT

@ym_wait1:
                dey
                bmi         @timeout
                bit         YM_DATA
                bmi         @ym_wait1
                stx         YM_REG
                ldy         #YM_TIMEOUT

@ym_wait2:
                dey
                bmi         @timeout
                bit         YM_DATA
                bmi         @ym_wait2
                sta         YM_DATA
                clc
                bra         @cleanup

@timeout:
                sec

@cleanup:
                ply
                cli
                rts

YM_LOADPATCH:
                ; Make re-entrant safe by protecting tmp and pointer variables from interrupt
                php
                sei

                ; and #$07 ; mask channel to range 0..7
                stx AZP0L
                sty AZP0H
                clc
                adc #$20 ; first byte of patch goes to YM:$20+channel
                tax

                lda (AZP0L)
                and #$3F

                ;sta ymtmp1
                ;lda ymshadow,x
                ;and #$C0 ; L+R bits for YM channel
                ;ora ymtmp1 ; Add the patch byte without L+R
                ora #$C0;

                jsr YM_WRITE
                bcs @fail
                ldy #0
                txa         ; YM_WRITE preserves X (YM register)
                ; Now skip over $28 and $30 by adding $10 to the register address.
                ; C guaranteed clear by successful ym_write
                adc #$10
                tax         ; set up for loop
@next:
                txa
                ; C guaranteed clear by successful YM_WRITE
                adc #$08
                bcs @success
                iny
                tax
                lda (AZP0L),y
                phy         ; YM_WRITE clobbers .Y
                jsr YM_WRITE
                ply
                bcc @next
@fail:
                plp         ; restore interrupt flag
                sec
                rts         ; return C set as failed patch write.
@success:
                plp         ; restore interrupt flag
                clc
                rts

; YM_DELAY_64 - Delay subroutine for musical note lengths
; A: number of 64th-note delays to wait (a 64th note @120 BPM = ~ 111,861 clock cycles @ 3.57955 MHz)
YM_DELAY_64:
                phx
                phy
                sta         YMTMP1

@far_outer:
                lda         #1          ; 2 cycles
                ldx         #75
                ldy         #142
                bra         @inner

@outer:
                ldx         #0          ; 2 cycles

@mid:
                ldy         #0          ; 2 cycles

@inner:
                dey                     ; 2 cycles
                bne         @inner      ; 3 cycles when branching, 2 when not
                dex                     ; 2 cycles
                bne         @mid        ; 3 cycles when branching, 2 when not

                ; Fine-tuning at end of inner loop
                dec                     ; 2 cycles
                bne         @outer      ; 3 cycles when branching, 2 when not
                dec         YMTMP1      ; 3 cycles
                bne         @far_outer  ; 3 cycles when branching, 2 when not
                ply
                plx
                rts                     ; 6 cycles
;
;  end of sound utilities
;
;-----------------------------------------------------------------------
;
;-------------------------------------------------------------
;                MATH routines
;         with MULT16 / DIV16, signs handled by calling word.
;         we just do the math here.
;
;    transition to Z_MATH1,2,3,4 to replace use of TEMP1,2,3,4
;
;
MULT16:                             ; 16 x 16 multiply; Z_MATH1 and Z_MATH2 are #'s, Z_MATH1 will be result
    stz Z_MATH3                       ; with Z_MATH3 as high bytes
    stz Z_MATH3+1
    ldx #17
    clc
MULTLOOP:
    ror Z_MATH3+1                     ; RIGHT.  if you need to go backwards, go backwards stupid fuck.
    ror Z_MATH3
    ror Z_MATH1+1
    ror Z_MATH1
    bcc MULTDECCNT
    clc
    lda Z_MATH2
    adc Z_MATH3
    sta Z_MATH3
    lda Z_MATH2+1
    adc Z_MATH3+1
    sta Z_MATH3+1
MULTDECCNT:
    dex
    bne MULTLOOP
    rts

;
;
;           16 / 16 divide; Z_MATH1 and Z_MATH2 #'s - Z_MATH3 is 'overflow'
;           Z_MATH2 divisor, Z_MATH1 dividend, Z_MATH1 + 3 = result + remainder
DIV16:
    stz Z_MATH3
    stz Z_MATH3+1
    ldx #16
UDIVLP:
    rol Z_MATH1
    rol Z_MATH1+1
    rol Z_MATH3
    rol Z_MATH3+1
UDIVCHK:
    sec
    lda Z_MATH3
    sbc Z_MATH2
    tay
    lda Z_MATH3+1
    sbc Z_MATH2+1
    bcc UDIVCNT
    sty Z_MATH3
    sta Z_MATH3+1
UDIVCNT:
    dex
    bne UDIVLP
    rol Z_MATH1
    rol Z_MATH1+1
    rts
;
;        32 / 16 divide; Z_MATH2-Z_MATH1 / Z_MATH3 #'s - Z_MATH4 is 'overflow'
;        -> Z_MATH2-Z_MATH1 + Z_MATH4 = result + remainder
DIV32:
    stz Z_MATH4
    stz Z_MATH4+1
    ldx #16
UDIV32LP:
    rol Z_MATH1
    rol Z_MATH1+1
    rol Z_MATH2
    rol Z_MATH2+1
    rol Z_MATH4
    rol Z_MATH4+1
UDIV32CHK:
    sec
    lda Z_MATH4
    sbc Z_MATH3
    tay
    lda Z_MATH4+1
    sbc Z_MATH3+1
    bcc UDIV32CNT
    sty Z_MATH4
    sta Z_MATH4+1
UDIV32CNT:
    dex
    bne UDIV32LP
    rol Z_MATH1
    rol Z_MATH1+1
    rol Z_MATH2
    rol Z_MATH2+1
    rts
;
;     galois32o - LSFR psuedo-random # generator
;
;  -- boilerplate --
; 6502 LFSR PRNG - 32-bit
; Brad Smith, 2019
; http://rainwarrior.ca
;
;
galois32o:
    ; rotate the middle bytes left
    ldy RSEED+2                     ; will move to RSEED+3 at the end
    lda RSEED+1
    sta RSEED+2
    ; compute RSEED+1 ($C5>>1 = %1100010)
    lda RSEED+3                     ; original high byte
    lsr
    sta RSEED+1                     ; reverse: 100011
    lsr
    lsr
    lsr
    lsr
    eor RSEED+1
    lsr
    eor RSEED+1
    eor RSEED+0                     ; combine with original low byte
    sta RSEED+1
    ; compute RSEED+0 ($C5 = %11000101)
    lda RSEED+3                     ; original high byte
    asl
    eor RSEED+3
    asl
    asl
    asl
    asl
    eor RSEED+3
    asl
    asl
    eor RSEED+3
    sty RSEED+3                     ; finish rotating byte 2 into 3
    sta RSEED+0
    rts
;-------------------------------------------------------------------
;                        NUMBER CONVERSIONS
;
DEC2ASCII:       ;  X is # - return as two digits in Z_MATH3, Z_MATH3+1
    lda #'0'
    sta Z_MATH3+1
    txa
    sta Z_MATH3
D2ASCLOOP:
    sec
    sbc #$0A
    bcc D2ASCNEXT
    inc Z_MATH3+1
    bra D2ASCLOOP
D2ASCNEXT:
    clc
    adc #$3A
    sta Z_MATH3
    rts
;
;      more math (from bios.s)
;
; MATH
MOD_10:
            ldx             #0
            cmp             #0
            bmi             @negative
            cmp             #100
            bmi             @pos_loop
            ldx             #10
            sec
            sbc             #100

@pos_loop:
            cmp             #10
            bmi             @pos_end
            inx
            sec
            sbc             #10
            bpl             @pos_loop

@pos_end:
            rts

@negative:
            cmp             #$A6            ; -90
            bpl             @neg_start
            adc             #$A6

@neg_start:
            clc

@neg_loop:
            adc             #10
            bmi             @neg_loop
            rts

REM_10:
            ldx             #0
            cmp             #0
            bmi             @negative
            cmp             #100
            bmi             @positive
            sbc             #100
            ldx             #10

@positive:
            sec

@pos_loop:
            inx
            sbc             #10
            beq             @pos_end
            bpl             @pos_loop
            dex
            adc             #10

@pos_end:
            rts

@negative:
            cmp             #$9B            ; -99
            bpl             @neg_start
            adc             #$9B
            ldx             #$F6            ; -10

@neg_start:
            clc

@neg_loop:
            dex
            adc             #10
            bmi             @neg_loop
            beq             @neg_end
            inx
            sec
            sbc             #10

@neg_end:
            rts

DIV_10:
            jsr             REM_10
            pha
            tya
            ply
            rts

ABS:
            cmp             #0
            bcs             NEG_DONE

NEGATE:
            eor             #$FF
            inc

NEG_DONE:
            rts
;
;    
;   
;
;-------------------------------------------------------------------------------------
;                                   MEMCPY
;    load mainoff ZP_TEMP_VEC -> ZP_TEMP_VEC2, ZP_TEMP_VEC3 is end of copy
;     with current ROM offsets (main = start, ends = finish)
;     and ramstart with destination corresponding to main.
;     Set 'supprint' <> 0 (TEMP5 $FC) to suppress printing of progress bar from Forth
;
;    reworked to used ZP_TEMP_VEC, ZP_TEMP_VEC2, ZP_TEMP_VEC3
;                     mainoff      endsoff       ramstart
;
;
;
; Dan's BIOS Memory Copy
; was ZP_TEMP_VEC: From, ZP_TEMP_VEC2: To, .A.Y: LSB/MSB size
;
;
MEMCPY_AY:                     ; to obviate Dan's version and have a length initialized version
    pha
    lda MC_ENDA                           ; dest in AY version
    sta MC_DEST                           ; copy to dest
    lda MC_ENDA+1
    sta MC_DEST+1
    pla
    clc
    adc MC_SRCA                           ; add source addr 
    sta MC_ENDA
    tya
    adc MC_SRCA+1
    sta MC_ENDA+1
    bcs CPY_RTS                           ; someone fucked up, bail out
MEMCPY:
    phx                                   ; preserve X
    ldy  #0
COPYLOOP:
    lda (MC_SRCA),y                       ; source address
    sta (MC_DEST),y                       ; dest address
    lda MC_SRCA
    cmp MC_ENDA                            ; compare to end address LSB
    bne SKIP1
    lda MC_SRCA+1                          ; and the MSB
    cmp MC_ENDA+1
    beq CPY_XRTS
SKIP1:
    lda supprint                           ; suppress progress bar if supprint != 0
    bne SKIP2
    lda #'.'
    jsr WRITE_CHAR
SKIP2:
    inc MC_SRCA                           ; increment source addr
    bne SKIP3
    inc MC_SRCA+1
SKIP3:
    inc MC_DEST                            ; increment dest
    bne SKIP4
    inc MC_DEST+1
SKIP4:
    bra COPYLOOP
CPY_XRTS:
    clc                                    ; all went well?
    plx                                    ; bring back X
CPY_RTS:
    rts
;---------------------------------------------------------------------------------
;                 DUMPREG, DUMPPAGE  - debugger
;
;
;------------------------------ DUMPREG ---------------------
;
DUMPTXT1:
        .byte "SP/PC/nv-bdizc/A/X/Y -> "
        .byte 0
DUMPMSG1:
        .byte "<spc> to continue, x for Wozmon, z for ZP, t for TIB, s for stacks"
        .byte $0D, $0A, 0

DUMPREG:            ; dump registers safely and print
    php                         ; -3
    pha                         ; -4
    phx                         ; -5
    phy                         ; -6
    lda   DFLAG
    beq   DPFCHECK
    jsr   WRITE_BYTE
    lda   #'!'
    jsr   WRITE_CHAR
    WCRLF
    jmp   DREGNXT
DPFCHECK:
    ldy   #0
    WCRLF_np
DUMPLP0:
    lda   DUMPTXT1, y
    beq   DUMPCON
    jsr  WRITE_CHAR
    iny
    bra   DUMPLP0
DUMPCON:
    tsx                         ; -6  - keeping tack of back-stack steps
    txa
    clc
    adc   #6
    jsr WRITE_BYTE      ; print stack pointer b4 jump
    lda #'/'
    jsr WRITE_CHAR 
    inx                         ; -5
    inx                         ; -4
    inx                         ; -3
    inx                         ; -2
    inx                         ; -1
    lda   $0100,x               ; get PC LSB
    tay
    inx                         ; 0
    lda $0100,x
    jsr WRITE_BYTE        ; get PC MSB
    tya
    jsr WRITE_BYTE
    lda #'/'
    jsr WRITE_CHAR 
        ;   whew
        ;
    dex                         ; -1
    dex                         ; -2
    lda   $0100,x               ; get status byte
    ldy   #8
DUMPLP2:
    rol
    pha
    bcc   DUMPSKx               ; NV-BDIZC
    lda   #'1'
    bra   DUMPSKy
DUMPSKx:
    lda   #'0'
DUMPSKy:
    jsr WRITE_CHAR                  ; print y-th bit
    pla
    dey
    bne   DUMPLP2
    lda #'/'
    jsr WRITE_CHAR
    dex                         ; -3
    lda $0100,x
    jsr WRITE_BYTE              ; print A
    lda #'/'
    jsr WRITE_CHAR 
    dex                         ; -4
    lda $0100,x
    jsr WRITE_BYTE              ; print X
    lda #'/'
    jsr WRITE_CHAR 
    dex                         ; -5
    lda $0100,x
    jsr WRITE_BYTE              ; print Y
    WCRLF_np
    ldy   #0
DUMPLP1:                        ; print message
    lda   DUMPMSG1, y
    beq   DREGLP1
    jsr   WRITE_CHAR
    iny
    bra   DUMPLP1
DREGLP1:
    stz   Z_DEBUG               ; clear for dumping pages below
    jsr   READ_CHAR             ; wait for a key
    bcc   DREGLP1
    cmp   #'s'              ; print out stacks?
    bne   DREGSK3
    jsr   DUMPSTACK
DREGSK3:
    cmp   #'z'              ; print out zp?
    bne  DREGSK5
    jsr  DUMPZP
DREGSK5:
    cmp   #'t'              ; print out INBUF?
    bne  DREGSK4
    jsr  DUMPTIB
DREGSK4:
    cmp   #'x'
    bne   DREGELSE
    jsr   $FE00                 ; go to Wozmon if necc
DREGELSE:
    cmp   #$0D                 ; continue on enter
    beq   DREGNXT
    jmp   DPFCHECK              ; otherwise print eveything again
DREGNXT:
    ply                         ; and restore everything
    plx
    pla
    plp
    rts
;
;   subs for particular pages
;
DUMPTIB:                            ; dump TIB
    php
    pha
    lda #>INBUF
    sta Z_DEBUG+1
    jmp DUMPPDBG
DUMPSTACK:                          ; dump DS/RT stack area
    php
    pha
    lda #>DS
    sta Z_DEBUG+1
    jmp DUMPPDBG
DUMPZP:                             ; dump ZP
    php
    pha
    stz Z_DEBUG+1
    jmp DUMPPDBG
;
;                 DUMPPAGE
;
DUMPPAGE:                           ; general purpose page dumper
                                    ; Z_DEBUG starts masked at $F0, Z_DEBUG+1 is page #
    php
    pha
DUMPPDBG:
    ldy #0
DUMPLOOP:
    tya
    clc
    adc Z_DEBUG
    pha
    bcc DUMPSK2
    lda Z_DEBUG+1
    inc
    .byte $2C                    ; skip 2 bytes
DUMPSK2:
    lda Z_DEBUG+1
    jsr WRITE_BYTE
    pla
    jsr WRITE_BYTE
    lda #':'
    jsr WRITE_CHAR 
DPLOOP2:
    lda (Z_DEBUG), y
    jsr WRITE_BYTE
    lda #$20
    jsr WRITE_CHAR              ; print space between columns
    iny
    tya
    and #$0F                    ; 00001111
    beq  DPSKIP
    bra  DPLOOP2
DPSKIP:
    lda #$20
    jsr WRITE_CHAR
    phy
    tya
    sec
    sbc #$10                    ; subtract 16 to rewind the line
    tay
DPPLOOP:
    lda (Z_DEBUG), y              ; printable ascii
    cmp #$20
    bcc PPERIOD
    cmp #$7F
    bcs PPERIOD
    jsr WRITE_CHAR
    bra DPPSKIP
PPERIOD:
    lda #'.'
    jsr WRITE_CHAR
DPPSKIP:
    iny
    tya
    and #$0F
    beq DPPEND
    bra DPPLOOP
DPPEND:
    ply
    WCRLF_np
    tya                         ; need this to check y = 0
    bne DUMPLOOP
DUMPSTKEND:
    WCRLF_np
    pla
    plp
    rts
;
UTES_END:
;
;  end of utes.s
;      
          