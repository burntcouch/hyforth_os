;
;   upper.s  - utility functions for HyForth - eventually ROM resident
;
;---------------------------------------------------------------------
;  error / system messaging
;           set ERRFLAG to appropriate error code (hyforth.s preamble),
;      print error/system message, then clear ERRFLAG and ERRPTR again.
;
WERROR:
    lda #>err_jumptable
    sta ERRPTR+1
    lda ERRFLAG
    beq ERREND
    asl a
    clc
    adc #<err_jumptable
    sta ERRPTR
    bcc ERRSKIP
    inc ERRPTR+1
ERRSKIP:
    WERR ERRPTR
ERREND:
    lda #0
    sta ERRFLAG
    sta ERRPTR
    sta ERRPTR+1
    rts
;
;err_jumptable:    moved to RAM space (hyforth.s) to facilitate custom
;   system messaging
;
;  error messages
RPTR_ERR:
    .byte " !RT PTR ERROR!"
    .byte 0
SPTR_ERR:
    .byte " !DS PTR ERROR!"
    .byte 0
DIV_ERR:
    .byte " !DIV ZERO!"
    .byte 0
OOM_ERR:
    .byte " !LOW MEM!"
    .byte 0
UKW_ERR:
    .byte " !UNK WORD!"
    .byte 0
SEC_ERR:
    .byte " !SECURITY!"
    .byte 0
SYS_ERR:
    .byte " !SYS ERR!"
    .byte 0
PAD_ERR:
    .byte " !PAD OOM!"
    .byte 0

;-------------------------------------------------------------
;
;           CODE called by engine AND heap
;
;------- used by 'exit'
;------------------------NOTE:  this is ALL of 'exit' but the screaming.
;----------------- For modularity purposes this is the only sensible place for it.
;
EXIT:
unnest:                             ; EXIT - done with previous word, on to next whether compiled or primitive

    ldy #INSTPTR
    jsr rpull                       ; IP = [RTPTR], RTPTR += 2

next:                               ;    go on to next word; IP is pointing at next entry in CFA of word
                                    ; or first entry in CFA of next word.
                                    ;
                                    ; WORKREG = (INSTPTR) ; INSTPTR += 2
    ldx #INSTPTR
    ldy #WORKREG
    jsr copyfrom                    ; W = [IP], IP += 2  ( and either ENTER or EXECUTE )

pick:                               ;        'THE SWITCHER' - COMPILED OR PRIMITIVE?
                                    ;
.ifdef DEBUG                        ;  DEBUG
    lda DFLAG
    bne PRINTWSKIP                  ; print W and [W] etc if DEBUG
    WSEQ_raw WDISP
    lda WORKREG+1
    jsr WRITE_BYTE
    lda WORKREG
    jsr WRITE_BYTE
    WSEQ_raw WATDISP
    ldy #0
    lda (WORKREG),y
    jsr WRITE_BYTE
PRINTWSKIP:
.endif
;
; .. use old-fashioned way AND new tricks
;  ( otherwise known as THE SWITCH )
;
    lda WORKREG + 1                 ; compare pages (MSBs)
    cmp #>ends + 1                  ;  !! Compiled must be higher in memory than hardcoded !! (see below)
    bmi jump                        ; jump over nest if native code
    ldy #1                          ; ldy #0 if check extra byte ($89 or $24 for various 'bit' variants)
    lda (WORKREG),y
    beq jump                        ; yep, jump to native execution

nest:                               ; ENTER in classic Forth lingo   ( COMPILED )
    ldy #INSTPTR
    jsr rpush                       ; RTPTR -=2, [RTPTR] = [IP]
    lda WORKREG                     ; W = IP
    sta INSTPTR
    lda WORKREG + 1
    sta INSTPTR + 1
    jmp next                        ; next

jump:                               ; EXECUTE                      ( PRIMITIVE )
    jmp (WORKREG)                   ; start running code at next word
                                    ;  JUMP [W]
;
; other stuff we want in ROM
;
HYWELCOME:
    .byte $0D, $0A
    .byte "HyForth 0.930 11-12-2026"
    .byte $0D, $0A, 0
;
;------- used by 'autoload'
ALOADTIB:
    ldy #0
    lda #$20
    sta (TIB),y
ALOADLOOP:
    lda (TEMP7),y
    beq ALOADSKIP
    iny
    sta (TIB),y
    bra ALOADLOOP
ALOADSKIP:
    jsr ALOADCHKDONE
    iny
    rts                             ; y points at trailing space

ALOADCHKDONE:
    iny
    lda (TEMP7),y
    bne ALNOTSKIP                   ; calc next address if not done
    stz ALFLAG                      ; turn off autoload
    bra ALNOTDONE
ALNOTSKIP:
    tya
    clc
    adc TEMP7
    sta TEMP7
    bcc ALNOTDONE
    inc TEMP7+1
ALNOTDONE:
    dey
    rts
;
;--------------------------------------------------------------------------
;
;  PAD management and MALLOC
;
;  padinit, cpypad, etc.
;
PADINIT:
    ldy #<PAD                    ; first entry of PAD
    sty PADPTR                   ; is $0000 (no previous item)
    stz PAD
    ldy #>PAD
    sty PADPTR+1
    stz PAD+1
    rts

CPYPAD:
    jsr spull_1
NEWPAD:                            ; first stab at new PAD item setup
                                   ; address of temp string in TEMP2, zero term'd
    lda PADPTR
    sta TEMP1
    lda PADPTR+1                   ; backup PADPTR to TEMP1
    sta TEMP1+1
    inc PADPTR
    inc PADPTR                     ; skip over previous address and length
    inc PADPTR
    ldy #$FF
NEWPADLP0:                         
    iny
    lda (TEMP2),y
    sta (PADPTR),y
    bne NEWPADLP0                ; copy string
    iny
    tya                      
    ldy #2
    sta (TEMP1),y              ; store length
    tay
    clc
    adc PADPTR                   ; advance PTR to start of next entry
    sta PADPTR
    bcc NEWPADSK0
    inc PADPTR+1
NEWPADSK0:
    ldy #0
    lda TEMP1
    sta (PADPTR),y               ; write previous entry address
    iny                          ; at head of next entry
    lda TEMP1+1
    sta (PADPTR),y
    jsr spush_0                   ; push address of item on stack
    rts
;
;-------- malloc and mlen
;  
MALLOC:
    ;  TEMP1 and TEMP2 should have bytes / record type if 'jsr MALLOC'
    ;  uses TEMP3, y, x, a
    lda MEMLAST
    sec
    sbc #3
    sta MEMLAST
    bcs MALSK00
    dec MEMLAST+1
MALSK00:
    sec
    sbc TEMP1
    sta MEMLAST
    lda MEMLAST+1
    sbc TEMP1+1
    sta MEMLAST+1
                        ;MEMLAST updated to start of new record
    lda MEMLAST
    sta TEMP3
    lda MEMLAST+1
    sta TEMP3+1         ; use TEMP3 to walk through clearing of memory
    ldy #0
    lda TEMP2            ; write type first
    sta (TEMP3),y
    iny
    lda TEMP1            ; LSB length
    sta (TEMP3),y
    iny
    lda TEMP1+1          ; MSB length
    sta (TEMP3),y
    ldx #TEMP3
    lda #3
    jsr addwx            ; increment TEMP3 by 3
MALLOOP:
    lda #0
    ldy #0
    sta (TEMP3),y
    dec TEMP1
    bne MALSK02    
    lda TEMP1+1
    beq MALCONT
    lda TEMP1
    cmp #$FF
    bne MALSK02       
    dec TEMP1+1
MALSK02:
    inc TEMP3
    bne MALSK01
    inc TEMP3+1
MALSK01:    
    bra MALLOOP
MALCONT:                   ; now store MEMLAST at MEMPTR
    ldy #0
    lda MEMLAST
    sta (MEMPTR),y
    iny
    lda MEMLAST+1
    sta (MEMPTR),y
    lda MEMPTR+1
    sta TEMP1+1
    lda MEMPTR           
    sta TEMP1             ; copy to TEMP1 before incrementing
    sec                   ; MEMPTR + 2
    sbc #2
    sta MEMPTR
    bcs MALLOCEND
    dec MEMPTR+1
MALLOCEND:
    rts    
; 
MEMLEN:           ; address from mem stack in TEMP2
     ldy #0
     lda (TEMP2),y
     sta TEMP3
     iny
     lda (TEMP2),y   ; and deref once
     sta TEMP3+1
     ldy #1
     lda (TEMP3),y   ; skip over type, get length
     sta TEMP1
     iny
     lda (TEMP3),y
     sta TEMP1+1
     rts
;-----------------------------------------------------------------------------------
;                                TEXTGET / TXG3
;   get escaped, delimited text from INBUF, store in temp or permanent memory
;    'token' has set NXTTOK to starting address in INBUF.
;
;  uses TEMP1, TEMP2, TEMP3 (MALLOC only?), TEMP4, TEMP5, TEMP6, x, y
;    TEMP1 starts as length, then as dest address (pushed on stack to end)
;    TEMP2 as record type, then as modified dest address during copy
;    TEMP3 stomped by MALLOC ('Q'), not affect by 'q' option
;    TEMP4 counts esc chars, 4+1 flag for PAD vs memory dest
;    TEMP5 and TEMP6 are bookends of NXTTOK offset
;    y used as index throughout in various read/cpy operations
;    x at end to copy back so parser knows how many chars to blank out if all goes well
;
;   Original TEXTGET code (TXG2) still stored in 11/12/26, 9:41AM version
;
;          copy/escape - translate escaped chars
;
;      will modify this sometime to require and handle escaped
;    two-digit hex values, ie \EE and such.
;
;  NOTE:  if a \0 or \00 is in middle of string, TEXTGET WILL 
;    copy it correctly, but...it may not print or copy right
;    with other functions that expect proper z-termination.
;
;  table includes all chars from $20 to $46 inclusive
;    $30-$39 -> trunc'd to $0x, $41-$46 to $0A-$0F
;    $22 is dbl-quote, $1B (\@) is escape char
;
TXHEXTBL:
    .byte " !"
    .byte $22
    .byte "#$%&'()*+,-./"
    .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09
    .byte ":;<=>?"
    .byte $1B, $0A, $0B, $0C, $0D, $0E, $0F
    
TXCPYESC:
    iny 
    lda (NXTTOK),y
    cmp #$20                    ; is this a single hex digit
    bcc TXCPYSK                 ; or the escape char '\@'?
    cmp #$47
    beq TXCPYSK
    bcs TXCPYSK
    sec
    sbc #$20                    ; if so, lookup substitute
    tax
    lda TXHEXTBL,x
TXCPYSK:
    dec TEMP2                    ; adjust TEMP2 so we are 
    bcs TXDECT2SK                ; not printing the extra '\'
    dec TEMP2+1
TXDECT2SK:
    rts
;
;  end of TXG2  (new text capture)
;
;-------------- TXG3 -  new version of TEXTGET
;
TXG3:
    jmp TX3GETTIB                 ; TEMP1 will have length, TEMP2 dest addr of string
                                  ; TEMP6 has starting index in buffer, TEMP5 end index
;                                   
TX3TIBDONE:                       ; 
    ;                   now we switch between q (PAD) and Q (MALLOC)
    ;
    lda TEMP4+1
    cmp #'Q'
    beq TX3mCONT                ; 'q' or 'Q' ?
    ;
    ;  if 'q':
    lda TEMP1
    ldy #2
    sta (PADPTR),y              ; copy length to PAD
    lda PADPTR                  ; and then copy ptr location
    sta TEMP2
    sta TEMP1                    ; copy for pushing later
    lda PADPTR+1
    sta TEMP2+1
    sta TEMP1+1                  ; copy for pushing later
    ;
    bra TX3tCONT
    ;
    ;    if 'Q':
TX3mCONT:
    jsr MALLOC                      ; TEMP1 now has address on mem stack, length already written
    ldy #0
    lda (TEMP1),y
    sta TEMP2
    iny
    lda (TEMP1),y                   ; and make a copy of address for copy 
    sta TEMP2+1                     ; operation from input buffer below.
    ; continue
TX3tCONT:
    jmp TX3STRCPY
TX3STRCOPYDONE:                   ; copy string and translate escaped chars
    lda TEMP4+1
    cmp #'Q'
    beq TX3mCONT2                ; 'q' or 'Q' ?
    ldy #2                       ; 'q', so finish updating and incrementing PADPTR
    lda (PADPTR),y               ; get length
    inc a
    inc a
    inc a
    clc
    adc PADPTR
    sta PADPTR
    bcc TX3tUPD
    inc PADPTR+1
TX3tUPD:
    ldy #0
    lda TEMP1
    sta (PADPTR),y
    iny
    lda TEMP1+1
    sta (PADPTR),y
;    
TX3mCONT2:
    jmp TX3FIXTIB
TX3NOGOOD:
    sec                             ; C=1, no text, so process as token
TX3END:
    rts
;
;--
;
TX3GETTIB:
    stz TEMP4                       ; to count escape '\' chars
    stz TEMP4+1                     ; flag for PAD vs memory storage
    stz TEMP1+1                     ; will store length here
    lda #$04
    sta TEMP2                       ; record type is 'sz'
    stz TEMP2+1
    stz TEMP6                       ; to save y for later copy
    ldy #1                          ; skip len of first token
TX3SKSPC:
    lda (NXTTOK),y
    cmp #$20                        ; skip leading spaces
    bne TX3SK00
    iny
    bra TX3SKSPC
TX3SK00:
    cmp #'q'                        ; text will go to PAD
    bne TX3SK_Q
    bra TX3SK_q
TX3SK_Q:
    cmp #'Q'                        ; text will got to memory
    bne TX3NOGOOD
TX3SK_q:
;    and #$40                        ; mask off q vs Q bits
    sta TEMP4+1                     ; store q or Q
    iny
    lda (NXTTOK),y
    cmp #'^'
    bne TX3NOGOOD
    iny
    sty TEMP6                       ; TEMP6 stores pos of first char
TX3SCAN:
    lda (NXTTOK),y                  ; find delimiting '^'
    cmp #'\'
    bne TX3SK04
    inc TEMP4
TX3SK04:
    cmp #'^'                       
    bne TX3SK03                    ; handle escaped ^ only
    dey                            ; other escaped chars handled when copied to 
    lda (NXTTOK),y                 ; MALLOC'd address (see TX2COPYLOOP below)
    iny
    cmp #'\'
    bne TX3FOUND
TX3SK03:
    iny                             ; get index back after checking for \^
    tya
    clc
    adc NXTTOK
    cmp #MAXSTR
    bcs TX3NOGOOD
    bra TX3SCAN
TX3FOUND:                         ; quoted text found.  Now do some math.
    sty TEMP5                       ; TEMP5 is pos+1 last letter
    tya
    sec
    sbc TEMP6                       ; and TEMP6 is where we started, so...
    sec
    sbc TEMP4                       ; subtract escape (\) chars
    sta TEMP1                       ; and this should be the length
    inc TEMP1 
    jmp TX3TIBDONE
;
;--
;
;   now for math.  NXTTOK ptr needs to be ref'd with same y
;    as TEMP2, so we need to match them up...and we are hitting
;    the record at +3, so....TEMP6 is start
TX3STRCPY:
    lda TEMP2
    sec
    sbc TEMP6
    bcs TX3SK01
    dec TEMP2+1
TX3SK01:
    clc
    adc #3
    bcc TX3SK02
    inc TEMP2+1
TX3SK02:
    ldy TEMP6
TX3CPYLOOP:
    lda (NXTTOK),y
    cmp #'\'
    bne  TX3CPY0
    jsr TXCPYESC                   ; handle escaped chars (translate using table below)
TX3CPY0:
    sta (TEMP2),y
    iny
    cpy TEMP5
    bne TX3CPYLOOP
;
    lda #0
    sta (TEMP2),y                   ; put zero on end
    jsr spush_0                     ; push address from mem stack on DS
    jmp TX3STRCOPYDONE
;
;
TX3FIXTIB:
    lda TEMP5                       ; now get the length of statement in TIB back
    sec                             ; so can return in X
    sbc TEMP6
    clc
    adc #4
    tax                             ; calc and bring back length to X
    clc                             ; C=0 means all good, so tell parser to cleanup buffer
    jmp TX3END
;
;
;
.ifdef numbers
;------------------------
;      CONVERT DIGITS, PUSH on DS

DIGCONVT:    ;  Y is index into NXTPTR, X is length
    stz TEMP1
    stz TEMP1+1
    stz TEMP2                       ; no necc for bin or hex, but
    stz TEMP2+1                     ; since is convenient....
    stz TEMP6
    ldy #1                          ; skip over length
    lda #10
    sta DIGBASE
    lda (NXTTOK),y
    cmp #'-'
    beq DIGCONV_MINUS
    cmp #'$'
    beq DIGHEX1
    cmp #'%'
    beq DIGBIN1
    bra DIG_SNG
DIGCONV_MINUS:
    inc TEMP6
    jmp DIG_XY
DIGBIN1:
    lda #2
    sta DIGBASE
    jmp DIG_XY
DIGHEX1:
    lda #16
    sta DIGBASE
DIG_XY:
    iny
    dex
DIG_SNG:
  .ifdef SINGLE
    cpx #1                          ; skip single digit, handle hard-wired or...
    bne DIGCONV_LOOP                ; only one digit left, we can handle that elsewhere
    jmp DIGCONV_ERR                 ; not really an error, just return and let 'find' to it
  .endif
DIGCONV_LOOP:
    jsr GETDIG
    bcc DIGCONT0
    jmp DIGCONV_ERR
DIGCONT0:
    pha                             ; else save it to add in a bit
    asl TEMP1                       ; do first shift
    rol TEMP1+1
    lda DIGBASE                     ; check base that was set above
    cmp #10
    beq DIGDEC                      ; it's DEC, go there
    cmp #2
    beq DIGBIN                      ; it's BIN, go there
    bra DIGHEX                      ; Go to hex if others not true
DIGDEC:
    asl TEMP1                       ; 2nd shift; upper nybble doesn't end up right
    rol TEMP1+1
    lda TEMP1                       ; load results of two shifts
    clc
    adc TEMP2                       ; add in previous total from last loop
    sta TEMP1
    lda TEMP1+1                     ; and same with second digit, and the carry
    adc TEMP2+1
    sta TEMP1+1
DIGDEC2:
    asl TEMP1                       ; final shift
    rol TEMP1+1
    pla                             ; bring back read digit
    cmp #10                         ; make sure it's not hex, mostly
    bcc DIGCONT                     ; jump to continue
    jmp DIGCONV_ERR                 ; else throw error
DIGHEX:
    asl TEMP1
    rol TEMP1+1
    asl TEMP1
    rol TEMP1+1
    asl TEMP1
    rol TEMP1+1                     ; shifted three more times
    pla
    jmp DIGCONT
DIGBIN:                             ; already did the single shift
    pla
    cmp #2
    bcs DIGCONV_ERR                 ; fall through to the additon of new digit
DIGCONT:
    clc                             ; add digit finally
    adc TEMP1
    sta TEMP1
    sta TEMP2                       ; copy to intermediate result in case another dec digit
    bcc DIGCONT2
    inc TEMP1+1                     ; and inc 2nd byte if necc.
DIGCONT2:
    lda DIGBASE
    cmp #10
    bne DIGCONT3
    lda TEMP1+1
    sta TEMP2+1                     ; save it for next round, regardless
    cmp #$80                        ; check to see if > $8000
    bcs DIGCONV_ERR
DIGCONT3:
    iny
    dex
    bne DIGCONV_LOOP
    lda DIGBASE
    cmp #10
    bne DIGCONT4
DECFINISH:
    lda TEMP6                       ; check for minus
    beq DIGCONT4
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    sta TEMP1+1
    inc TEMP1
    bne DIGCONT4
    inc TEMP1+1
DIGCONT4:
    jsr spush_0                     ; push TEMP1 on to stack
    clc
    rts
DIGCONV_ERR:
    sec
    rts

;--------------------------
GETDIG:                             ; y is index to next char in NXTTOK
    lda (NXTTOK),y
    sec
    sbc #'0'
    bcc GETDIG_ERR
    cmp #10
    bcc GETDIG_RTN
    sbc #7
    cmp #10
    bcc GETDIG_ERR
    cmp #16
    bcs GETDIG_ERR
GETDIG_RTN:                         ; pass carry clear for good digit
    clc
    rts
GETDIG_ERR:                         ; pass carry set for no digit
    sec
    rts
;  end of new number conv
;
H2NUM: 
 .byte $27,$10                ; 10000
 .byte $03,$E8                ; 1000
 .byte $00,$64                ; 100
 .byte $00,$0A                ; 10
HEX2DEC:                            ; uses X, TEMP1, Z_MATH1,2,3,4
    lda PADPTR
    sta TEMP1
    lda PADPTR+1
    sta TEMP1+1
    lda #0
    sta Z_MATH1                   ; flag for first non-zero digit
    
    inc PADPTR
    inc PADPTR
    inc PADPTR                     ; we'll come back to write length
    ldy #0
    ldx #0
H2DDIV10:
    lda H2NUM,x
    sta Z_MATH3+1
    inx
    lda H2NUM,x
    sta Z_MATH3
    inx
    stz Z_MATH4
H2DLOOP:
    lda Z_MATH2+1
    cmp Z_MATH3+1
    bcc  H2DSK1
    bne  H2DSK0
    lda Z_MATH2
    cmp Z_MATH3
    bcc  H2DSK1
H2DSK0:
    lda Z_MATH2
    sec
    sbc Z_MATH3
    sta Z_MATH2
    lda Z_MATH2+1
    sbc Z_MATH3+1
    sta Z_MATH2+1
    inc Z_MATH4
    bra H2DLOOP
H2DSK1:    
    lda Z_MATH1
    bne  H2DSK2
    lda Z_MATH4
    beq  H2DSK3
    inc Z_MATH1
H2DSK2:
    lda Z_MATH4
    clc
    adc #'0'
    sta (PADPTR),y
    iny
H2DSK3:
    cpx #8
    beq H2DFIN
    jmp H2DDIV10                      ; back to top of loop
H2DFIN:
    lda Z_MATH2
    clc
    adc #'0'
    sta (PADPTR),y
    iny                                  
    lda #0                           ; write 0 on end of string, oops!
    sta (PADPTR),y
    iny
    phy                               ; will pull back to A here in a bit
    tya
    clc
    adc PADPTR
    sta PADPTR
    bcc H2DSK4
    inc PADPTR+1
H2DSK4:
    jsr spush_0                       ; push address of string
;   update length and PADPTR
    pla                               ; pull back pushed Y
    ldy #2
    sta (TEMP1),y                     ; copy length
    ldy #0
    lda TEMP1
    sta (PADPTR),y                    ; and copy address of prev 
    iny                               ; entry here before leaving
    lda TEMP1+1
    sta (PADPTR),y
    rts
;
;
.endif    ; numbers
;
;--------------------------------------------------------------
;                     ctrl check  - s, c, x, v
;
;         ctrl-s - copy TIB 0 to y to current screen buffer line
;         ctrl-c - copy TIB 0 to y to PAD
;         ctrl-v - pull last PAD entry and overwrite TIB starting at y (bounds check)
;         ctrl-x - copy TIB 0 to y to PAD, clear TIB
;
CTRLCHECK:                   ; A has last key entered, Y is current position in TIB
    pha
    cmp #$13      ; ctrl-s
    beq DOCTRLS
    cmp #$03      ; ctrl-c
    beq JMPCTRLC
    cmp #$16      ; ctrl-v   - TIBEND should be check when adding into TIB
    beq JMPCTRLV
    cmp #$18      ; ctrl-x
    beq JMPCTRLX
    clc             ; fell through, return
CTRLEND:
    pla
    rts
    
DOCTRLS:
    sec
    jmp CTRLEND

JMPCTRLV:
    jmp DOCTRLV
JMPCTRLC:
    jmp DOCTRLC    
JMPCTRLX:
    jmp DOCTRLX
    
DOCTRLC:
    sty TEMP5
    lda PADPTR
    sta TEMP1
    lda PADPTR+1                   ; backup PADPTR to TEMP1
    sta TEMP1+1
    ldy #2
    lda TEMP5                      ; write the length while we're here
    sta (PADPTR),y
    lda #2
    clc
    adc PADPTR
    sta PADPTR
    bcc DOCCSK0
    inc PADPTR+1
DOCCSK0:
    ldy #1
DOCCLOOP:                         
    lda (TIB),y
    sta (PADPTR),y
    iny
    cpy TEMP5
    bne  DOCCLOOP
    lda #0
    sta (PADPTR),y            ; write zero at end
    lda TEMP5
    inc a
    clc
    adc PADPTR
    sta PADPTR
    bcc  DOCCSK1
    inc PADPTR+1
DOCCSK1:
    ldy #0
    lda TEMP1
    sta (PADPTR),y
    iny
    lda TEMP1+1
    sta (PADPTR),y
    ldy TEMP5                     ; restore y
    sec
    jmp CTRLEND
    
DOCTRLV:
    sty TEMP5      ; backup Y
    lda TIB+1
    sta TEMP1+1
    tya
    clc
    adc TIB
    sta TEMP1
    bcc DOCV_SK0
    inc TEMP1+1    
DOCV_SK0:
    ldy #0
    lda (PADPTR),y          ; we want PREVIOUS ITEM addr, not current 
    sta TEMP2               ; pointer addr
    iny
    lda (PADPTR),y
    sta TEMP2+1
    ora TEMP2               ; are we at zero?
    bne  DOCV_SK1   
    ldy TEMP5               ; if at zero, bail out.  restore Y
    sec                     ; and return 
    jmp  CTRLEND 
DOCV_SK1:
    lda TEMP2
    clc
    adc #3                 ; skip over address and length now
    sta TEMP2
    bcc  DOCV_SK2
    inc TEMP2+1
DOCV_SK2:
    ldy #$FF
DOCV_LP0:
    iny
    cpy TIBEND
    beq  DOCV_END
    lda (TEMP2),y
    sta (TEMP1),y
    beq DOCV_END
    jsr WRITE_CHAR      ; remember to write to the screen!
    bra DOCV_LP0
DOCV_END:
    iny
    lda #$20
    sta (TEMP1),y        ; tokenizer won't work w/o an extra space?
    jsr WRITE_CHAR       ;
    tya
    inc a
    clc
    adc TEMP5
    tay
    sec
    jmp CTRLEND
    
DOCTRLX:
    sec
    jmp CTRLEND
   
;--------------------------------- CLEAR ------------------------------
;
;  zero out $C8 - $FF, meet and greet
;  zero out INBUF
;  and clear SCRBUF
;
CLEAR:
    lda #$FF
    sta DFLAG                       ; debug OFF by default
zpclear:
    ldx #ZPSTART                    ; whoops, this is all the ZP that is used
    lda #0
zerolp:
    sta  $00,x
    inx
    bne zerolp
    ldx  #0
inbufzlp:                           ; and then clear out INBUF
    sta  INBUF,x
    inx
    bne  inbufzlp
    ldx  #0
stackslp:                           ; and then clear out DS / RT
    sta  DS,x
    inx
    bne  stackslp
        ; 
    jsr CLR_SCREENBUF               ; it does this
        ;  meet and greet
    ldy  #0
hywelclp:
    lda  HYWELCOME,y
    beq  CLREXIT
    jsr WRITE_CHAR
    iny
    bra  hywelclp
CLREXIT:
    jsr print_libtable
    rts

CLR_SCREENBUF:
;               clear screen buffer;  16 rows of 63 + 1 columns
    lda #$10
    sta TEMP5                       ; count rows from 16
    lda #<SCRBUF
    sta TEMP0
    lda #>SCRBUF
    sta TEMP0 + 1    
clrscrbuf0:
    lda #$20
    ldx HFECOLS                       ; count down from 63
    dex
    ldy #0
clrscrbuf1:
    sta (TEMP0),y
    iny
    dex
    bne clrscrbuf1               ; and 64th col is zero, so...
    lda #0                       ; all rows zero term'd but
    sta (TEMP0),y                ; don't know if really need
    lda TEMP0                    ; to clear rows this way or not, yet.
    clc
    adc #$40
    bcc clrscrbuf2
    inc TEMP0+1
clrscrbuf2:
    sta TEMP0
    dec TEMP5
    bne clrscrbuf0
    rts
;
;-------------------------------------------------------------------
;
;  ANSI CLS, cursor reposition, and color change
;
ANSIHDR:
    lda #27
    jsr WRITE_CHAR
    lda #91
    jsr WRITE_CHAR
    rts

ANSIONEDIG:   ;two ASCII digits in Z_ANSI1
    lda Z_ANSI1 + 1
    cmp #$30
    beq ansi_scr_00
    jsr WRITE_CHAR
ansi_scr_00:
    lda Z_ANSI1
    jsr WRITE_CHAR
    rts
;
CLEAR_SCR:
ANSICLS:
    jsr ANSIHDR
    lda #'2'    
    jsr WRITE_CHAR
    lda #'J'    
    jsr WRITE_CHAR
    rts    
    
ANSISCR:      ; assumes Z_ANSI1 AND Z_ANSI2 have digits 
              ; one or two digit ASCII #'s already
    jsr ANSIHDR
    jsr ANSIONEDIG
    lda #';'
    jsr WRITE_CHAR
    lda Z_ANSI2
    sta Z_ANSI1
    lda Z_ANSI2+1
    sta Z_ANSI1+1
    jsr ANSIONEDIG
    lda #'f'    
    jsr WRITE_CHAR
    rts
    
ANSICOL:                 ; assumes Z_ANSI1 has digits
    jsr ANSIHDR      
    jsr ANSIONEDIG
    lda #'m'    
    jsr WRITE_CHAR
    rts
;
; ---------------- end of upper.s
;
;   hyf_edit.s is loaded in hyforth.s directly after this
;