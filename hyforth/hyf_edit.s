;----------------------------------------------------------------------
;
;  Patrick Struthers - October/November 2026
;
; *** hyf_edit.s
;
; HyFedit - screen editor for Hydra-16 / HyForth
;
; NOTES:  for now this is included at the tail of 'upper.s' in
;   the main hyforth build, but has a seperate ROM space 
;   at $F500 per the os_rom.cfg file.  May just add it to 
;   tail of core Forth OS ROM code after all...
;
;
.debuginfo
.setcpu "65C02"
;---------------------------------------------------------------------
;  macros in hyforth.s
;.macro WCRLF_np                 -- print CRLF, no push/pull of A
;.macro WCRLF                    -- print CRLF, p/p A
;.macro WSEQ_np  strlbl          -- print (strlbl) + \0, p/p Y only
;.macro WSEQ  strlbl             -- print (strlbl) + \0, p/p Y and A, w/CRLF
;.macro ANSI b1,b2,b3,b4,b5,b6   -- print up to six ANSI codes, p/p A
;
;.macro ERR_entry errmsg         -- macro to create errmsg entry
;.macro WERR errptr              -- write error using 
;
;---------------------------------------------------------------------
;  definitions in hyforth.s
;
; DEBUG := 1        ; enable inclusion of debug code
;
; INROM = $A000
;
; malloc stack and managed memory area
; both move downwards like other stacks
;
;MEMEND = $01FE            ; pointers DOWN from MEMEND+MEMSTK (store-and-decrement)
;MEMTOP = $8000            ; malloc allocates DOWN from MEMTOP
;
;INBUF = $0400             ; see stacks segment
;
;---------------------------------------------------------------------
;  HyFedit definitions
;
HFE_EOL = $00              ; end of line
HFE_EOR = $09              ; tab means end of row
HFE_HZC = $2D              ; for horizontal frame '-'
HFE_VTC = $7C              ; for vertical frame   '|'
;
;
;.segment "ZEROPAGE"
; **** hyforth.s ZP
;
;.org $C0
;HFE_BPTR:   .res 2             ; pointer into 1K buffer      $C0
;HFE_CH:     .res 1             ; cursor horizontal           $C2
;HFE_CV:     .res 1             ; cursor vertical             $C3
;HFE_T0:     .res 1             ; reserved                    $C4
;HFE_T0H:    .res 1             ; reserved                    $C5
;HFE_T1:     .res 1             ; reserved                    $C6
;HFE_T1H:    .res 1             ; reserved                    $C7
;
;TEMP0:     .res 2             ;  DUMPREG                    $C8   
;TEMP8:     .res 2             ;  Hstring macro              $CA   
;TEMP9:     .res 2             ;  Imm                        $CC   
;MEMPTR:    .res 2             ;  malloc                     $CE   
;MEMLAST:   .res 2             ;  malloc                     $D0
;TIB:       .res 2             ; pointer to input buffer     $D2
;TIBEND:    .res 2             ; pointer to end of TIB       $D4
;DFLAG:     .res 1             ; debug flag                  $D6
;ERRFLAG:   .res 1             ; error type, 0 = none        $D7
;ERRPTR:    .res 2             ; ptr to mitigation/message   $D8
;TEMP1:     .res 2     ; first, COPYTORAM, MEMCPY            $F0
;TEMP2:     .res 2     ; second, COPYTORAM, MEMCPY           $F2
;TEMP3:     .res 2     ; third, COPYTORAM, MEMCPY            $F4
;TEMP4:     .res 2     ; fourth,                             $F6
;NXTTOK:    .res 2     ; next token in tib (INBUF)           $F8
;TEMP5:     .res 1     ;    WORDS, WFIND, MEMCPY             $FC
;TEMP6:     .res 1     ;    WORDS, DIGCONT, TEXTGET          $FD
;TEMP7:     .res 2     ;    AUTOLOAD                         $FE
;---------------------------------------------------------------------
;
;     hyforth.s buffers
;.segment "BUFFERS"
;
;   *** at $0400
;INBUF:
;      .res 256
;
;   *** at $0600
;MEMSTK:                      ; memory manager
;      .res 510
;      .res 2
;
;
;---------------------------------------------------------------------
;  hyforth.s starts at $0800
;
;  space reserved for *stuff* at $0806 to $0825
;
;HFE_RSV:           ; at $0806
;HFECOLS:        ; offsets to data in RAM
;    .byte $3F    ; 63 columns w/ $00 or $09 in rightmost
;HFEROWS:
;    .byte $10    ; 16 rows
;HFEBUF:
;    .res 2       ; addr to buffer
;             ideally, we would allocate 1K with 'malloc', then copy 
;             the address to HFEBUF in HyForth, then call HFE_COLD
;             ...or if buffer already got stuff, call HFE_WARM
;            
;   .res 6
;HFE_TITLE:
;    .byte "Generic ScreenX"
;    .byte 0, 0, 0, 0, 0, 0, 0    ; title of screen - zero terminated string, up to 12 chars incl \0
;
;---------------------------------------------------------------------
;.segment "FORTH_EDIT"
;                             ; this will be at $F500 until further notice...
HFE_WARM:
  lda #1                      ; set 'warm start' flag, HFE_T0H
  sta HFE_T0H
  bra hfe_warmover                    ; skip over next inst 
HFE_COLD:
  stz HFE_T0H
hfe_warmover: 
  lda HFEBUF+1
  sta HFE_BPTR+1
  lda HFEBUF                   ; find out where screen buffer is
  sta HFE_BPTR
  jsr HFE_SCRINIT
  stz HFE_CH                  ; set cursor position
  stz HFE_CV
  jmp HFE_START

HFE_START:
  jsr  HFE_SCRINIT
  jsr  HFE_REDRAW
  
HFE_PARSE:

hfe_getline:

HFE_EXIT:       
  rts
;
; end of main HyFedit code
;
;-------------------------------------------
;   Screen Init
HFE_SCRINIT:
  ;jsr ANSICLS
  lda #$40         ; 64 columns, including line ending
  sta HFECOLS
  lda #$10         ; 16 rows
  sta HFEROWS
  rts
  
;-------------------------------------------
;   Redraw
HFE_REDRAW:
  jsr hfe_draw_dline                     ; draw top line
  jsr hfe_draw_title                     ; draw title line
  jsr hfe_draw_dline                     ; draw border 
  ldx HFEROWS
  lda #$30
  sta HFE_T1                              ; for line #
HFE_LP0:
  jsr hfe_draw_bline
;  iny
;  tya
  lda HFECOLS
  clc
  adc HFE_BPTR                           ; update pointer to get to
  sta HFE_BPTR  
  bcc HFE_SK0                            ; next line.
  inc HFE_BPTR + 1
HFE_SK0:
  lda HFE_T1                             ; for printed line count
  inc a                                  ; increment for next 
  cmp #$3A                               ; line, and see if need
  bne HFE_SK1                            ; alpha hex yet.
  clc
  adc #7                                 ; yup.  It's now 'A'
HFE_SK1:
  sta HFE_T1
  dex
  bne HFE_LP0
  jsr hfe_draw_dline                     ; draw bottom line 
  rts
;
;  *** draw horizontal line
;
hfe_draw_dline:
  lda HFECOLS
  adc #3
  tax
hfe_ddloop:
  lda #'-'
  jsr WRITE_CHAR
  dex
  bne hfe_ddloop
  WCRLF_np                      ; CRLF w/o push/pull of A               
  rts
;
;  *** draw title line
;  
hfe_draw_title:
  lda #'|'
  jsr WRITE_CHAR
  ldy #20
  ldx HFECOLS
  inx
  lda #$20
hfe_dtloop0:
  jsr WRITE_CHAR
  dex
  dey
  bne hfe_dtloop0
  ;
  lda #$31              ; set color to red 
  sta Z_ANSI1
  lda #$33
  sta Z_ANSI1+1
  jsr ANSICOL         ; esc[31m
  ;
  ldy #0
  lda #>HFE_TITLE
  sta HFE_T0 + 1
  lda #<HFE_TITLE
  sta HFE_T0
hfe_dtloop1:
  lda (HFE_T0), y
  beq hfe_dtcon0
  jsr WRITE_CHAR
  iny
  dex
  bra hfe_dtloop1
hfe_dtcon0:
  stz Z_ANSI1         ; set color back to normal
  stz Z_ANSI1+1
  jsr ANSICOL         ; esc[0m
  lda #$20
hfe_dtloop2:
  jsr WRITE_CHAR
  dex
  bne hfe_dtloop2
  jsr WRITE_CHAR
  lda #'|'
  jsr WRITE_CHAR
  WCRLF_np                      ; CRLF w/o push/pull of A 
  rts
;
;  *** draw line from buffer
;  
hfe_draw_bline:
  lda #'|'
  jsr WRITE_CHAR
  ;
  lda #$32              ; set color to green
  sta Z_ANSI1
  lda #$33
  sta Z_ANSI1+1
  jsr ANSICOL  
  ;
  lda HFE_T1                     ; line #  
  jsr WRITE_CHAR                 ; print it
  ;
  stz Z_ANSI1
  stz Z_ANSI1+1        ; and back to normal
  jsr ANSICOL  
  ;  
  lda #'|'
  jsr WRITE_CHAR
  ldy #0
hfe_db_loop0:
  lda (HFE_BPTR),y                ; if \0 or tab,
  beq hfe_db_done                ; line is done
  cmp #$09                       ; and we can skip 
  beq hfe_db_done                ; to next line.
  cmp #$1F
  bcc hfe_db_spcsub              ; don't print non-printables
  cmp #$7F                       ;..there SHOULDN'T be any
  bcs hfe_db_spcsub              ; but who knows....
  jsr WRITE_CHAR                 ; padding out line.
  iny
  bra hfe_db_loop0
hfe_db_spcsub:
  lda #$20
  jsr WRITE_CHAR
  iny
  bra hfe_db_loop0               ; substitute spc for non-printables
hfe_db_done:
  sty HFE_T1H                    ; swap around to calc extra spaces
  lda HFECOLS
  sec
  sbc HFE_T1H
  tay
  lda #$20
hfe_db_loop1:
  jsr WRITE_CHAR                ; pad out rest of line
  dey
  bne  hfe_db_loop1
  lda #'|'
  jsr WRITE_CHAR  
  WCRLF_np                      ; CRLF w/o push/pull of A 

;  ldy HFE_T1H               ; restore Y and return to calc offset to next line...
;  jsr DUMPREG
  rts

;
;                 update a line on screen
;
HFE_UPDATE:                
  ldy #0
  ldx #HFE_CV
hfe_u_loop0:         ; count zeros/tabs up to current cursor pos
  lda (HFE_BPTR),y
  beq  HFEU_ZCNT
  cmp #$09
  beq  HFEU_ZCNT
  iny
  bra hfe_u_loop0
HFEU_ZCNT:
  iny
  tya
  clc
  adc HFE_BPTR         ; update HFE_BPTR
  bcc HFEU_SKIP
  inc HFE_BPTR + 1
HFEU_SKIP:
  ldy #0
  txa
  beq HFEU_LFOUND
  dex
  bra hfe_u_loop0
HFEU_LFOUND:
  lda HFE_CH
  sta HFE_T1           ; backup horizontal cursor pos
  lda #0
  sta HFE_CH          ; cuz we wanna draw from beginning of line
  jsr hfe_place_cur   ; place the cursor
  jsr hfe_draw_bline  ; and draw from the current HFE_PTR until line end
  lda HFE_T2
  sta HFE_BPTR
  lda HFE_T2 + 1       ; restore HFE_PTR and HFE_CH
  sta HFE_BPTR
  lda HFE_T1
  sta HFE_CH
  rts

hfe_place_cur:
  lda HFE_CH
  clc
  adc #2
  sta TEMP3
  lda HFE_CV
  clc
  adc #4
  sta TEMP4
  jsr ANSISCR
  rts
;
; end of hyf_edit.S
;