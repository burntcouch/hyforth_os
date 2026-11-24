;
;HyForth 'ADDITIONS'
;
; hywords.s
;
;  -------------------------------------------------------------
;  snip tuck pick nip 2over 2drop 2dup
;  bload cload autoload lib libs free
;  syscall disasm memcpy 
;  memw@ memwn@ wmemn! cmemn! rcmemn!
;  rand rand32 rseed Acol Aclr Ascr
;  ywrite ytest yinit
;  ferc@ fecol! ferow! felin feadd feclr fedit febuf fedisp
;  fa_mo@ fa_ms@
;
;   EXTRA stack manipulation words
;
; (a b -- a b a b)
def_word "2dup", "dup2", 0
    jsr spull_1          ; pull top to TEMP2
    jsr spull_0          ; then TEMP1
    jsr spush_0          ; and then push them back
    jsr spush_1
    jsr spush_0
    jsr spush_1
    jmp next
;
; (a b -- )
def_word "2drop", "drop2", 0
    jsr spull_0
    jsr spull_0
    jmp next
;
; (a b c d -- a b c d a b)
def_word "2over", "over2", 0
    ldy #TEMP9
    jsr spull     ; to TEMP9 'd'
    jsr spull_2  ; TEMP3 'c'
    jsr spull_1  ; TEMP2 'b'
    jsr spull_0  ; TEMP1 'a'
    jsr spush_0  ;  'a'
    jsr spush_1  ;  'b'
    jsr spush_2  ;  'c'
    ldy #TEMP9
    jsr spush    ; 'd'
    jsr spush_0  ;  'a' again
    jsr spush_1  ;  'b' again
    jmp next
;
def_word "pick", "xpick", 0
    jsr spull_0
    lda TEMP1
    asl
    clc
    adc DSPTR
    sta TEMP8
    cmp #DSEND           ; boundary check
    bcs PICKPTRERR
    sta TEMP8
    lda DSPTR+1
    sta TEMP8+1
    ldy #0
    lda (TEMP8),y
    sta TEMP1
    iny
    lda (TEMP8),y
    jmp keeps
    
PICKPTRERR:
    lda #ERR_SPTR
    sta ERRFLAG
    jmp errrtn
;
def_word "snip", "snip", 0
    lda DSPTR
    cmp #DSEND
    beq SNIPERR
    lda DSPTR+1
    sta TEMP2+1
    sta TEMP1+1
    lda #DSEND
    sta TEMP2
    lda #DSEND
    sta TEMP1
SNIPLOOP:
    lda TEMP1
    sec
    sbc #2
    sta TEMP1
    ldy #0
    lda (TEMP1),y
    sta (TEMP2),y
    iny
    lda (TEMP1),y
    sta (TEMP2),y
    lda TEMP1+1
    sta TEMP2+1
    lda TEMP1
    sta TEMP2
    cmp #DSEND
    beq SNIPEND
    bra SNIPLOOP
SNIPEND:
    ldx #DSPTR
    lda #2
    jsr addwx
    jmp next
SNIPERR:
    lda #ERR_SPTR
    sta ERRFLAG
    jmp errrtn
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
    ;                       ; bounds checking?
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
    iny
    lda #'-'
    jsr WRITE_BYTE
    lda (TEMP0),y
    jsr WRITE_BYTE                   ; print bank #
    WCRLF_np
    inx
    beq LIBSEND
    bra LIBSLOOP
LIBSEND:
    rts
    
GETLIBENTRY:               ; get entry pointed to by x
    txa
    asl a
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
;
;-------------------------AUTOLOAD and CLOAD----------------------
CLOADMSG:
   .byte "cload>"
   .byte 0
BLOADMSG:
   .byte "bload:"
   .byte $0D, $0A, 0
;
; ( -- )     autoload a list of scripts
def_word "autoload", "autoload", 0
    jsr spull_0   ; get end of list
    lda TEMP1
    sta TEMP7
    lda TEMP1+1
    sta TEMP7+1
    lda #1
    sta ALFLAG
    jmp next

; (a -- )       load a compile-able script from memory, zero term'd
def_word "cload", "cload", 0
    ;stz ALFLAG        ; clear autoload flag
CLOAD_IN:
    WSEQ_raw CLOADMSG
    jsr spull_0        ; address from stack to TEMP1
CLOAD_ENTER:
  ;  jsr DUMPREG
    ldy #0
    lda #$20
    sta (TIB), y       ; put space at start
CLOAD_LP:
    lda (TEMP1), y
    beq CLOAD_CONT     ; stops at first 0
    jsr WRITE_CHAR     ; echo char out so can see what's being pulled in
    iny                ; yep, skip
    sta (TIB), y
    bra CLOAD_LP
CLOAD_CONT:
    iny
    lda #$20
    sta (TIB),y        ; not sure but won't hurt to add a space
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR     ; print CRLF
    lda #$20
    phy
    ldy #0
    sta (TIB), y       ; start with space
    ply
    sta (TIB), y       ; ends with space
    lda #0             ; mark eol with 0
    iny
    sta (TIB), y
    dey
    sta CURBUF        ; start it
;
    tya                ; calc next address if want to load more
    clc
    adc TEMP1
    sta TEMP1
    bcc CLSKIP
    inc TEMP1+1
CLSKIP:
    jsr spush_0        ; push next addr on stack if wanted
.ifdef DEBUG
    jsr DUMPREG
.endif
    jsr token            ; massage the buffer, oh yeah
    jmp RESFIND           ; works perfectly!
;
;
;  BLOAD  -- see example in 'bload.s'
;
; (a -- )       load native code from memory, double zero term'd
;
def_word "bload", "bload", 0
BLOAD_IN:
    WSEQ_raw BLOADMSG
    jsr spull_0          ; address from stack to TEMP1

BLAGAIN:
    lda NEXTHEAP
    sta BACKHEAP                ; backup NEXTHEAP to BACKHEAP
    lda NEXTHEAP + 1
    sta BACKHEAP + 1

BLHEAD:
    ldy #LASTHEAP
    jsr comma                    ; change NEXTHEAP to point to LASTHEAP  ('here' <= 'last')
    ldy #0                       ; copy it to heap: length and name
                                 ; code field comes with later proc
                                 ;
                                 ; NOTE:  This cannot pull more than 255 bytes including
                                 ;  leading or trailing zeros!
                                 ;
BLZEROSKIP:
    lda (TEMP1), y
    bne BLNSK1                  ; skip any LEADING zeros
    iny
    bra BLZEROSKIP
BLNSK1:
    tya
    ldx #TEMP1
    jsr addwx
    ldy #0
BLNLOOP:
    lda (TEMP1), y
    bne BLCOPY
    iny
    lda (TEMP1), y
    beq BLSKIP0
    dey
    lda #0
    bra BLCOPY
BLSKIP0:
    dey
    dey
    bra BLEND
BLCOPY:
    sta (NEXTHEAP), y
    iny
    bne BLNLOOP
BLEND:
    iny
    tya                          ; and update NEXTHEAP  :  'here' incremented by length
    ldx #NEXTHEAP
    jsr addwx
    iny
    iny
    tya
    ldx #TEMP1
    jsr addwx
BLFINISH:
    lda BACKHEAP
    sta LASTHEAP                ; bring back BACKHEAP to LASTHEAP
    lda BACKHEAP + 1
    sta LASTHEAP + 1
    jsr BLTESTEND
    bcs BLENDEND
    jmp BLAGAIN                  ; next word
;    jsr spush_0                 ; push next/last address?
BLENDEND:
    jmp next

BLTESTEND:
    phy
    ldy #0
    lda (TEMP1), y
    cmp #'E'
    bne BLNOEND
    iny
    lda (TEMP1), y
    cmp #'N'
    bne BLNOEND
    iny
    lda (TEMP1), y
    cmp #'D'
    bne BLNOEND
    sec
    bcs BLTEND
BLNOEND:
    clc
BLTEND:
    ply
    rts
;
;
;
; ( -- )   ANSI clear screen
.ifdef ANSIOK
def_word "Acls", "Acls", 0
    jsr ANSICLS
    jmp next
;
; (c r -- )      ANSI screen position ESC[<r>;<c>f
def_word "Ascr", "Ascr", 0
    jsr spull_0
    ldx TEMP1
    jsr DEC2ASCII         ; digits end up in Z_MATH3
    lda Z_MATH3
    sta Z_ANSI1
    lda Z_MATH3+1
    sta Z_ANSI1+1        
    jsr spull_0
    ldx TEMP1
    jsr DEC2ASCII         ; digits end up in Z_MATH3
    lda Z_MATH3
    sta Z_ANSI2
    lda Z_MATH3+1
    sta Z_ANSI2+1      
    jsr ANSISCR
    jmp next
;
; (c -- )      ANSI attributes ESC[<c>m
def_word "Acol", "Acol", 0
    jsr spull_0
    ldx TEMP1
    jsr DEC2ASCII         ; digits end up in TEMP3
    lda Z_MATH3
    sta Z_ANSI1
    lda Z_MATH3+1
    sta Z_ANSI1+1 
    jsr ANSICOL    
    jmp next
.endif   ; ANSIOK
;
;--------------------------RANDOM #'s
; ( s s -- )   random #
def_word "rseed", "rseed", 0
    jsr spull_0
    lda TEMP1
    sta RSEED
    lda TEMP1+1
    sta RSEED+1
    jsr spull_0
    lda TEMP1
    sta RSEED+2
    lda TEMP1+1
    sta RSEED+3
    jmp next
; ( -- r)          16 bit rand -> stack
;
def_word "rand", "rand", 0
    jsr galois32o
    jmp RAND32IN
;
; ( -- r r)          32 bit rand -> stack
def_word "rand32", "rand32", 0
    jsr galois32o
    lda RSEED+2
    sta TEMP1
    lda RSEED+3
    sta TEMP1+1
    jsr spush_0
RAND32IN:
    lda RSEED
    sta TEMP1
    lda RSEED+1
    jmp keeps
;
;------------------------------MEMORY OPERATIONS----------------------------
;
; (as ae ad -- )    copy from $as thru $ae to $ad
def_word "memcpy", "memcpy", 0
    ldy #ZP_TEMP_VEC3
    jsr spull              ; dest addr
    ldy #ZP_TEMP_VEC2
    jsr spull              ; end
    ldy #ZP_TEMP_VEC
    jsr spull              ; start
    lda ZP_TEMP_VEC+1
    cmp ZP_TEMP_VEC2+1
    bcc MEMCPYDOIT
    bne MEMCPYEND
    lda ZP_TEMP_VEC
    cmp ZP_TEMP_VEC2
    bcs MEMCPYEND
MEMCPYDOIT:
    lda #1
    sta supprint
    jsr MEMCPY
    stz supprint
MEMCPYEND:
    jmp next
;
;                   free memory between BACKHEAP and MEMPTR
def_word "free", "free", 0
    lda MEMLAST
    sec
    sbc NEXTHEAP
    sta TEMP1
    lda MEMLAST+1
    sbc NEXTHEAP+1
    jmp keeps
;
; (daddr n -- ) start disassembly from daddr, do it
; $F800 is entry point for DISASM (low/high addr), C=1 for multiple opcodes, X for # of codes
;  ..or, since it's not much fun figuring out why WozMon is picky, use the regular DISASM
;  entry point instead.  simpler, and just shoe-horn address into Z_D_XAM, and run the loop here.
;
def_word "disasm", "disasm", 0
    jsr spull_1    ; # of instructions to print
    jsr spull_0    ; addr
    lda TEMP2
    cmp #$FE
    bcs DISEND
    lda #1           ; and ZP_D_STATE has to be =1 in order to show mnemonics etc
    sta ZP_D_STATE
    lda TEMP1+1
    sta ZP_D_XAM+1   ; gotta write the address here, since WozMon doesn't
    lda TEMP1
    sta ZP_D_XAM
DISLOOP:
     lda ZP_D_XAM+1
     jsr WRITE_BYTE   ; weird shit ensues if I try to do it in Wozmon/DISASM
     lda ZP_D_XAM
     jsr WRITE_BYTE    
     lda #':'
     jsr WRITE_CHAR  
     clc
     jsr DISASM
     WCRLF
     dec TEMP2
     beq DISSKIP
     bra DISLOOP
DISSKIP:     
    lda ZP_D_XAM
    sta TEMP1
    ldy ZP_D_XAM+1
    sty TEMP1+1
    jsr spush_0     ; push last address on stack, in case want to continue
DISEND:
    jmp next

; (jsaddr 0a 0y-- 0x) jump to external code with parms passed via A,Y, result in X
def_word "syscall", "syscall", 0
    jsr spull_2    ; parm to pass to y
    jsr spull_1    ; parm to pass to a
    jsr spull_0    ; addr
    lda TEMP1
    sta SYSCALL+1
    lda TEMP1+1
    sta SYSCALL+2
    ldy TEMP3
    lda TEMP2
    jsr SYSCALL
    jmp next
;
;  below must be in RAM to work
;
SYSCALL:
    jsr SCDUMMY        ; store into SYSCALL+1, +2 to customize jump
    txa                ; returned stuff in X
    beq SCSKIP         ; if returns zero, don't do anything else
    sta TEMP1          ; otherwise...
    stz TEMP1+1
    jsr spush_0        ; push result onto stack
    rts
SCSKIP:
    pla
    pla
    jmp errrtn
SCDUMMY:
    ldx #0
    rts
    
def_word "basic", "basic", 0
    jsr WWARMSTART_ADDR    
    lda #BASBANK               ; switch ROM bank to one with basic in it
    sta $01
    jmp $A000                  ;   start BASIC
;
; -------------- various functions to copy data between memory and stack
;
; ( addr n -- w0 w1 ... w(n-1) )  push n words from memory to stack
;
def_word "memwn@", "memwnget", 0
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
def_word "memw@", "memwget", 0
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
def_word "wmemn!", "wmemstn", 0
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
def_word "cmemn!", "cmemstn", 0
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
def_word "rcmemn!", "rcmemstn", 0
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
;
.ifdef YSOUND
;
;                        word definitions for Yamaha 2151 sound chip
;
def_word "yinit", "yinit", 0
    jsr SOUND_INIT
    jmp next

def_word "ytest", "ytest", 0
    jsr SOUND_TEST
    jmp next

; ( xxaa -- )    send byte(a) to register(x) on yamaha 2151
def_word "ywrite", "ywrite", 0
    jsr spull_0
    ldx TEMP1+1
    lda TEMP1
    jsr YM_WRITE
    bcc YMGOOD
    jmp PUSHFALSE
YMGOOD:
    jmp PUSHTRUE
.endif
;
;
def_word "insz", "insz", 0   ; compare two strings, find smaller in larger
    jsr spull_2    ; TEMP3 has length of small string
    jsr spull_1    ; TEMP2 has addr of string to find
    jsr spull_0    ; TEMP1 has addr of string to search, zero termed
    jsr INSTR      ; returns offset in TEMP2
    jsr spush_1
    jmp next
    
INSTR:               ; TEMP1 has addr of string to search, zero termed
                     ; TEMP2 has addr of string to find
                     ; TEMP3 has length of search string
    ldy #0
    ldx #0
INSTRLP:
    jsr DUMPREG
    
    lda (TEMP1),y
    beq INSTRNONE
    sec
    sbc (TEMP2),y
    inx
    iny
    and #$FF            ; just need a test
    bne INSTRINC
    cpx TEMP3
    beq INSTRFOUND
    bra INSTRLP
INSTRINC:
    dey
    dex
    bne INSTRINC
    iny
    dec TEMP2
    lda TEMP2
    cmp #$FF
    beq INSTRINC2
    bra INSTRLP
INSTRINC2:
    dec TEMP2+1
    bra INSTRLP    
INSTRFOUND:
    tya
    sec
    sbc TEMP3
    sta TEMP2
    bra INSTROK    ; skip
INSTRNONE:
    lda #$FF     ; dint find it.
    sta TEMP2    ; can't use 0 cuz could be legit offset
INSTROK:
    stz TEMP2+1
    rts
;
;       search for a byte in memory. Do not search more than $FF bytes
;    return OFFSET.  If no luck, return next page to search.
;
;    NOTE:  I need alternate ways to terminate this search, built in.
; 
def_word "bin&", "binamp", 0
    jsr spull_0   ; address to start
    jsr spull_1   ; byte to search for.  ignore MSB
    jsr BINAMP
    jsr spush_0
    jmp next
 
def_word "bind&", "binampd", 0   ; search to delimeter at DELIM
    jsr spull_0   ; address to start
    jsr spull_1   ; byte to search for.  ignore MSB
    jsr BINAMPD
    jsr spush_0
    jmp next

BINAMP:
    ldy #0
BINAMPLP:
    lda (TEMP1),y
    cmp TEMP2
    beq BINAMP_FOUND
    iny
    beq BINAMP_NONE
    bra BINAMPLP
BINAMP_FOUND:
    stz TEMP1+1
    sty TEMP1          ; this is the offset, NOT the found address
    rts
BINAMP_NONE:
    inc TEMP1+1        ; and this is one page ahead, if NOT found
BINAMP_END:
    rts

BINAMPD:               ; search until found or delimeter
    ldy #0
BINAMPDLP:
    lda (TEMP1),y
    cmp TEMP2
    beq BINAMP_FOUND
    cmp DELIM
    beq BINAMPD_NONE
    iny
    beq BINAMP_NONE    ; return next page if no results so far
    bra BINAMPDLP
BINAMPD_NONE:
    lda #$FF           ; not found before delimeter
    sta TEMP1+1
    iny                ; offset + 1 of delimeter
    sty TEMP1     
    rts
    
    
;----------------------------------------------------------------------------
;                     HFA - HyForth mini-assembler stuff
;
;  opcode family table
def_word "fa_ops@", "faopsget", 0
    lda #<FA_ops
    sta TEMP1
    lda #>FA_ops
    jmp keeps                   ; 'keeps' includes sta TEMP1+1 / jsr spush_0 / jmp next
;
;  opcode address mode table
def_word "fa_adm@", "faadmget", 0
    lda #<FA_addr
    sta TEMP1
    lda #>FA_addr
    jmp keeps
;
;  capture and convert address mode string to #
def_word "fa_amcap", "fa_amcap", 0

;  mnemonic string addr
def_word "fa_mnsz@", "famnszget", 0
    lda #<MNEMONIC_STR
    sta TEMP1
    lda #>MNEMONIC_STR
    jmp keeps
;
;  mnemonic offset table addr
;
def_word "fa_mno@", "famnoget", 0
    lda #<MN_OFFSETS
    sta TEMP1
    lda #>MN_OFFSETS
    jmp keeps
;
;
def_word "fa_m2s&", "fam2samp", 0    ; returns offset in mn string
       ;
       ; note: calling token kills x, y, a, TEMP1, TEMP2, TEMP4, TEMP5, TEMP6
       ;  (at least) Best not to use any TEMPs until after call, if possible
       ;
    jsr token            ; get following token  
    lda NXTTOK
    sta TEMP2         ;store addr of token
    lda NXTTOK+1
    sta TEMP2+1    
    ldy #0
    lda (TEMP2),y
    sta TEMP3         ; save length
    inc TEMP2
    bne ASCANL0
    inc TEMP2+1
ASCANL0:
    jsr spull_0     ; TEMP1 has address of DISASM mnemonic string
    jsr INSTR
    jsr spush_1       ; push TEMP2 on DS, found
    jmp next
;
;         return hex address mode from string
;
def_word "fa_asz&", "faaszamp", 0
    ldy #TEMP4
    jsr  spull
    jsr FA_ASZ2AM
    bcc FA_ASZ_SZERR
    ldy #TEMP4
    jsr  spush
FA_ASZ_SZERR:
    jmp next


FA_ASZ2AM:           ; address string to address mode  - TEMP4 has address, will return mode
    ldy #0
    lda (TEMP4),y
    tax
    iny
    lda (TEMP4),y
    beq  FA_ASZ1
 ;
    ldy #0                  ; has two chars
    sta TEMP4+1             ; stash A here
FA_ASZ2LP:
    txa
    cmp FA_amtable2,y
    beq FA_ASZ2_NXT
    iny
    iny
    iny
FA_ASZ2_ychk:
    cpy #FA_xamtablen2
    beq FA_ASZERR
    bra FA_ASZ2LP
FA_ASZ2_NXT:
    iny
    lda TEMP4+1            ; get A back
    cmp FA_amtable2, y
    beq FA_ASZ2_found
    iny
    iny
    bra FA_ASZ2_ychk
FA_ASZ2_found:
    iny
    lda FA_amtable2,y
    sta TEMP4
    bra FA_ASZDONE
;  
FA_ASZ1:                   ; is it a digit so RMB/SMB/BBR/BBS?
    txa
    sec
    sbc #$30
    bmi  FA_ASZERR        ; not anything we can use
    cmp #8
    bpl  FA_ASZNOTDIG     ; not a digit 0-7
    inc                   ; shift to upper nybble, add one
    asl
    asl
    asl
    asl
    sta TEMP4
    bra FA_ASZDONE        ; mode will be $10-$80 depending on 0-7 digit
FA_ASZNOTDIG:
    ldy #0
FA_ASZ1LP:
    txa
    cmp   FA_amtable1,y
    beq    FA_ASZ1_found
    iny
    iny
    cpy #FA_xamtablen1
    beq  FA_ASZERR
    bra  FA_ASZ1LP
FA_ASZ1_found:
    iny
    lda   FA_amtable1,y
    sta TEMP4
FA_ASZDONE:
    stz TEMP4+1
    sec             ; found something
    rts
    
FA_ASZERR:          ; oops
    clc
    rts
    
;----------------------------------------------------------------------------
;                     HyFedit - editor stuff
def_word "fedisp", "fedisp", 0
    jsr HFE_WARM                    ; note: as of 11/4/26, only diff between HFE_WARM and _COLD
    jmp next                        ; is a flag set to say which entry point was used.  May be more use later.
;
;    
def_word "febuf", "febuf", 0
    lda DSPTR                   ; if nothing in stack...
    cmp #DSEND                 
    bne FEBUF_RESET            ; then set FEBUF to SCRBUF
    jsr spull_0
    ldy TEMP1
    sty HFEBUF
    ldy TEMP1+1
    sty HFEBUF+1
    bra FEBUF_END
FEBUF_RESET:    
    ldy #<SCRBUF                ; initialize screen pointer
    sty HFEBUF                  ; HFE_BPTR is set up when 
    ldy #>SCRBUF                ;   HFE_COLD is called.
    sty HFEBUF+1                
FEBUF_END:
    jmp next
;
;   copy data into current SCRBUF 
;   
def_word "fedit", "fedit", 0
    jsr spull_0
    lda HFEBUF
    sta HFE_BPTR
    lda HFEBUF+1
    sta HFE_BPTR+1
    lda HFEROWS
    sta TEMP5
FEDIT_LP2:
    ldy #$FF
FEDIT_LP0:
    iny
    cpy HFECOLS
    beq FEDIT_EOL
    ;
    lda (TEMP1),y
    beq  FEDIT_CLDONE
    cmp #9
    beq  FEDIT_CLDONE
    ;
    sta (HFE_BPTR),y
    bra FEDIT_LP0
FEDIT_CLDONE:
    phy
    lda #$20
    sta (HFE_BPTR),y           ; print spc instead of \0
FEDIT_LP1:
    iny
    cpy HFECOLS
    beq FEDIT_EOL
    sta (HFE_BPTR),y
    bra FEDIT_LP1
FEDIT_EOL:
    lda #0
    dey
    sta (HFE_BPTR),y    
    lda HFE_BPTR
    clc
    adc #$40
    bcc FEDIT_SK0
    inc HFE_BPTR+1
FEDIT_SK0:
    sta HFE_BPTR
    pla              ; from backed up Y
    inc
    clc
    adc TEMP1
    bcc FEDIT_SK1
    inc TEMP1+1
FEDIT_SK1:
    sta TEMP1
    dec TEMP5
    bne FEDIT_LP2
;
    jmp next
;
;    
def_word "feclr", "feclr", 0
    jsr CLR_SCREENBUF
    jmp next
;
;    ADD TEXT FROM STRING TO BUFFER
;
def_word "feadd", "feadd", 0
    jsr spull_0                  ; get addr of string to add, in TEMP1
    lda HFEROWS
    dec
    cmp HFE_CV
    bcc  FEADDNEXT               ; failed bounds check
    lda HFE_CV
    sta TEMP2
    jsr FELIN                   ; row in TEMP2 -> address, destroys Y  
    jsr FECPY                    ; src addr in TEMP1 returns # of chars copied in Y
    sty TEMP1                    ; reuse TEMP1 for chars copied
    stz TEMP1+1
    jsr spush_0                  ; push # of chars
    inc HFE_CV                 ; update cursor row pos
    lda #0
    sta HFE_CH                 ; and columns too
FEADDNEXT:
    jmp next

def_word "felin", "felin", 0       ; calc address in buffer for a given line and column
    jsr spull_1                    ; row in TEMP2
    jsr spull_2                    ; column in TEMP3
    lda TEMP2
    cmp HFECOLS                    ; do bounds checking first
    beq FELNXT
    bcs FELNXT
    lda TEMP3
    cmp HFEROWS
    beq FELNXT
    bcs FELNXT      
    jsr FELIN                   ; addr will end up in TEMP2
    lda TEMP2
    clc
    adc TEMP3                    ; now add column to addr
    sta TEMP2
    bcc FEL2SK
    inc TEMP2+1
FEL2SK:
    jsr spush_1
FELNXT:
    clc
    jmp next

    
;    SET CURRENT VERTICAL CURSOR POS - row
def_word "ferow!", "ferow_g", 0
    jsr spull_0
    lda TEMP1
    sta HFE_CV
    jmp next
;
;    SET CURRENT HORIZONTAL CURSOR POS - column    
def_word "fecol!", "fecol_g", 0
    jsr spull_0
    lda TEMP1
    sta HFE_CH
    jmp next
;
;    GET COORDINATES OF CURSOR
def_word "ferc@", "ferc_get", 0
    stz TEMP1+1
    lda HFE_CV
    sta TEMP1
    jsr spush_0
    lda HFE_CH
    sta TEMP1
    jsr spush_0
    jmp next
;----------------------------------------------------------------------------
HYWORDS_END:
;  end hywords.s
;----------------------------------------------------------------------------