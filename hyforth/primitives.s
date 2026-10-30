;
; primitives.s
;

;----------------------------------------------------------------------
;  library management
;
def_word "libcnt", "libcnt", 0
    jsr LIBCNT
    sta TEMP1
    stz TEMP1+1
    jsr spush_0
    jmp next
    
LIBCNT:
    lda #>lib_jumptable
    sta TEMP1+1
    lda #<lib_jumptable
    sta TEMP1
    ldy #$FF
LIBCNTLOOP:
    iny
    lda (TEMP1),y
    iny
    ora (TEMP1),y          ; entry after last should be $0000
    bne LIBCNTLOOP
    tya
    lsr
    rts
    
def_word "lib", "lib", 0
    jsr spull_2                 ; nth library
    lda #>lib_jumptable
    sta TEMP1+1            
    ldx TEMP3               ; check that TEMP3 is not neg or out of bounds       
    dex                     ; need it 0 - LASTLIB-1 indexed
    bmi LIBNG
    ;
    ;
    jsr GETLIBENTRY
    tya
    bne LIBNG
LIBWLOOP:
    lda (TEMP0),y      ; TEMP0 should point at name of entry, step through
    beq LIBWEND       ; entry via y
    iny
    bra LIBWLOOP       ; step through name
LIBWEND:
    iny                 ; jump past lib type 'C' or 'B'
    iny
    lda (TEMP0),y
    sta TEMP1+1                 ; hi byte of lib address
    iny
    lda (TEMP0),y
    sta TEMP1                  ; lo byte of lib address
LIBEND:
    jsr spush_0               ; should have address of first entry of lib n in TEMP1
LIBNG:
    jmp next

def_word "libs", "libs", 0
    jsr print_libtable
    jmp next
    
print_libtable:
    lda #>lib_jumptable
    sta TEMP1+1
    ldx #0
LIBSLOOP:
    jsr GETLIBENTRY    ; looks up lib entry #x, sets up TEMP1 and TEMP0, y = 0
    tya
    bne LIBSEND
LIBSWLOOP:
    lda (TEMP0),y      ; TEMP0 should point at name of entry, step through
    beq LIBSWEND       ; entry via y
    iny
    jsr WRITE_CHAR     ; prints name of library
    bra LIBSWLOOP
LIBSWEND:
    lda #'-'
    jsr WRITE_CHAR
    iny
    lda (TEMP0),y
    jsr WRITE_CHAR                   ; print type 'C' or 'B'
    lda #$20
    jsr WRITE_CHAR
    iny
    lda (TEMP0),y
    jsr WRITE_BYTE                   ; hi byte of lib address
    iny
    lda (TEMP0),y
    jsr WRITE_BYTE                   ; lo byte of lib address
    WCRLF_np
    inx
    beq LIBSEND
    bra LIBSLOOP
LIBSEND:
    rts
    
GETLIBENTRY:               ; get entry pointed to by x
    txa
    asl a
    clc
    adc #<lib_jumptable
    sta TEMP1
    bcc LIBSNEXT
    inc TEMP1+1
LIBSNEXT:
    ldy #0
    lda (TEMP1),y
    sta TEMP0
    iny
    lda (TEMP1),y
    sta TEMP0+1
    dey
    lda (TEMP0),y
    iny
    ora (TEMP0),y
    bne LIBSKIP 
    rts
LIBSKIP:
    dey
    rts
;----------------------------------------------------------------------
; ( -- ) ae list of data stack
def_word ".S", "splist", 0      ; changed from %S
    lda DSPTR
    sta TEMP1
    lda DSPTR + 1
    sta TEMP1 + 1
    WCRLF_np
    lda #'S'
    jsr WRITE_CHAR 
    lda #DSEND
    jsr STKLIST
    WCRLF_np
    jmp next

; ( -- ) data stack empty?
def_word "?S", "spp", 0
    stz TEMP1+1
    stz TEMP1
    lda DSPTR
    cmp #DSEND
    bne EMPEND
EMPCONT:
    lda #$FF
    sta TEMP1
    sta TEMP1+1
EMPEND:
    jsr spush_0
    jmp next

; ( -- ) return stack empty?
def_word "?R", "rtp", 0
    stz TEMP1+1
    stz TEMP1
    lda RTPTR
    cmp #RTEND
    bne EMPEND
    jmp EMPCONT

;----------------------------------------------------------------------
; ( -- ) list of return stack
def_word ".R", "rplist", 0       ; changed from %R
    lda RTPTR
    sta TEMP1
    lda RTPTR + 1
    sta TEMP1 + 1
    WCRLF_np
    lda #'R'
    jsr WRITE_CHAR
    lda #RTEND
    jsr STKLIST
    WCRLF_np
    jmp next

;----------------------------------------------------------------------
;  list a sequence of references ( for .S and .R )
STKLIST:
    sec                 ; calc diff and length of list
    sbc TEMP1
    lsr
    tax                 ; hide in X
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    lda #$20
    jsr WRITE_CHAR
    txa
    jsr WRITE_BYTE         ; print # of entries
    lda #$20
    jsr WRITE_CHAR
    txa
    beq @ends
    ldy #0
@loop:
    lda #$20
    jsr WRITE_CHAR
    iny
    lda (TEMP1), y
    jsr WRITE_BYTE
    dey
    lda (TEMP1), y
    jsr WRITE_BYTE
    iny
    iny
    dex
    bne @loop
@ends:
    rts

;------------------------------- DUMP ----------------------------------
; ( -- ) dump memory
def_word "dump", "dump", 0
    jsr spull_1             ; TEMP2 LSB is # of pages
    jsr spull_0             ; TEMP1 has starting addr
    lda TEMP1+1
    sta Z_DEBUG+1
    lda TEMP1
    and #$F0
    sta Z_DEBUG
    ldx TEMP2
    bne FDUMPLOOP
    ldx #1                  ; always print at least one page
FDUMPLOOP:
    jsr DUMPPAGE
    inc Z_DEBUG+1
FDUMPGET:
    jsr READ_CHAR           ; wait for char to continue to next page
    bcc FDUMPGET
    dex
    bne FDUMPLOOP
    clc
    jmp next

;------------------------------ WLIST -----------------------------------
;
; ( -- ) clean word list,
def_word "words", "words", 0

; load LASTHEAP
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2

; load NEXTHEAP
    lda NEXTHEAP + 1
    sta TEMP3 + 1
    lda NEXTHEAP
    sta TEMP3
    stz TEMP5
    dec TEMP5

WORD_LOOP:
    inc TEMP5       ; increment 'words per line' count
    lda TEMP2       ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if TEMP2 = $0000, end if so
    beq WORD_END
    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1

    lda TEMP5        ; check word count, CRLF if 4th one
    and #$03
    bne WORD_SKIP
    WCRLF_np
    lda TEMP5
    cmp #80
    bne WORD_SKIP
WWAITKEY:
    jsr READ_CHAR           ; wait for char to continue to next page
    bcc WWAITKEY
    stz TEMP5

WORD_SKIP:               ; TEMP1 has address of word-record,
; put address            ; (TEMP1) is link to previous record
    lda #$20
    jsr WRITE_CHAR       ; print space
    lda TEMP1 + 1
    jsr WRITE_BYTE       ; print msb of addr
    lda TEMP1
    jsr WRITE_BYTE       ; print lsb of addr

    ldx #TEMP1          ; advance TEMP1 to size + flag, name
    lda #2
    jsr addwx
    ldy #0
    jsr WRDSHOWNAME        ; print (size + flag,) name

    lda #10
    sec
    sbc TEMP6
    tax
SPCLOOP:
    lda #$20
    jsr WRITE_CHAR
    dex
    bne SPCLOOP
    lda #'|'
    jsr WRITE_CHAR
    iny                  ; update TEMP1 again, point at CFA
    tya
    ldx #TEMP1
    jsr addwx
    lda TEMP3           ; instead of printing refs, just advance TEMP1 to TEMP3
    sta TEMP1
    lda TEMP3+1
    sta TEMP1+1

WORD_CONT:
    lda TEMP2            ; update TEMP2 and TEMP3, advance in linked list
    sta TEMP3
    lda TEMP2 + 1
    sta TEMP3 + 1
    ldy #0
    lda (TEMP3), y
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1
    ldx #(TEMP3)
    lda #2
    jsr addwx
    jmp WORD_LOOP
WORD_END:
    clc              ; clean return
    jmp next
;
;  routines needed for 'words'
;
; print size and name
;  TEMP1 has address of word-record + 2, y is
; is keeping track of offset withi in.
;
WRDSHOWNAME:
    lda #':'
    jsr WRITE_CHAR
;    lda (TEMP1), y
;    jsr WRITE_BYTE       ; size and flag
    lda #$20
    jsr WRITE_CHAR
    lda (TEMP1), y
    and #$3F           ; mask off top two bits
    tax                ; x now has length
    sta TEMP6          ; save length of name

NAMELOOP:              ; name
    iny                ; first time through, (TEMP1),y advanced to first char of name
    lda (TEMP1), y
    jsr WRITE_CHAR
    dex
    bne NAMELOOP
    lda #$20
    jsr WRITE_CHAR
    rts
    
;----------------------------------------------------------------------
; ( saddr -- waddr ) find a word by matching to string
;
;  TEMP5 will point to the following string in the input buffer
; for now, you must match ALL chars in the name of the word; no partial
; matches.  Addr of word will end up on stack.
;
; so this will be used like 'w@ words' which will return CFA of 'words'
;  equivalent of Forth-79 word 'tick' (single quote)
;
def_word "w@", "wfind", 0
WLOOKUP:
    jsr token            ; get following token
    lda NXTTOK
    sta TEMP5            ;store addr of first char
    lda NXTTOK + 1
    sta TEMP5 + 1
    
; load LASTHEAP
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2

; load NEXTHEAP
    lda NEXTHEAP + 1
    sta TEMP3 + 1
    lda NEXTHEAP
    sta TEMP3

WMATCH_LOOP:
    lda TEMP2       ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if TEMP2 = $0000, end if so
    beq WMATCH_END
    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1

WMATCH_SKIP:               ; TEMP1 has address of word-record,
;                          TEMP1) is link to previous record
    ldx #TEMP1          ; advance TEMP1 to size + flag, name
    lda #2
    jsr addwx
    ldy #0
    jsr WNAMEMATCH       ; check if match; carry set, YES
    bcs WMATCHFOUND
    
    iny                  ; update TEMP1 again, point at CFA
    tya
    ldx #TEMP1
    jsr addwx
    lda TEMP3           ; instead of printing refs, just advance TEMP1 to TEMP3
    sta TEMP1
    lda TEMP3+1
    sta TEMP1+1

WMATCH_CONT:
    lda TEMP2            ; update TEMP2 and TEMP3, advance in linked list
    sta TEMP3
    lda TEMP2 + 1
    sta TEMP3 + 1
    ldy #0
    lda (TEMP3), y
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1
    ldx #(TEMP3)
    lda #2
    jsr addwx
    jmp WMATCH_LOOP
WMATCH_END:
    stz TEMP1
    stz TEMP1 + 1
    jsr spush_0
    clc              ; clean return
    jmp next
    
WMATCHFOUND:
    jsr spush_0      ; push address of record + 2
    ldy #0
    lda (TEMP1),y
    and #$3F
    sta TEMP1
    stz TEMP1 + 1
    jsr spush_0      ; push length
    clc
    jmp next
;
;  TEMP1 has addr of string to test, TEMP2 is current word-record addr + 2
;
WNAMEMATCH:
    lda (TEMP1), y
    and #$3F
    tax
WMATCHLOOP:              ; name
    iny                ; first time through, (TEMP1),y advanced to first char of name
    lda (TEMP5), y     ; addr of string
    cmp (TEMP1), y     ; addr of current name
    bne  WMATCH_NO
    dex
    bne WMATCHLOOP
    bra WMATCH_YES
WMATCH_NO:
    clc
    rts
WMATCH_YES:
    sec
    rts
;----------------------------------------------------------------------
;
;  holdover from original 'words' but keep for now
;
show_refer:
; print references (PFA - parameter field addresses)
;    ldx #(TEMP1)
;
;SHWREFLOOP:
;    PRINT_SPACE
;    lda TEMP1 + 1
;    PRINT_BYTE
;    lda TEMP1
;    PRINT_BYTE
;    PRINT_CHAR #':'
;    iny
;    PRINT_BYTE {(TEMP1), y}
;    dey
;    PRINT_BYTE {(TEMP1), y}
;    lda #2
;    jsr addwx
;
; check if at the end
;    lda TEMP1
;    cmp TEMP3
;    bne SHWREFLOOP
;    lda TEMP1 + 1
;    cmp TEMP3 + 1
;    bne SHWREFLOOP
;    rts
;
;----------------------------------------------------------------------
;
; ( u -- u ) print top of DS in hexadecimal in MSB:LSB form
def_word ".", "dot", 0
    lda #$20
    jsr WRITE_CHAR
    jsr spull_0
    lda TEMP1
    jsr WRITE_BYTE
    lda TEMP1 + 1
    jsr WRITE_BYTE
    jmp next     ; '.' now consumes top of DS
;
; ( u -- u ) print top of DS in ascii, two bytes, msb first
def_word ".C", "cdot", 0
     jsr spull_0
     ldy #$FF
     lda TEMP1
CDOTAGAIN:     
     tax
     cmp #$1F
     bcc UPRINT
     cmp #$7F
     bcs UPRINT
     jsr WRITE_CHAR
CDOTRTN:
     lda TEMP1+1
     iny
     beq CDOTAGAIN
     bra CDOTEND
UPRINT:                ; print unprintable chars as \x<hex> 
     lda #'\'
     jsr WRITE_CHAR
     lda #'x'
     jsr WRITE_CHAR
     txa
     jsr WRITE_BYTE
     bra CDOTRTN
CDOTEND:
     jmp next
;
;
; ( -- )  comments in ()
def_word "(", "comment", 0
COM_TOKLOOP:
    jsr token                  ; get next token
    ldy #0
    lda (NXTTOK),y
    cmp #1                     ; is it longer than 1?
    bne COM_TOKLOOP
    iny
    lda (NXTTOK),y
    cmp #')'                   ; does it start with a parens?
    bne COM_TOKLOOP
    jmp next
;
;
; ( -- u) push following character in input buffer to stack
def_word "ord", "ord", 0
    jsr token                  ; get first token
    ldy #0
    lda (NXTTOK),y
    tax
    clc
    adc #'0'
    jsr WRITE_CHAR             ; print length, just for fun
    lda #$20
    sta (NXTTOK), y           ; clear it (may be unnecc.)
    iny
ORDLOOP:                     ; loop is necc because can pick up ANSI codes!
    lda (NXTTOK), y
    beq  ORDNONE
    cmp #$20
    beq  ORDNONE
    sta TEMP1
    stz TEMP1+1
    lda #$20
    sta (NXTTOK), y
    iny
    phx
    jsr spush_0
    plx
    dex
    bne ORDLOOP
ORDNONE:
    jmp next
;
; (addr -- )  -------  print sz string using new allocated RAM space
;
def_word ".sz", "szdot", 0
    jsr spull_0    ; will have MEMPTR addr
    ldy #0
    lda (TEMP1),y
    sta TEMP2      ; will have RAM stack address
    iny
    lda (TEMP1),y
    sta TEMP2+1    ; TEMP2 now points at type byte of string?
    ldy #0
    lda (TEMP2),y
    and #$7F       ; mask off temp flag
    cmp #MEM_SZ
    bne SZEND
    ldy #3
SZLOOP:
    lda (TEMP2),y
    beq SZEND
    jsr WRITE_CHAR
    iny
    bra SZLOOP
SZEND:
    jmp next
;
;  print n bytes from addr
;
def_word ".sn", "sndot", 0
    jsr spull_0    ; length in LSB
    jsr spull_1    ; addr to print from
    ldx TEMP1      ; ignore TEMP+1, 256 bytes max
    ldy #0
SNLOOP:
    lda (TEMP2),y
    jsr WRITE_CHAR
    iny
    dex
    beq SNEND
    bra SNLOOP
SNEND:
    jmp next
; ( addr n -- w0 w1 ... w(n-1) )  push n words from memory to stack
;
def_word "dsgetn@", "dsgetn", 0
    ldy #TEMP4
    jsr spull    ; get # WORDS
    jsr spull_1  ; get ptr addr
    jsr MEMLEN   ; returns TEMP3 w/maddr, length in TEMP1
    lda TEMP4
    asl a
    sta TEMP4
    cmp TEMP1
    bcs DSGETNSK
    sta TEMP1
DSGETNSK:
    lda TEMP1
    cmp #$78
    bcc DSGETNSK2
    jmp DSGETERR
DSGETNSK2:
    clc
    adc #3
    sta TEMP1
    ldy #3
    jmp DSGLOOP
;
; ( addr -- w w ... w )  push words from memory to stack
;
def_word "dsget@", "dsget", 0
    jsr spull_1    ; get addr on memstack
    jsr MEMLEN     ; maddr in TEMP3, length in TEMP1
    lda TEMP1
    cmp #$78
    bcs DSGETERR
    lda TEMP1+1
    bne DSGETERR    ; too much data, can't push this on
    lda TEMP1
    clc
    adc #3
    sta TEMP1
    ldy #3
DSGLOOP:
    lda (TEMP3),y
    sta TEMP2
    iny
    lda (TEMP3),y
    sta TEMP2+1
    iny
    phy
    jsr spush_1
    ply
    cpy TEMP1
    bne DSGLOOP
DSGEND:
    jmp next
DSGETERR:
    lda #ERR_SPTR   ; throw pointer error
    sta ERRFLAG
    jmp errrtn
;
; ( w w w..len addr -- addr)    stores len BYTES (words * 2) from stack
;
def_word "dwstk!", "dwstkstore", 0
    jsr HSSETUP
    jsr DW_STFWD
    jsr spush_1      ; and push ptr addr back on stack
    jmp next

DW_STFWD:
    ldy #0            ; count up
DWFLOOP:
    lda DSPTR
    sec
    sbc #DSEND
    bcs DW_FWDEND
    phy
    jsr spull_0
    ply
    lda TEMP1
    sta (TEMP3),y
    iny
    lda TEMP1+1
    sta (TEMP3),y
    iny
    cpy TEMP5
    bne DWFLOOP
DW_FWDEND:
    rts
;
;
; ( 0c 0c 0c...len addr -- addr)    stores len chars from stack
;
def_word "dcstk!", "dcstkstore", 0
    jsr HSSETUP
    jsr HS_STFWD
    jsr spush_1      ; and push ptr addr back on stack
    jmp next

HS_STFWD:
    ldy #0            ; count up
HSRLOOP:
    lda DSPTR
    sec
    sbc #DSEND
    bcs HS_FWDEND
    phy
    jsr spull_0
    ply
    lda TEMP1
    sta (TEMP3),y
    iny
    cpy TEMP5
    bne HSRLOOP
HS_FWDEND:
    rts
;
; ( 0c 0c 0c...len addr -- addr)  stores len chars from stack, reverse order
;
def_word "rdcstk!", "rdstkstore", 0
    jsr HSSETUP
    jsr HS_STREV
    jsr spush_1      ; and push ptr addr back on stack
    jmp next

HSSETUP:
    jsr spull_1     ; get addr from malloc run -> TEMP2
    jsr MEMLEN      ; length in TEMP1, maddr TEMP3
    lda TEMP1
    sta TEMP5
    lda TEMP3
    clc
    adc #3          ; calc offset to storage
    sta TEMP3
    bcc HSSETUPEND
    inc TEMP3+1
HSSETUPEND:
    rts

HS_STREV:
    ldy TEMP5            ; count down from length
    lda #0
    dey
    sta (TEMP3),y
HSFLOOP:
    lda DSPTR
    sec
    sbc #DSEND
    bcs HS_REVEND
    phy
    jsr spull_0
    ply
    lda TEMP1
    dey
    sta (TEMP3),y
    bne HSFLOOP
HS_REVEND:
    rts
;
;   replace leading zeros with spcs when creating decimal ascii string
;
DECSFINISH:
    ldy #0
DECSCLRLOOP:             ; replace $00 or leading $30 with spaces
    lda (TEMP3),y
    beq  DECSTSK02
    cmp #'0'
    beq  DECSTSK02
    bra  DECSTDONE
DECSTSK02:
    lda #$20
    sta (TEMP3),y
    iny
    bra DECSCLRLOOP
DECSTDONE:
    rts
;
;
;
def_word "decs!", "decstore", 0
    jsr HSSETUP
    jsr HS_STREV
    jsr DECSFINISH
    jsr spush_1      ; and push ptr addr back on stack
    jmp next
;
;
;---------------------------------------------------------------------
;                     ' extensions ' in original AGSB
;---------------------------------------------------------------------
; ( w n -- w >> n ) -- shift right
def_word ">>", "shr", 0
    jsr spull_1
    lda TEMP2
    beq SRZERO
    jsr spull_0
SRLOOP:
    lsr TEMP1 + 1
    ror TEMP1
    dec TEMP2
    bne SRLOOP
    jmp this         ; 'this' includes jsr spush_0 and next
SRZERO:
    jmp next

; ( w n -- w << n ) -- shift left
def_word "<<", "shl", 0
    jsr spull_1
    lda TEMP2
    beq SLZERO
    jsr spull_0
SLLOOP:
    asl TEMP1
    rol TEMP1 + 1
    dec TEMP2
    bne SLLOOP
    jmp this         ; 'this' includes jsr spush_0 and next
SLZERO:
    jmp next

;--------------- bit test/set/clear ----------------------------------
; ( n b -- t? )
def_word "tbit", "tbit", 0            ; nondestructive test bit
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0
    jsr spush_0     ; backup!
    jsr BITWIND
    lda TEMP1
    and #$01
    beq TBCLR      ; test bit 0
    lda #$FF
    sta TEMP1
    sta TEMP1+1
    bra TBITEND
TBCLR:
    stz TEMP1
    stz TEMP1+1
TBITEND:
    jmp this

; ( n b -- ns )
def_word "sbit", "sbit", 0             ; set bit
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0
    jsr BITWIND
    lda TEMP1
    ora #$01        ; set bit 0
    sta TEMP1
    jsr BITUNWIND
    jmp this

; ( n b -- nc )
def_word "cbit", "cbit", 0
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0
    jsr BITWIND
    lda TEMP1
    and #$FE       ; clear bit 0
    sta TEMP1
    jsr BITUNWIND
    jmp this

BITWIND:
    stz TEMP3
    stz TEMP3+1
    ldx TEMP2
    beq BITWSKIP
BITWLOOP:
    lsr TEMP1+1
    ror TEMP1
    ror TEMP3+1
    ror TEMP3
    dex
    bne BITWLOOP
BITWSKIP:
    rts

BITUNWIND:
    ldx TEMP2
    beq BITUWSKIP
BITUNWLOOP:
    asl TEMP3
    rol TEMP3+1
    rol TEMP1
    rol TEMP1+1
    dex
    bne BITUNWLOOP
BITUWSKIP:
    rts
;---------------------------------------------------------------------
;     start of AGSB dictionary
;---------------------------------------------------------------------
core_dict:
;---------------------------------------------------------------------
; ( -- u ) ; tos + 1 unchanged
def_word "key", "key", 0
KEYRDLP:
    jsr READ_CHAR
    bcc KEYRDLP
    sta TEMP1
    jmp this         ; 'this' includes jsr spush_0 and next

;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull_0
    lda TEMP1
    jsr WRITE_CHAR
    jmp next

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    and TEMP1
    eor #$FF            ; toggles FIRST byte okay, but...
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    eor #$FF           ; and then second.
    jmp keeps          ; keeps - sta TEMP1+1, then jsr spush_0 and 'next'
    
;---------------------PLUS and MINUS----------------------------------
; ( w1 w2 -- w1+w2 )
def_word "+", "plus", 0
    jsr spull_1        ; load TEMP2 from stack
    jsr spull_0        ; then TEMP1
    clc
    lda TEMP2
    adc TEMP1
    sta TEMP1
    lda TEMP2+1
    adc TEMP1+1
    jmp keeps        ; keeps - sta TEMP1+1, then jsr spush_0 and 'next'

; ( w1 w2 -- w1-w2 )
def_word "-", "minus", 0
    jsr spull_1        ; get TEMP 2 from stack
    jsr spull_0        ; then TEMP 1
    sec
    lda TEMP1
    sbc TEMP2
    sta TEMP1
    lda TEMP1+1
    sbc TEMP2+1
    clc              ; clean return since math involved
    jmp keeps        ; keeps - sta TEMP1+1, then jsr spush_0 and 'next'

;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF)  normalize boolean - change TOS to $0000 if false, $FFFF if TRUE
def_word "bool", "normbool", 0
    jsr spull_0
    lda TEMP1+1
    ora TEMP1    ; only zero if both are zero
    beq PUSHFALSE
    jmp PUSHTRUE
;
; ( -- $FFFF )
def_word "TRUE", "istrue", 0
PUSHTRUE:
    lda #$FF
    sta TEMP1
    jmp keeps         ; keeps - sta TEMP1+1, then jsr spush_0 and 'next'
;
; ( -- $0000 )
def_word "FALSE", "isfalse", 0
PUSHFALSE:
    stz TEMP1
    stz TEMP1+1
    jmp this
;---------------------------------------------------------------------
; ( -- state ) pushes addr of status word on stack
;    changed name to x@ cuz confusion with other DS words
;
def_word "x@", "state", 0
    lda #<STATUS
    sta TEMP1
    lda #>STATUS
    jmp keeps   ; pushes addr of status word on stack?  keeps includes sta TEMP+1 etc.

.ifdef DEBUG
;------------------------ADDED for HyForth debugging-------
; ( -- ) toggle debug flag
def_word "debug", "debug", 0
    lda DFLAG
    eor #$FF
    sta DFLAG
    jmp next
.endif
;
;------------------------END of primitives.s
;