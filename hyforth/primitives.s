;
; primitives.s
;
;
;  ------------------------------------------------------------
;  var cons malloc mlen mem@ pad@ pad! xpad
;  hx2d dump .sz .rsz .psz .sn
;  * / */ max min << >> cbit sbit tbit
;
;
; ------------------------------------------------------
;       MEMORY management:  VAR, CONS, ARRAY, etc.
;
;---  stubs of malloc and mlen
;
; ( bytes type -- staddr )
def_word "malloc", "malloc", 0
    jsr spull_1       ; type ( word ($00), char ($01), words ($02), bytes ($03), sz ($04) ..)
    jsr spull_0       ; # bytes
    jsr MALLOC        ; will return address in TEMP1
    jmp this       ; push ptr address to new record on stack

;
; ( maddr -- len )
def_word "mlen", "mlen", 0
    jsr spull_1
    jsr MEMLEN   ; returns length in TEMP1, maddr in TEMP3
    jmp this
;
;
;         HF version of 'variable'
;
; ( -- )
def_word "var", "var", 0
    lda NEXTHEAP
    sta BACKHEAP                ; backup NEXTHEAP to BACKHEAP
    lda NEXTHEAP + 1
    sta BACKHEAP + 1

VCHEAD:
; copy LASTHEAP into (NEXTHEAP)
    ldy #LASTHEAP
    jsr comma                    ; change NEXTHEAP to point to LASTHEAP  ('here' <= 'last')
    jsr token                    ; get first token, the name of new word
    ldy #0                       ; copy it to heap: length and name
                                 ; code field comes with later proc
VCLOOP:
    lda (NXTTOK), y
    cmp #$20                   ; copy in length and name
    beq VCMID
VCCOPY:
    sta (NEXTHEAP), y
    iny
    bne VCLOOP
VCMID:
    tya                          ; and update NEXTHEAP  :  'here' incremented by length
    ldx #(NEXTHEAP)
    jsr addwx                   ; 'here' now at CFA


    ldx #(VCEND0-VCCODE)        ; calc offset
    ldy #0
VCLOOP2:
    lda VCCODE, y
    sta (NEXTHEAP),y
    iny
    dex
    bne VCLOOP2
    phy                        ; save for later
    lda NEXTHEAP+1
    sta TEMP1+1
    lda NEXTHEAP
    clc
    adc #15                     ; calc addresses for indirect data
    sta TEMP1                   ; read.
    bcc VCSKIP00
    inc TEMP1+1
VCSKIP00:                      ; update addresses for lda's
    ldy #3                     ; <VCDATA
    lda TEMP1
    sta (NEXTHEAP),y
    ldy #7                     ; >VCDATA
    lda TEMP1+1
    sta (NEXTHEAP),y
    lda #0
    ldy #15
    sta (NEXTHEAP),y          ; store zero in data word
    iny
    sta (NEXTHEAP),y

    pla                        ; to update
    ldx #NEXTHEAP
    jsr addwx
VCFINISH:
    lda BACKHEAP
    sta LASTHEAP                ; bring back BACKHEAP to LASTHEAP
    lda BACKHEAP + 1
    sta LASTHEAP + 1
    jmp this
;
;    VCCODE - 'dovar' - copied into a var word ( 'DOES>' )
;
VCCODE:         ; NEXTHEAP ('here') should start here
    bit #00
    lda #<VCDATA               ; <NEXTHEAP+15   (at 'here' +3)
    sta TEMP1
    lda #>VCDATA               ; >NEXTHEAP+15   (at 'here' +7)
    sta TEMP1+1
    jsr spush_0
    bra VCEND                  ; bra 2
VCDATA:
   .word 0
VCEND:
    jmp next
VCEND0:
;
;  HF version of 'constant'
;
; ( cv -- )
def_word "cons", "cons", 0
    lda NEXTHEAP
    sta BACKHEAP                ; backup NEXTHEAP to BACKHEAP
    lda NEXTHEAP + 1
    sta BACKHEAP + 1
    ldy #TEMP8
    jsr spull

;    jsr DUMPREG

CCHEAD:
; copy LASTHEAP into (NEXTHEAP)
    ldy #LASTHEAP
    jsr comma                    ; change NEXTHEAP to point to LASTHEAP  ('here' <= 'last')
    jsr token                    ; get first token, the name of new word
    ldy #0                       ; copy it to heap: length and name
                                 ; code field comes with later proc
CCLOOP0:
    lda (NXTTOK), y
    cmp #$20
    beq CCMID
CCCOPY:
    sta (NEXTHEAP), y
    iny
    bne CCLOOP0
CCMID:
    tya                          ; and update NEXTHEAP  :  'here' incremented by length
    ldx #(NEXTHEAP)
    jsr addwx                   ; 'here' now at CFA
                                ; copy in code from CCCODE ('docon')
    ldx #(CCEND0-CCCODE)        ; calc offset
    ldy #0
CCLOOP:
    lda CCCODE, y
    sta (NEXTHEAP),y
    iny
    dex
    bne CCLOOP
    phy
    lda NEXTHEAP+1
    sta TEMP1+1
    lda NEXTHEAP
    clc
    adc #17                     ; calc addresses for indirect data
    sta TEMP1                   ; read.
    bcc CCSKIP00
    inc TEMP1+1
CCSKIP00:
    ldy #3                     ; offset to lda CCDATA
    lda TEMP1
    sta (NEXTHEAP),y
    iny
    lda TEMP1+1
    sta (NEXTHEAP),y
    inc TEMP1
    bne CCSKIP01
    inc TEMP1+1
CCSKIP01:
    ldy #8                     ; offset to lda CCDATA+1
    lda TEMP1
    sta (NEXTHEAP),y
    iny
    lda TEMP1+1
    sta (NEXTHEAP),y
    lda TEMP8                  ; store constant val LSB
    ldy #17
    sta (NEXTHEAP),y
    lda TEMP8+1                ; store constant val MSB
    iny
    sta (NEXTHEAP),y
             ; pull back offset from above
    pla                        ; update NEXTHEAP
    ldx #NEXTHEAP
    jsr addwx
CCFINISH:
    lda BACKHEAP
    sta LASTHEAP                ; bring back BACKHEAP to LASTHEAP
    lda BACKHEAP + 1
    sta LASTHEAP + 1

    ldy #TEMP8
    jsr spush
    jmp next
;
;   cons copies this in and 'customizes it' by
;   plugging in corrected address for CCDATA
;
;  'DOCONS'
CCCODE:
    bit #00
    lda CCDATA
    sta TEMP1
    lda CCDATA+1
    sta TEMP1+1
    jsr spush_0
    bra CCEND                   ; bra 2
CCDATA:
    .word 0                        ; 0 0
CCEND:
    jmp next
CCEND0:
;
;
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
;
;-------------------------------------------
;
; ( hex -- paddr )
;  converts a word from hex to decimal, puts on PAD, returns address
;
def_word "hx2d", "hx2d", 0
    ldy #Z_MATH2
    jsr spull
    jsr HEX2DEC
    jmp next
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
;
; (addr -- )  -------  print sz string using new allocated RAM space
;
def_word ".rsz", "rszdot", 0
    jsr spull_1
    ldy #0
    jmp SZLOOP
    
def_word ".psz", "pszdot", 0
    jsr spull_1
    jmp PADSZ

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
PADSZ:             ; print zero term'd string at TEMP2, +3
    ldy #3
SZLOOP:            ; print zero term'd string at TEMP2 (make sure to zero Y first!)
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
;
;--------------------------------------------------------------------
;   PAD words
;                
;              push pad pointer val on stack
def_word "pad@", "padfetch"
    lda PADPTR
    sta TEMP1
    lda PADPTR+1
    jmp keeps
;
;              clear pad area
def_word "xpad", "padclr", 0
    jsr PADINIT
    jmp next
;
;              store zero term'd string to pad, return address
; (szaddr - paddr)
def_word "pad!", "padstore", 0  
    jsr CPYPAD
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
;
;
; (u1 u2 -- ux um)  min
; (u1 u2 -- um ux)  max
def_word "min", "min16", 0
    jsr spull_1
    jsr spull_0
MININ16:
    lda TEMP1+1
    cmp TEMP2+1
    bcc MINSWAP
    lda TEMP1
    cmp TEMP2
    bcc MINSWAP
    jmp MINDONE
MINSWAP:
    jsr spush_1
    jmp this
MINDONE:
    jsr spush_0
    jsr spush_1
    jmp next

def_word "max", "max16", 0
    jsr spull_1
    jsr spull_0
    lda TEMP1+1
    cmp TEMP2+1
    bcc MINDONE
    lda TEMP1
    cmp TEMP2
    bcc MINDONE
    jmp MINSWAP

;
; (ux um -- rh rl)      16x16 multiply, result in reverse order
; faster if Z_MATH2 (um) is smaller of two.  Need a MIN/MAX swap routine!
;
def_word "*", "mult16", 0
    ldy #Z_MATH2
    jsr spull
    ldy #Z_MATH1
    jsr spull
    lda Z_MATH1            ; handle zeros  3/22 1320
    ora Z_MATH1+1
    beq m16zero          ; if either is 0-0, can skip to end
    lda Z_MATH2
    ora Z_MATH2+1
    beq m16zero          ; Z_MATH2 is zero?  same deal.
    jsr MULT16
    bra m16push
m16zero:
    stz Z_MATH1
    stz Z_MATH1+1
    stz Z_MATH3
    stz Z_MATH3+1
m16push:
    ldy #Z_MATH3
    jsr spush           ; MSbyte
    ldy #Z_MATH1
    jsr spush           ; push LSbyte in Z_MATH1 on top
    jmp next

;
; (ux um -- r m)      16x16 divide, result + MOD
;
def_word "/", "div16", 0
    ldy #Z_MATH2
    jsr spull
    ldy #Z_MATH1
    jsr spull
    lda Z_MATH1            ; handle zeros  3/22 1320
    ora Z_MATH1+1
    beq d16zero         ; shortcut!
    lda Z_MATH2
    bne d16skip0
    ora Z_MATH2+1
    bne d16skip1
    jmp div0err                     ; divide by zero error
d16skip0:
    cmp #1
    bne d16skip1
    lda Z_MATH2+1
    bne d16skip1
    bra d16rzero                   ; dividing by 1, just return Z_MATH1
d16skip1:
    jsr DIV16                      ; results Z_MATH2, remainder Z_MATH3
    jmp d16done
d16zero:
    stz Z_MATH1
    stz Z_MATH1+1
d16rzero:
    stz Z_MATH3
    stz Z_MATH3+1
d16done:
    ldy #Z_MATH3
    jsr spush        ; remainder first
    ldy #Z_MATH1
    jsr spush        ; result on top
    jmp next
;
;                      divide by zero error
div0err:                      ; pop jsr off stack, throw error
    lda #ERR_DIV0
    sta ERRFLAG
    jmp errrtn
;
;
; (u1 u2 ud -- rl rh m)      16x16/16 mult-divide, result + MOD
;
def_word "*/", "mdiv32", 0
    ldy #Z_MATH4           ; so we can use Z_MATH3 below
    jsr spull              ; divisor
    ldy #Z_MATH1
    jsr spull              ; mult 1
    ldy #Z_MATH2
    jsr spull              ; mult 2
    ;
    lda Z_MATH1            ; handle zeros  3/22 1320
    ora Z_MATH1+1
    beq d32zero         ; shortcut!
    lda Z_MATH2
    ora Z_MATH2+1
    beq d32zero         ; shortcut!
    lda Z_MATH4
    bne d32skip0
    ora Z_MATH4+1
    bne d32skip1
    jmp div0err                     ; divide by zero error
d32skip0:
    cmp #1
    bne d32skip1
    lda Z_MATH4+1
    bne d32skip1
    bra d32rzero                   ; dividing by 1, just return Z_MATH1
d32skip1:
    jsr MULT16                     ; results Z_MATH3/Z_MATH1
    lda Z_MATH3                      ; do-si-do
    sta Z_MATH2
    lda Z_MATH3+1
    sta Z_MATH2+1
    lda Z_MATH4                      ; move divisor to Z_MATH3
    sta Z_MATH3
    lda Z_MATH4+1
    sta Z_MATH3+1                   
    jsr MDIV32              ; results Z_MATH2/Z_MATH1, remainder Z_MATH4
    jmp d32done
d32zero:
    stz Z_MATH1
    stz Z_MATH1+1
    stz Z_MATH2
    stz Z_MATH2+1
d32rzero:
    stz Z_MATH4
    stz Z_MATH4+1
d32done:
    ldy #Z_MATH4
    jsr spush        ; remainder first
    ldy #Z_MATH2
    jsr spush         ; msb next
    ldy #Z_MATH1
    jsr spush        ; lsb on top
    jmp next
    
;        32 / 16 divide; Z_MATH2-Z_MATH1 / Z_MATH3 #'s - Z_MATH4 is 'overflow'
;        -> Z_MATH2-Z_MATH1 + Z_MATH4 = result + remainder
MDIV32:
    stz Z_MATH4
    stz Z_MATH4+1
    ldx #32
UMDIV32LP:
    rol Z_MATH1
    rol Z_MATH1+1
    rol Z_MATH2
    rol Z_MATH2+1
    rol Z_MATH4
    rol Z_MATH4+1
UMDIV32CHK:
    sec
    lda Z_MATH4
    sbc Z_MATH3
    tay
    lda Z_MATH4+1
    sbc Z_MATH3+1
    bcc UMDIV32CNT
    sty Z_MATH4
    sta Z_MATH4+1
UMDIV32CNT:
    dex
    bne UMDIV32LP
    rol Z_MATH1
    rol Z_MATH1+1
    rol Z_MATH2
    rol Z_MATH2+1
    rts    
;
;
;
;
;
;------------------------END of primitives.s
;