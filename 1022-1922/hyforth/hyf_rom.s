;
;  COPYTORAM  - This HAS to sit at $A000 or the HyForth engine in OSROM will NOT find it.
;    so....this always needs to be the first thing in the library image before the heap,
;    therefore .org $A000, .include 'hyf_rom.s', .org $0800, ...(heap).
;
COPYMAIN = COPYSTART
RAMST = RAMSTART
COPYENDS = ends - RAMSTART + COPYSTART

COPYTORAM:
    jmp CTRSTART                     ; copies from mainoff thru endsoff to ramstart
    .byte >h_exit
    .byte <h_exit
    .byte >ends
CTRSTART:
    WCRLF_np
    WCRLF_np
    stz supprint               ; let it print
    lda #>COPYMAIN
    sta mainoff+1
    lda #<COPYMAIN
    sta mainoff
    ;
    lda #<COPYENDS
    sta endsoff
    lda #>COPYENDS
    sta endsoff+1
    ;
    lda #>RAMST
    sta ramstart+1
    lda #<RAMST
    sta ramstart
    WCRLF_np
    jsr MEMCPY
    rts
;;
WHERESFT:
    nop
    bit ftrain_0 + INROM               ; see if is of use
    nop
;;
