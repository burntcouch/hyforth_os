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
;
;    the 10-23-26 1920 version
;
;    reworked to used ZP_TEMP_VEC, ZP_TEMP_VEC2, ZP_TEMP_VEC3
;                     mainoff      endsoff       ramstart
;
    WCRLF_np
;    lda #1
;    sta supprint               ; supress printing of progress
    lda #>COPYMAIN
    sta ZP_TEMP_VEC+1
    jsr WRITE_BYTE
    lda #<COPYMAIN
    sta ZP_TEMP_VEC
    jsr WRITE_BYTE
    lda #'+'
    jsr WRITE_CHAR
    lda #<COPYENDS
    sta ZP_TEMP_VEC2
    jsr WRITE_BYTE
    lda #>COPYENDS
    sta ZP_TEMP_VEC2+1
    jsr WRITE_BYTE
    ;
    lda #>RAMST
    sta ZP_TEMP_VEC3+1
    lda #<RAMST
    sta ZP_TEMP_VEC3
    jsr MEMCPY
    lda #$20
    jsr WRITE_CHAR
    lda #'f'
    jsr WRITE_CHAR    
    lda #'i'
    jsr WRITE_CHAR   
    lda #'n'
    jsr WRITE_CHAR   
    WCRLF_np
    rts

;     the 10-22-26 1922 version
;
;    WCRLF_np
;    WCRLF_np
;    stz supprint               ; let it print
;    lda #>COPYMAIN
;    sta ZP_TEMP_VEC+1
;    lda #<COPYMAIN
;    sta ZP_TEMP_VEC
    ;
;    lda #<COPYENDS
;    sta ZP_TEMP_VEC2
;    lda #>COPYENDS
;    sta ZP_TEMP_VEC2+1
    ;
;    lda #>RAMST
;    sta ZP_TEMP_VEC3+1
;    lda #<RAMST
;    sta ZP_TEMP_VEC3
;    WCRLF_np
;    jsr MEMCPY
;    rts  
;;
