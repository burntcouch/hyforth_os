;------------ CRITICAL CORE PRIMITIVES (AGSB and PGS) ----------------
;   (the 'primitive' primitives)
;  ----------------------------------------------------------- 
;  @ ! lit [ ] , : :$ ; ;$ I .R .S xR xS ?R ?S
;  dup swap rot over drop 0-9 $0-$F %0 %1 < > <= >= = <>
;  0= bool FALSE TRUE not neg and or nand xor 
;  + - key emit ord . .be spc cr c! c@ words w&
;  in> >in rp sp x@ pp mp r> r> back here last
;  bye exec reset abort debug
;  -----------------------------------------------------------
;
;   COMPILE (:), FINISH (;), FETCH (@), STORE (!)
;      including:  keeps, this, next, finish
;       ...and other stuff.
;
;---------------------------------------------------------------------
;
; ( -- ) ae exit forth
def_word "bye", "bye", 0
    jsr WWARMSTART_ADDR
    jmp MON_START               ; jump to WOZMON
WWARMSTART_ADDR:
    lda #'F'
    jsr WRITE_CHAR
    lda #'W'
    jsr WRITE_CHAR
    lda #'-'
    jsr WRITE_CHAR
    lda #>F_warm
    jsr WRITE_BYTE
    lda #<F_warm
    jsr WRITE_BYTE
    rts
;
; ( -- ) ae abort
def_word "abort", "abort_", 0
    jmp abort
;
; ( -- ) resets buffer to INBUF
def_word "reset", "reset_", 0
    jmp reset
;
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0
    jsr spull_0
    jmp (TEMP1)        ; assumes an address on top of DS

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ":$", "docode", 0
    jmp (INSTPTR)                 ;  DOCODE (thus the ':')

;---------------------------------------------------------------------
; ( -- ) execute a jump to next
def_word ";$", "donext", 0        ;  'next' (thus the ';')
    jmp next
;---------------------------------------------------------------------
;         set and clear flags bits and delimiter
;
def_word "fb!", "fbitset", 0
    jsr spull_0
    ldx TEMP1
    jsr FLAGSET          ; kills X, but uses NO TEMP vars
    jmp next
;
def_word "f@", "flagget", 0
    lda FLAGS
    sta TEMP1
    stz TEMP1+1
    jmp this
;
def_word "?f", "whatsf", 0
    stz TEMP2
    stz TEMP2+1
    jsr spull_0
    lda TEMP1
    and #$07
    tax
    inx
    lda #0
    sec
WHATSFLP:
    rol
    dex
    bne WHATSFLP
    and FLAGS
    beq WHATSCLR
WHATSSET:
    dec TEMP2
    dec TEMP2+1
WHATSCLR:
    jsr spush_1
    jmp next
;    
;   
def_word "del@", "delimget", 0
    lda #DELIM
    sta TEMP1
    stz TEMP1+1
    jmp this
;
def_word "del!", "delimst", 0
    jsr spull_0
    lda TEMP1
    sta DELIM
    jmp next
;
def_word "f!", "flagsset", 0
    jsr spull_0
    lda TEMP1
    sta FLAGS
    jmp next
;
; ( w a -- ) ; [a] = w    (w is word, a is an address)
def_word "!", "store", 0
storew:
    jsr spull_1             ; get address, store in TEMP2
    jsr spull_0             ; get data, store in TEMP1
    ldx #TEMP2              ;  [a]
    ldy #TEMP1              ;   w
    jsr copyinto            ; copy TEMP2 stuff to addr in TEMP1 (opposite of @)..
    jmp next                ;            ...(see below)
;
;--------------------------------------------FETCH--------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0      ; replace addr of data on top of DS, with data pointed to
fetchw:
    jsr spull_0             ; get addr from DS
    ldx #TEMP1
    ldy #TEMP2
    jsr copyfrom            ; copies data from [TEMP1] => TEMP2
;---------------------------------------------------------------------
;            NEXT entry point for many AGSB primitives, and
;            almost all other hard-coded words.
;---------------------------------------------------------------------
                            ; in fall through, this copies TEMP2 (in y) to TEMP1,
                            ; overwriting the address that was pulled from the stack.
                            ;
                            ; in theory, one could load y with any TEMPx and
                            ; call jump to 'copys' to finish off to 'next'.
                            ; in PRACTICE, AGSB didn't reuse this much.
                            ;
copys:                      ; copy from cell at y (zp) to TEMP1
    lda 0, y
    sta TEMP1
    lda 1, y
                            ; 'keeps' is a shortcut to the 'second half' of the
                            ; (sta TEMP1) routine to return results; to push another
                            ; variable on the stack, do it explicitly.
                            ;
                            ; 'this' assumes 'keeps' has already been done.
                            ;  Almost every hard-coded word uses keeps, this, or next
                            ;  to end a word; 'next' ends with 'exit' of course.
                            ; 
keeps:                      ; saves bytes since have to get here anyway
    sta TEMP1+1
this:                       ; same as above
    jsr spush_0             ; then push back on stack
    jmp next
;
;-----------------------IMMEDIATE, '[', ']', ','-----------------------
def_word "I", "Imm", 0
wimm:                        ; jmp here if proccessing a compiled
    lda LASTHEAP+1           ;   word that needs to run 'immediate'.
    sta TEMP9+1
    lda LASTHEAP             ; get addr of 'last' compiled word, copy to TEMP4, add 2
    clc
    adc #2                   ; ..to find where length byte is...
    sta TEMP9
    bcc IMMSKIP
    inc TEMP9+1
IMMSKIP:
    ldy #0
    lda (TEMP9),y
    ora #$80                 ; ...set bit 7 and store
    sta (TEMP9),y
    jmp next
;
def_word "[", "leftbrack", FLAG_IMM       ; switch to 'interpret'
    stz STATUS
    jmp next
;
def_word "]", "rtbrack", 0               ; switch back to 'compile'
    lda #1
    sta STATUS
    jmp next
;
;
                                         ; NOTE: 'lit' or similar will have pushed a value
                                         ; or address onto stack; 'comma' stores it inline in word
                                         ;
def_word ",", "xcomma", 0                ; pull data from top of stack, store at 'here' (NEXTHEAP)
                                         ; , increment 'here' to point to next cell.
    jsr spull_0                          ;
    ldy #0                               ; 
    lda TEMP1
    sta (NEXTHEAP),y                     ; POP DS TO TEMP1, [here] = TEMP1
    iny
    lda TEMP1+1
    sta (NEXTHEAP),y
    ldx #NEXTHEAP                        ; here += 2
    lda #2
    jsr addwx
    jmp next

;--------------------------------------------SEMIS-----------------
def_word ";", "semis",  FLAG_IMM
    lda BACKHEAP
    sta LASTHEAP                ; bring back BACKHEAP to LASTHEAP
    lda BACKHEAP + 1
    sta LASTHEAP + 1

    stz STATUS                  ; set status to 'interpret' (presumably from 'compile')

finish:                         ; compiled words must end with exit
    lda #<exit
    sta WORKREG
    lda #>exit
    sta WORKREG + 1
    jsr wcomma                  ; change NEXTHEAP to point to addr of 'exit',
                                ; and make sure is last entry in code table for word...
                                ; as all good Forth compiled words should do.
    jmp next
;
;
;------------------------------------------COMPILE------------------
def_word ":", "colon", 0
    lda NEXTHEAP
    sta BACKHEAP                ; backup NEXTHEAP to BACKHEAP
    lda NEXTHEAP + 1
    sta BACKHEAP + 1

    lda #1                      ; set status to 'compile'
    sta STATUS

COMPHEADER:
; copy LASTHEAP into (NEXTHEAP)
    ldy #LASTHEAP
    jsr comma                    ; change NEXTHEAP to point to LASTHEAP  ('here' <= 'last')
    jsr token                    ; get first token, the name of new word
    ldy #0                       ; copy it to heap: length and name
                                 ; code field comes with later proc
COMPLOOP:
    lda (NXTTOK), y
    cmp #$20
    beq COMPEND
    cpy #0                       ; if this is the length field...
    bne COMCOPY
    ora #$40                     ; set bit six for 'compiled' word
COMCOPY:
    sta (NEXTHEAP), y
    iny
    bne COMPLOOP
COMPEND:
    tya                          ; and update NEXTHEAP  :  'here' incremented by length
    ldx #(NEXTHEAP)
    jsr addwx                   ; 'here' now at CFA

;~~~~~~~~ all done....
    jmp next                     ; and then see below; compiled word will continue until ';'
;
;  That's the basic basics, now for the rest of the core...
;
;----------------------------------------------------------------------
;
;   DS and RT manipulation words
;



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
;
; ( -- ) is data stack empty?
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
    jmp this

; ( -- ) is return stack empty?
def_word "?R", "rtp", 0
    stz TEMP1+1
    stz TEMP1
    lda RTPTR
    cmp #RTEND
    bne EMPEND
    jmp EMPCONT
;
; (a a a ... -- )    clear DS
def_word "xS", "xS", 0
    lda #DSEND
    sta DSPTR
    lda #0
    ldy #0
    sta (DSPTR),y
    iny
    sta (DSPTR),y
    jmp next
;
; (RT:a a a ... -- RT: )    clear RT
def_word "xR", "xR", 0
    lda #RTEND
    sta RTPTR
    lda #0
    ldy #0
    sta (RTPTR),y
    iny
    sta (RTPTR),y
    jmp next
;
;
;----------------------LOGIC FUNCTIONS--------------------------
; ( w1 w2 -- w1 AND w2 )
def_word "and", "xand", 0   ; had to use 'xand' cuz 'and' used for something important...
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    and TEMP1
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    jmp keeps  ; uncomment if carry could be set
;
; ( w1 w2 -- w1 OR w2 )
def_word "or", "or", 0
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    ora TEMP1
    sta TEMP1
    lda TEMP2 + 1
    ora TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
;
; ( w1 w2 -- w1 XOR w2 )
def_word "xor", "xor", 0
    jsr spull_1             ;load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    eor TEMP1
    sta TEMP1
    lda TEMP2 + 1
    eor TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
;
; ( w1 -- NOT w1 )
def_word "not", "not", 0
    jsr spull_0             ; load TEMP1 from stack
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    jmp keeps  ; sta TEMP1+1 included!
;
; ( w1 -- NEG w1 )  1's complement
def_word "neg", "neg", 0
    jsr spull_0             ; load TEMP1 from stack
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    inc TEMP1
    bne NEGENDS
    inc TEMP1+1
NEGENDS:
    jmp this
;
;
;    printing stuff off the stack
;
; ( u -- u ) print top of DS in hexadecimal in MSB:LSB (little-endian) form
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
; ( u -- u ) print top of DS in hexadecimal in LSB:MSB (big-endian) form
def_word ".be", "bedot", 0
    lda #$20
    jsr WRITE_CHAR
    jsr spull_0
    lda TEMP1+1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    jmp next     ; '.' now consumes top of DS
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
;  PGS core extras
;
;----------------------CLASSIC FORTH-------------------------
; (a b -- b a)
def_word "swap", "swap", 0
    jsr spull_0          ; pull top
    lda TEMP1
    sta TEMP2
    lda TEMP1+1
    sta TEMP2+1
    jsr spull_0          ; pull next, will end up in TEMP1
    jsr spush_1          ; push TEMP2 back on now
    jmp this            ; includes jsr spush_0
;
;  (a -- a a)
def_word "dup", "dup", 0
    jsr spull_0          ; pull top to TEMP1
    jsr spush_0          ; and then push back
    jmp this            ; includes jsr spush_0 for second time
;
; (a -- )
def_word "drop", "drop", 0
    jsr spull_0          ; pull top, ends up in TEMP1 but...
    jmp next
;



; (a b c -- b c a)
def_word "rot", "rot", 0
    jsr spull_0
    jsr spull_1
    jsr spull_2
    jsr spush_1
    jsr spush_0
    jsr spush_2
    jmp next
;
; (a b -- a b a)
def_word "over", "over", 0
    jsr spull_0
    jsr spull_1
    jsr spush_1
    jsr spush_0
    jsr spush_1
    jmp next
;
; (a b -- b)
def_word "nip", "nip", 0
    jsr spull_0
    jsr spull_1
    jmp this
;
; (a b -- b a b)
def_word "tuck", "tuck", 0
    jsr spull_0
    jsr spull_1
    jsr spush_0
    jsr spush_1
    jmp this
;
;----------------------NUMERALS----------------------------------------   
;
.ifdef SINGLE
; ( -- n ) numeral 1
def_word "$1", "onehex", 0
    jmp ONEHEX
def_word "1", "one", 0
ONEHEX:
    lda #1
DOWITHONE:
    sta TEMP1
    stz TEMP1+1
    jmp this

; ( -- n ) numeral 2
def_word "$2", "twohex", 0
    lda #2
    jmp DOWITHONE
def_word "2", "two", 0
    lda #2
    jmp DOWITHONE

; ( -- n ) numeral 3
def_word "$3", "threehex", 0
    lda #3
    jmp DOWITHONE
def_word "3", "three", 0
    lda #3
    jmp DOWITHONE

; ( -- n ) numeral 4
def_word "$4", "fourhex", 0
    lda #4
    jmp DOWITHONE
def_word "4", "four", 0
    lda #4
    jmp DOWITHONE

; ( -- n ) numeral 5
def_word "$5", "fivehex", 0
    lda #5
    jmp DOWITHONE
def_word "5", "five", 0
    lda #5
    jmp DOWITHONE

; ( -- n ) numeral 6
def_word "$6", "sixhex", 0
    lda #6
    jmp DOWITHONE
def_word "6", "six", 0
    lda #6
    jmp DOWITHONE

; ( -- n ) numeral 7
def_word "$7", "sevenhex", 0
    lda #7
    jmp DOWITHONE
def_word "7", "seven", 0
    lda #7
    jmp DOWITHONE

; ( -- n ) numeral 8
def_word "$8", "eighthex", 0
    lda #8
    jmp DOWITHONE
def_word "8", "eight", 0
    lda #8
    jmp DOWITHONE

; ( -- n ) numeral 9
def_word "$9", "ninehex", 0
    lda #9
    jmp DOWITHONE
def_word "9", "nine", 0
    lda #9
    jmp DOWITHONE

; ( -- n ) numeral -1
def_word "-1", "negone", 0
    lda #$FF
    sta TEMP1
DOWITHNEG:
    jmp keeps

; ( -- n ) numeral 0
def_word "$0", "zerohex", 0
    jmp DOITZERO
def_word "0", "zero", 0
DOITZERO:
    stz TEMP1
    stz TEMP1+1
    jmp this

; ( -- n ) numeral -2
def_word "-2", "negtwo", 0
    lda #$FE
    sta TEMP1
    jmp DOWITHNEG

; ( -- n ) numeral -3
def_word "-3", "negthree", 0
    lda #$FD
    sta TEMP1
    jmp DOWITHNEG

def_word "-4", "negfour", 0
; ( -- n ) numeral -4
    lda #$FC
    sta TEMP1
    jmp DOWITHNEG

def_word "-5", "negfive", 0
; ( -- n ) numeral -5
    lda #$FB
    sta TEMP1
    jmp DOWITHNEG

def_word "-6", "negsix", 0
; ( -- n ) numeral -6
    lda #$FA
    sta TEMP1
    jmp DOWITHNEG

def_word "-7", "negseven", 0
; ( -- n ) numeral -7
    lda #$F9
    sta TEMP1
    jmp DOWITHNEG

def_word "-8", "negeight", 0
; ( -- n ) numeral -8
    lda #$F8
    sta TEMP1
    jmp DOWITHNEG

def_word "-9", "negnine", 0
; ( -- n ) numeral -9
    lda #$F7
    sta TEMP1
    jmp DOWITHNEG

; ( -- n ) numeral A
def_word "$A", "zeroa", 0
    lda #10
    jmp DOWITHONE

; ( -- n ) numeral B
def_word "$B", "zerob", 0
    lda #11
    jmp DOWITHONE

; ( -- n ) numeral C
def_word "$C", "zeroc", 0
    lda #12
    jmp DOWITHONE

; ( -- n ) numeral D
def_word "$D", "zerod", 0
    lda #13
    jmp DOWITHONE

; ( -- n ) numeral E
def_word "$E", "zeroe", 0
    lda #14
    jmp DOWITHONE

; ( -- n ) numeral F
def_word "$F", "zerof", 0
    lda #15
    jmp DOWITHONE

; ( -- n ) numeral %0
def_word "%0", "binary0", 0
    lda #0
    jmp DOWITHONE

; ( -- n ) numeral %1
def_word "%1", "binary1", 0
    lda #1
    jmp DOWITHONE
;
;   end of numerics
;
.endif   ; SINGLE
;
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
;
;
;---------------------------------------------------------------------------
;      FORTH INTERNALS
;
def_word ">in", "inptr", 0                  ; CURBUF - pointer into INBUF (TIB)
    lda #CURBUF
REGIN:
    sta TEMP1
    stz TEMP1+1
    jmp this
;
def_word "last", "last", 0                   ; LASTHEAP addr onto stack
    lda #LASTHEAP
    bra REGIN
;
def_word "here", "here", 0                   ; NEXTHEAP addr onto stack
    lda #NEXTHEAP
    bra REGIN
;
def_word "back", "back", 0                   ; backup of NEXTHEAP addr onto stack
    lda #BACKHEAP
    bra REGIN
;
def_word "sp", "sp", 0                       ; DSPTR pointer addr onto stack
    lda #DSPTR
    bra REGIN
;
def_word "rp", "rp", 0                       ; RTPTR pointer addr onto stack
    lda #RTPTR
    bra REGIN
;
def_word "mp", "mp", 0                       ; MEMPTR addr on stack
    lda #MEMPTR
    bra REGIN
;
def_word "mem@", "memptr", 0               ; memory area pointer target on stack ( 'mp @')
    lda MEMPTR
    sta TEMP1
    lda MEMPTR+1
    jmp keeps
;
def_word "pp", "padptr", 0
    lda #PADPTR
    bra REGIN
;
;
def_word ">r", "s_to_r", 0
    jsr spull_0   ; put top of stack in TEMP1
    ldy #TEMP1
    jsr rpush
    jmp next
;                             ': r> rp @ @ rp @ 2 + rp ! rp @ @ swap rp @ ! ;'
def_word "r>", "r_to_s", 0
    ldy #TEMP1
    jsr rpull   
    jmp this                ; and push on DS stack 
;
; ( -- state ) pushes addr of status word on stack
;    changed name to x@ cuz confusion with other DS words
;
def_word "x@", "state", 0
    lda #<STATUS
    sta TEMP1
    lda #>STATUS
    jmp keeps   ; pushes addr of status word on stack?  keeps includes sta TEMP+1 etc.

;
;         Get next byte off INBUF, advance CURBUF
def_word "in>", "intib", 0
    stz TEMP1+1
    ldy #0
    lda (CURBUF),y
    sta TEMP1
    jsr spush_0
    inc CURBUF
    jmp next
;
;----------------------OTHER EXTRAS--------------------------------------
def_word "cr", "crlf", 0
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    jmp next
;
; ( a -- >[a])   -  : c@ @ ffh and ;  - load a byte
def_word "c@", "c_from", 0
    jsr spull_1
    ldy #0
    lda (TEMP2),y
    sta TEMP1
    stz TEMP1+1
    jmp this
;
; (0b a -- )  0b -> [a]  --- store a byte
def_word "c!", "c_to", 0
    jsr spull_1   ; load address
    jsr spull_0   ; load byte to store (TEMP1 lsb only)
    ldy #0
    lda TEMP1    ; ignore upper byte
    sta (TEMP2),y
    jmp next
;
; ( -- 2)   - : cells lit [ 2 , ] ;
def_word "cells", "cells", 0
    lda #2
    sta TEMP1
    stz TEMP1+1
    jmp this

; ( -- 32)   - : bl lit [ 1 2* 2* 2* 2* 2* , ] ;
def_word "spc", "spc", 0
    lda #$20
    sta TEMP1
    stz TEMP1+1
    jmp this
;
;----------------------------------------------
; (? -- ?)      -  LIT -
;                - ': lit rp @ @ dup 2 + rp @ ! @ ;'
;                     OR  - [IP] PUSH DS, IP += 2, next
;
;    This is how you make room inside a word to store data the
; word will want later.
;
;                    yep, it's this easy...
def_word "lit", "literal", 0
    ldy #0
    lda (INSTPTR),y
    sta TEMP1
    iny
    lda (INSTPTR),y
    sta TEMP1+1
    jsr spush_0   ; [IP] PUSH DS
    ldx #INSTPTR  ; IP += 2
    lda #2
    jsr addwx
    jmp next
;
;
; (n1 n2 -- n1<>n2)  not equal
def_word "<>", "ne", 0
    jsr spull_1
    jsr spull_0
CMPLINK:
    lda TEMP1
    cmp TEMP2
    bne IEQTRUE
    lda TEMP1+1
    cmp TEMP2+1
    beq IEQFALSE
    jmp PUSHTRUE
;
; (n1 n2 -- n1=n2)  equal
def_word "=", "eq", 0
    jsr spull_1
    jsr spull_0
    lda TEMP1
    cmp TEMP2
    bne IEQFALSE
    lda TEMP1+1
    cmp TEMP2+1
    bne IEQFALSE
    jmp PUSHTRUE
;
; (n1 -- n1=0)  equal to zero
def_word "0=", "eqz", 0
    jsr spull_0
    lda TEMP1
    ora TEMP1+1       ; only zero if both zero
    bne IEQFALSE
    jmp PUSHTRUE
;

; (n1 n2 -- n1>n2)  more than
def_word ">", "gt", 0
    jsr spull_1
    jsr spull_0
    lda TEMP1+1
    cmp TEMP2+1
    bcc IEQFALSE
    bne IEQTRUE
    lda TEMP1
    cmp TEMP2
    bcc IEQFALSE
    beq IEQFALSE
IEQTRUE:
    jmp PUSHTRUE
IEQFALSE:
    jmp PUSHFALSE

;
; (n1 n2 == n1<=n2) less than or equal
def_word "<=", "lte", 0
    jsr spull_1
    jsr spull_0
    lda TEMP1+1
    cmp TEMP2+1
    bcc IEQTRUE
    bne IEQFALSE
    lda TEMP1
    cmp TEMP2
    bcc IEQTRUE
    beq IEQTRUE
    jmp PUSHFALSE

;
; (n1 n2 == n1>=n2) greater than or equal
def_word ">=", "gte", 0
    jsr spull_1
    jsr spull_0
GTELINK:
    lda TEMP1+1
    cmp TEMP2+1
    bcc IEQFALSE
    bne IEQTRUE
    lda TEMP1
    cmp TEMP2
    bcc IEQFALSE
    jmp PUSHTRUE
;
; (n1 n2 == n1<n2) less than
def_word "<", "lt", 0
    jsr spull_1
    jsr spull_0
    lda TEMP1+1
    cmp TEMP2+1
    bcc IEQTRUE
    bne IEQFALSE
    lda TEMP1
    cmp TEMP2
    bcc IEQTRUE
    jmp PUSHFALSE
;
;
;      
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
; so this will be used like 'w& words' which will return CFA of 'words'
;  equivalent of Forth-79 word 'tick' (single quote)
;
def_word "w&", "wfind", 0
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
;
;
;  end of core.s
;