;
;  hfa.s  - split from 'hywords.s' 11/27/26 
;
; enable (=1) 'HFA' in hyforth.s to load
;
;-----------------------------------------------------------------------------
;                     HFA - HyForth mini-assembler
;
;
;  Three passes of assembler
;   1)  convert a 'mnemonic' line of assembly e.g. 'LDAiy F0' to machine code
;          q^LDAiy F0^
;          {_mnsz@ pad@ @ 3 + 3 insz   ( -- off )
;          {_mno@ bin&                 ( -- bop )
;          pad@ @ 6 + {_asz&           ( -- bop am )
;          {_bop&                      ( -- f len op )
;          pad@ @ 8 + c@ x2bin          ( -- obmsb f len op )
;          pad@ @ 9 + c@ x2bin          ( -- oblsb obmsb f len op )
;
;   2) use '{org}' to set origin of new code
;
;
;
;------------------------------------------------------------------------------
;
;  opcode family table
def_word "{_ops@", "faopsget", 0
    lda #<FA_ops
    sta TEMP1
    lda #>FA_ops
    jmp keeps                   ; 'keeps' includes sta TEMP1+1 / jsr spush_0 / jmp next
;
;  opcode address mode table
def_word "{_adm@", "faadmget", 0
    lda #<FA_addr
    sta TEMP1
    lda #>FA_addr
    jmp keeps
;
;  mnemonic string addr from DISASM
def_word "{_mnsz@", "famnszget", 0
    lda #<MNEMONIC_STR
    sta TEMP1
    lda #>MNEMONIC_STR
    jmp keeps
;
;  mnemonic offset table addr from DISASM
;
def_word "{_mno@", "famnoget", 0
    lda #<MN_OFFSETS
    sta TEMP1
    lda #>MN_OFFSETS
    jmp keeps
;
;
;        fa_m2st& WAS ONLY proof of concept; not needed now, but good example of
;            how to handle the 'token' post-parser.
;
; ( mnsa -- off )
;def_word "{_m2st&", "fam2sampt", 0    ; returns offset in mn string (command line)
;     
;     note: calling token kills x, y, a, TEMP1, TEMP2, TEMP4, TEMP5, TEMP6
;      (at least) Best not to use any TEMPs until after call, if possible
;
;    jsr token            ; get following token  
;    lda NXTTOK
;    sta TEMP2         ;store addr of token
;    lda NXTTOK+1
;    sta TEMP2+1    
;    ldy #0
;    lda (TEMP2),y
;    sta TEMP3         ; save length
;    inc TEMP2
;    bne ASCANL0
;    inc TEMP2+1
;    jmp ASCANL0
;
;--------------------------------------------------------------------------
;
; ( mnsa sn -- off )
def_word "{_m2s&", "fam2samp", 0    ; returns offset in mn vs memory 
    lda #3
    sta TEMP3       ; length
    jsr spull_1     ; TEMP2 has addr of search string
ASCANL0:
    jsr spull_0     ; TEMP1 has address of DISASM mnemonic string
    jsr INSTR
    jsr spush_1       ; push TEMP2 on DS, found
    jmp next
;
;         return hex address mode from string
; ( amasz -- am )
def_word "{_asz&", "faaszamp", 0
    ldy #TEMP4
    jsr  spull
    jsr FA_ASZ2AM
    bcc FA_ASZ_SZERR
    ldy #TEMP4
    jsr  spush
    jmp  next
    
FA_ASZ_SZERR:
    stz TEMP1+1
    lda #$FF
    sta TEMP1        ; return $00FF if no valid addr mode
    jmp this

FA_ASZ2AM:           ; address string to address mode  - TEMP4 has address, will return mode
    ldy #0
    lda (TEMP4),y
    tax
    iny
    lda (TEMP4),y
 ;   beq  FA_ASZ1       ; zero term, done
    cmp #$30
    bmi  FA_ASZ1       ; ..or anything less than ASCII 0
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
    bra FA_ASZDONE        ; mode will be $10-$80 depending on 0-7 digit.  REMEMBER to fix when adding to base op!
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
;
;    scan for inst. family using base op code
;    return family code, len of inst, opcode
; ( bop am -- f len op ) 
;
def_word "{_bop&", "fabaseopscan"
    jsr spull_2    ; address mode in TEMP3
    stz TEMP3+1

    jsr spull_1    ; base op in TEMP2 for now
    stz TEMP2+1
    lda TEMP3   
;jsr DUMPREG           ; $20B1
    cmp #$10
    bpl FA_SEQLJMP   ; if baseop is RMB/SMB/BBR/BBS then
    beq FA_SEQLJMP   ; can skip over most of this.
    
    lda #<FA_ops
    sta TEMP1
    lda #>FA_ops
    sta TEMP1+1
    lda DELIM
    sta TEMP3+1    ; backup DELIM
    lda #3
    sta DELIM
    stz TEMP4     ; will store family #
    stz TEMP4+1   ; will store family op, then final op
    ldy #0           ; count offset through family list
    lda FA_ops, y    ; store base family op
    sta TEMP4+1
FA_BOPLP0:
;jsr DUMPREG          ;  $20D5
    lda TEMP1
    sta TEMP5
    lda TEMP1+1
    sta TEMP6
    jsr   BINAMPD    ; base op will be in TEMP2, opaddr in TEMP1, offset if found TEMP1
                   ; if none found TEMP1 = $FF MSB + offset LSB to next table
;jsr DUMPREG          ;  $20DC
    ldy TEMP1        ; save offset
    inc TEMP4        ; inc fam #
    lda TEMP4         
    cmp #(FA_FAMCNT+1)  ; done with all of them?
    beq   FA_BNOFAM  ; none there, skip down to 'exceptions' in ad-mode list
    lda TEMP1+1
    bmi   FA_NOTFAM   ; if $FF, skip down and continue loop
                    ; else FOUND
    bra   FA_FAMFOUND  ; skip down to finish

FA_SEQLJMP:
    jmp FA_BSEQOP
    
FA_NOTFAM:
    lda TEMP6
    sta TEMP1+1
    tya
    clc
    adc TEMP5
    sta TEMP1
    bcc  FA_BSK0
    inc TEMP1+1
FA_BSK0:
    ldy #0
    lda (TEMP1),y      ; get next base op
    sta TEMP4+1       ; save fer later
    bra FA_BOPLP0
  
FA_FAMFOUND:          ; now look up family base op in addr mode table
    dec TEMP4
    lda TEMP4      
    cmp #3            ; check fam#, is it more or less than 3?
    bpl FA_BSK1
    beq FA_BSK1
                      ; family 0,1,2 just have 1 address mode
    lda TEMP2         ; so we already have the correct op code
    sta TEMP4+1       ; save it.
    lda TEMP4
    beq   FA_BSKSINGLE   ; single byte instruction for fam 0
    cmp #1
    beq   FA_BJSR       ; it's JSR, fam 1
    lda #2            ; else it's a branch, fam 2
    bra   FA_BSK2
FA_BJSR:
    lda #3
    bra   FA_BSK2
FA_BSKSINGLE:
    lda #1
FA_BSK2:
    sta TEMP2              ; store length
    bra   FA_BSK2END
    
FA_BSK1:                  ; now lookup address mode
    ldx  #0               ; 'normal' families
    bra   FA_BAAMLKLP
FA_BNOFAM:
    ldx #(FA_anofam-FA_addr)   ; exceptions
    lda #$0F
    sta TEMP4          ; exceptions are family 'F'
    lda TEMP2
    sta TEMP4+1        ; and we are match base code, not family code
FA_BAAMLKLP:
;jsr   DUMPREG                ; $213D
    lda FA_addr,x    
;jsr DUMPREG                  ; $2143
    beq   FA_BOPERR
    cmp TEMP4+1             ; match fam base, NOT mn base  (except for exceptions, bwahah)
    beq   FA_BNXT0           ; go here if found?
    txa
    clc
    adc #FA_AMRLEN      ; FA_AMRLEN is row width
    tax
    bra   FA_BAAMLKLP
    
FA_BNXT0:
    inx                  ; cuz they are offset 1-14 in row, not 0
    txa
    clc
    adc TEMP3            ; add address mode code
    tax
    lda FA_addr,x        ; get offset code for op
    cmp #$FF   
;jsr DUMPREG              ; $215F
    beq FA_BOPERR
    sta TEMP4+1            ; store offset and continue
    clc
    adc TEMP2
    sta TEMP4+1
    bra FA_BNXT1
    
FA_BSEQOP:            ; for RMB/SMB/BBR/BBS
    lda #$F0
    sta TEMP4         ; family # is $F0
    clc
    adc TEMP3        ; address mode for these is $10-$80 -> $00 - $70
    clc
    adc TEMP2        ; add base op ($07, $87, $0F, $8F)
    sta TEMP4+1      ; op code
    stz TEMP1+1      ; zero out fer later
    stz TEMP2+1
    lda TEMP2
    and #$08
    beq FA_BSK4      ; is this BBR/BBS?
    inc TEMP4        ; yes. family is $F1
FA_BSK4:
    lda #2
    sta TEMP2         ; length for all is 2   
;jsr DUMPREG
    bra   FA_BSK2END
FA_BNXT1:
    stz TEMP1+1
    stz TEMP2+1
                  ; get # bytes of inst in TEMP2
    lda TEMP3    ; address mode?
    cmp #8
    bpl   FA_BNXT2     ; more than...
    beq   FA_BNXT2    ; or equal to 8?  3 bytes per inst
    lda #2
    bra   FA_BNXT3
FA_BNXT2:
    lda #3
FA_BNXT3:
    sta TEMP2
FA_BSK2END:
    lda TEMP4 
    sta TEMP1
    jsr spush_0     ; push family#   
    lda TEMP4+1
    sta TEMP1
    jsr spush_0     ; push opcode
    jsr spush_1     ; push length of inst
    lda TEMP3+1
    sta DELIM      ; restore previous DELIM
    sec           ; all is good
    jmp next
    
FA_BOPERR:
    clc
    lda #$FF
    sta TEMP1
    sta TEMP1+1
    jmp this
;
;
; ( addr -- opa ) 
;
def_word "{_opa&", "faopasscan"
    jsr spull_0     ; addr in TEMP1
    stz TEMP5       ; count digits
    stz TEMP2+1
    ldy #$FF
FA_OPASSLP:
    iny
    lda (TEMP1),y
    beq FA_OPASNOT         ; end of string?  nuthin
    cmp #$20
    bne FA_OPASSLP
FA_OPASLP:
    iny
    lda (TEMP1),y
    beq FA_OPASNOT
    cmp #$20
    beq FA_OPASLP    
    sec
    sbc #$30
    bmi FA_OPASNOT         ; error, not good number
    cmp #$0A
    bmi FA_OPASFOUND
    sec
    sbc #7
    cmp #$10
    bmi FA_OPASFOUND
    bra FA_OPASNOT        ; error, not good char
FA_OPASFOUND:
    pha
    sta TEMP6
    lda TEMP5
    ror
    bcc FA_OPSKIPPUSH
    lda TEMP2
    asl
    rol
    rol
    rol
    clc
    adc TEMP6
    sta TEMP2
    phy
    jsr spush_1
    ply
FA_OPSKIPPUSH:
    pla
    sta TEMP2
    inc TEMP5
    bra FA_OPASLP
FA_OPASNOT:
    jmp next
;
;   end of hfa.s
;