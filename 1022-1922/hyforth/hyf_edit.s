;----------------------------------------------------------------------
;
;  Patrick Struthers - October/November 2026
;
; *** hyf_edit.s
;
; HyFedit - screen editor for Hydra-16 / HyForth
;
; NOTES:  for now this is included at the tail of 'upper.s' in
;   the main hyforth build.
;
;
.debuginfo
.setcpu "65C02"
;---------------------------------------------------------------------
;  macros in hyforth.s
;.macro WCRLF_np                 -- print CRLF, no push/pull of A
;.macro WCRLF                    -- print CRLF, p/p A
;.macro WSEQ_np  strlbl          -- print (strlbl) + \0, p/p Y only
;.macro WSEQ_raw strlbl          -- print (strlbl) + \0, p/p Y, no CRLF
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
HFE_HZC = $2D             ; for horizontal frame
HFE_VTC = $7C             ; for vertical frame
;
;
.segment "ZEROPAGE"
.org $C0
HFE_BPTR:   .res 2             ; pointer into 1K buffer     $C0
HFE_CH:     .res 1             ; cursor horizontal          $C2
HFE_CV:     .res 1             ; cursor vertical            $C3
HFE_CCNT:   .res 1             
HFE_LCNT:   .res 1
;
; **** hyforth.s ZP
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
;HFEWID:        ; offsets to data in RAM
;    .byte $40    ; 64 columns w/ $00 or $09 in rightmost
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

;---------------------------------------------------------------------
.segment "FORTH_EDIT"
;                             ; this will be at $F500 until further notice...
;
HFE_WARM:
  lda #1                      ; set 'warm start' flag
  sta TEMP1
  jmp hfe_warmover
  
HFE_COLD:
  stz TEMP1
  lda #<HFEBUF        ; find out where screen buffer is
  sta HFE_BPTR
  lda #>HFEBUF
  sta HFE_BPTR + 1
  jsr HFE_SCRINIT
  stz HFE_CH                 ; set cursor position
  stz HFE_CV
  jmp HFE_START

  
hfe_warmover:
  lda TEMP1
  bne  HFE_START
  jsr  HFE_SCRINIT  

HFE_START:
  jsr  HFE_REDRAW
  
HFE_PARSE:

hfe_place_cur:
  
hfe_getline:


  
;
HFE_EXIT:       
  rts
HFE_ENDS:
;
; end of main HyFedit code
;
;-------------------------------------------
;   Screen Init
HFE_SCRINIT:

  
;-------------------------------------------
;   Redraw
HFE_REDRAW:

  jsr hfe_draw_dline
  
  jsr hfe_draw_title
  
  jsr hfe_draw_dline
  
  jsr hfe_draw_bline

  rts
;
;  *** draw horizontal line
;
hfe_draw_dline:
  ldx HFEWID
hfe_ddloop:
  lda #'-'
  jsr WRITE_CHAR
  dex
  bne hfe_ddloop
  rts
;
;  *** draw title line
;  
hfe_draw_title:
  ldx HFEWID + 2
  lda #'|'
  jsr WRITE_CHAR
  dex
  ldy #20
  lda #$20
hfe_dtloop0:
  jsr WRITE_CHAR
  dex
  dey
  bne hfe_dtloop0
  ldy #0
hfe_dtloop1:
  lda HFE_TITLE, y
  beq hfe_dtcon0
  jsr WRITE_CHAR
  iny
  dex
  bra hfe_dtloop1
hfe_dtcon0:
  lda #$20
hfe_dtloop2:
  jsr WRITE_CHAR
  dex
  bne hfe_dtloop2
  jsr WRITE_CHAR
  lda #'|'
  jsr WRITE_CHAR
  rts
;
;  *** draw line from buffer
;  
hfe_draw_bline:

  rts
;
; end of hyf_edit.S
;
