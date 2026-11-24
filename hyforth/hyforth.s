;----------------------------------------------------------------------
;
;  Patrick Struthers - March 2026
;      - THANKS to AGSB for the starting point here....
;
;  The HyForth project starts here with AGSB's core Forth engine;
;  the engine now resides in ROM (as of 5/1/26) and the heap is copied to RAM
;  on cold start.
;
;  The ulitmate purpose of working this port through is to develop a
;  flexible and powerful operating system for the Hydra-16 of reasonable
;  efficiency and minimal memory footprint.  Eventually, HyForth will be
;  able to grow and shrink in RAM footprint according to context.
;
; ---------------------------------------------------------------------
;
.debuginfo
.setcpu "65C02"

;---------------------------------------------------------------------
; macros for dictionary, creates code as follows:
;
;   h_name:
;   .word  link_to_previous_entry
;   .byte  strlen(name) + flags
;   .byte  name
;   name:
;
; label for primitives
;
.macro makelabel arg1, arg2
.ident (.concat (arg1, arg2)):
.endmacro
;
; header for primitives
; the entry point for dictionary is h_~name~
; the entry point for code is ~name~
;
.macro def_word name, label, flag
makelabel "h_", label
.ident(.sprintf("H%04X", hcount + 1)):
  .word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
  .byte .strlen(name) + flag + 0 ; nice trick !
  .byte name
makelabel "", label
.endmacro
;---------------------------------------------------------------------
;  macros for PGS stuff
;
.macro WCRLF_np                ; no push of A
       lda #$0D
       jsr WRITE_CHAR
       lda #$0A
       jsr WRITE_CHAR
.endmacro

.macro WCRLF
       pha
       lda #$0D
       jsr WRITE_CHAR
       lda #$0A
       jsr WRITE_CHAR
       pla
.endmacro

.macro  WSEQ_np  strlbl
     phy
     ldy #0
:
     lda strlbl, y
     beq :+
     iny
     jsr WRITE_CHAR
     bra :-
:
     WCRLF_np
     ply
.endmacro


.macro  WSEQ_raw  strlbl
     phy
     ldy #0
:
     lda strlbl, y
     beq :+
     iny
     jsr WRITE_CHAR
     bra :-
:
     ply
.endmacro

.macro WSEQ  strlbl
      pha
      WSEQ_np  strlbl
      pla
.endmacro
;
;---------------------------------------------------------------------
;  for error messages
;
.macro ERR_entry errmsg
    .byte <errmsg
    .byte >errmsg
    emcount .set emcount + 1
.endmacro

.macro WERR errptr
;.macro WERR
    .local werrloop, werrend
    WCRLF_np
    ldy #0
    lda (errptr),y
    sta TEMP0
    iny
    lda (errptr),y
    sta TEMP0+1
    ldy #0
werrloop:
    lda (TEMP0),y
    beq werrend
    iny
    jsr WRITE_CHAR
    bra werrloop
werrend:
    WCRLF_np
    rts
.endmacro
;
;---------------------------------------------------------------------
;              library list  - handle like an error/token jumptable
;
;                --- this is also how MS-BASIC knows where to send
;   the code when a tokenized command is invoked.  Inherent limitation
;   with one-byte tokens (for errors or libraries) is max of 255 entries.
;
.macro LIBENTRY libname, bank
    .byte <libname
    .byte >libname
    .byte bank
    .byte 0
    libcount .set libcount + 1
.endmacro
;
;---------------------------------------------------------------------
; variables for macros

hcount .set 0
emcount .set 0             ; # of error messages set up
libcount .set 0

H0000 = 0

;---------------------------------------------------------------------
;               CONFIGURATION OPTIONS
;---------------------------------------------------------------------

; number conversion
numbers := 1      ; include DEC/BIN/HEX conversion

SINGLE := 1     ; single digits hard coded?

DEBUG := 1        ; enable inclusion of debug code

HYWORDS := 1      ; add in additional hardcoded words / logic

ANSIOK := 1         ; add ANSI screen stuff

YSOUND := 1        ; add sound support

;TXT2STACK := 1     ; use old TXTGET instead of new

;---------------------------------------------------------------------
;              for PGS hyforth stuff
;
; error codes
;
ERR_RPTR := $01    ; return stack pointer error
ERR_SPTR := $02    ; data stack pointer error
ERR_DIV0 := $03    ; divide by zero
ERR_MEM := $04     ; memory not-avail
ERR_UKW := $05     ; unknown word
ERR_SEC := $06     ; security error, ie dangerous address write
ERR_SYS := $07     ; return from system call error
ERR_PAD := $08
  ; warnings
WRN_SEC := $86     ; security
WRN_MEM := $84     ; memory alloc
;
;---------------------------------------------------------------------
;                 CORE ENGINE CONSTANTS
;
CELL = 2         ; cell size, two bytes, 16-bit
FLAG_IMM = 1<<7  ; immediate flag
FLAG_COM = 1<<6  ; compiled flag
MAXSTR = 100

; terminal input buffer, forward
; getline, token, skip, scan, depends on page boundary
; INBUF = $0400  (see segment STACKS below)
; moves forwards
INBUF_end = $FD

; data stacks
; moves backwards, push decreases before copy
DSEND = $7E

; return stack
; moves backwards, push decreases before copy
RTEND = $FE

; malloc stack and managed memory area
; both move downwards like other stacks
;
MEMEND = $01FE            ; pointers DOWN from MEMEND+MEMSTK (store-and-decrement)
MEMTOP = $7BF0            ; malloc allocates DOWN from MEMTOP
SCRBUF = $7C00            ; screen buffer 1K going up
MSBUF = $600             ; note, allocated at assembly, may change
PADBUF = $800            ; note, allocated at assembly, may change

PADEND = $01FE            ; PAD+PADEND, up with PADPTR - increment and store
;
;   types:  <type> <len0 len1> <data data data...>
;
MEM_SCR = $01  ; screen  (1024 bytes, with 63 char rows terminated either $09 or $00
MEM_SZ = $04   ; zero-termed string
MEM_FRAC = $06 ; 'fractional binary' <type> <03 00> <offset> <xxxx>
MEM_TAB = $07  ; table
;
; spi
;F9E8 SPI_INIT_DELAY
;F9CC SPI_RECV
;F9AD SPI_SEND
;F9A3 SPI_OPERATION_DONE
;F974 SPI_TRANSCEIVE

INROM = $A000

;----------------------------------------------------------------------
;       Look closely at hyforth.cfg and the output of ca65/ld65 after
;  a build; the RAM and ROM code is carefully arranged when the binary
;  is created, to make initialization easier and optimize RAM use.
;  The main program engine starts at $EA00 in OS ROM and is only about 500 bytes
;  long.  Additional functions, then initialization and support code follow.
;  The heap or 'dictionary' primitives are stored on a banked ROM, mapped
;  to $A000, along with some meta-compiled words following the primitives.
; 
;       Currently, the primitives are loaded with 'COPYTORAM' (at $A000)
;  using parameters for the size and location of the heap stored at $A003,4,5.  
;
;       The dictionary has a particular structure, with 'bye' and 'abort'
;  at the beginning; there are some core words, then contents of 'primitives.s', 
; then 'hywords.s', followed by the end of the dictionary with critical items 
; such as 'fetch', 'store', 'immediate', 'compile, 'semis', 'exit, and ancillary 
; stuff.  Any sub-routines that are called by multiple words (and therefore need set
; addresses) appear in the 'utes.s' or 'upper.s' files.  These are considered 
; 'support code' and reside in OS ROM following the basic HyForth engine.
;
;       HyForth is started by running 'A00R' or 'EC00R' from Wozmon; 
;  the basic functions can be supplemented with the meta-compiled words, or 
;  'libraries' as well as runtime-loaded binaries and other items.  Libraries
;  are loaded with 'autoload' or 'bload' (compiled or binary).
;
;----------------------------------------------------------------------
;                   ZERO PAGE USAGE
;----------------------------------------------------------------------
.segment "ZEROPAGE"
;
.org $A0
ZPSTART:
                 ;   16 bytes for PAD and clipboard
                 ;
PADPTR:     .res 2             ; pointer to top of PAD linked list     $A0
DELIM:      .byte 0            ; default string delimiter       $A2
FLAGS:      .byte 0            ; all purpose flags byte         $A3
TEMPA:      .word 0            ; TEMP var A                     $A4
TEMPB:      .word 0            ; TEMP var B                     $A6
TEMPC:      .word 0            ; TEMP var C                     $A8
TEMPD:      .word 0            ; TEMP var D                     $AA
TEMPE:      .word 0            ; TEMP var E                     $AC
TEMPF:      .word 0            ; TEMP var F                     $AE
;
;                 Utilities, some BIOS crossover
;
Z_DEBUG:    .res 2             ; dedicated ZP temp for debugger  $B0
;
Z_MATH1:    .res 2             ; ZP temp for math routines   $B2  (*, /, */, felin)
Z_MATH2:    .res 2             ; ZP temp for math routines   $B4  (*, /, */, felin)
Z_MATH3:    .res 2             ; ZP temp for math routines   $B6  (*, /, */, felin)
Z_MATH4:    .res 2             ; ZP temp for math/ANSI       $B8  (HEX2DIG, */)
;
Z_ANSI1:    .res 2             ; ZP temp for ANSI            $BA
Z_ANSI2:    .res 2             ; ZP temp for ANSI            $BC
Z_ANSI3:    .res 2             ; ZP temp for ANSI            $BE
;
;                  HyFedit specific
;
HFE_BPTR:   .res 2             ; pointer into 1K buffer      $C0
HFE_CH:     .res 1             ; cursor horizontal (columns) $C2
HFE_CV:     .res 1             ; cursor vertical (rows)      $C3
HFE_T0:     .res 1             ; reserved                    $C4
HFE_T0H:    .res 1             ; reserved                    $C5
HFE_T1:     .res 1             ; reserved                    $C6
HFE_T1H:    .res 1             ; reserved                    $C7
;HFE_T2 is at $FE/$FF  (TEMP7)
;
;                   HyForth setup stuff
;
TEMP0:                    ; DUMPREG, lib/libs    $C8
   .res 2
TEMP8:                        ;  cons and pick   $CA
   .res 2
TEMP9:                        ;   Imm            $CC
   .res 2
MEMPTR:                       ;   malloc         $CE
   .res 2
MEMLAST:
   .res 2                      ;  malloc         $D0
TIB:
   .res 2          ; pointer to input buffer     $D2
TIBEND:
   .res 2          ; pointer to end of TIB       $D4
DFLAG:
   .res 1          ; debug flag                  $D6
ERRFLAG:
   .res 1          ; error type, 0 = none        $D7
ERRPTR:
   .res 2          ; ptr to mitigation/message   $D8
DIGBASE:
   .res 1          ; base for number conversion  $DA
RSEED:
   .res 4          ; random # seed               $DB
ALFLAG:            ; autoload flag               $DF
   .res 1
;
;                   internal Forth
;   NOTE:  do NOT change the order of the first eight words;
;     AGSB's 'training' words assume that STATUS -> WORKREG
;     are consecutive and in below sequence.
;
STATUS:     .word $0   ; state at lsb, last size+flag at msb   $E0
CURBUF:     .word $0   ; CURBUF next free byte in TIB          $E2
LASTHEAP:   .word $0   ; last link cell                        $E4
NEXTHEAP:   .word $0   ; next free cell in heap dictionary     $E6
;
;                   pointer registers
;
DSPTR:      .word $0   ; data stack pointer                    $E8
RTPTR:      .word $0   ; return stack pointer                  $EA
INSTPTR:    .word $0   ; instruction pointer                   $EC
WORKREG:    .word $0   ; working register                      $EE
;
;                    TEMP1 - 4
;
TEMP1:    .word $0     ; first                                 $F0
TEMP2:    .word $0     ; second                                $F2
TEMP3:    .word $0     ; third  (two bytes)                    $F4
TEMP4:    .word $0     ; fourth  (two bytes)                   $F6
;
;          NXTTOK, BACKHEAP, TEMP5 - 7
;
NXTTOK:     .word $0   ; next token in tib (INBUF)             $F8
BACKHEAP:   .word $0   ; hold 'here while compile              $FA
supprint:              ; suppress printing in MEMCPY
TEMP5:   .res 1        ;    WORDS, supprint for MEMCPY         $FC
TEMP6:   .res 1        ;    WORDS, DIGCOUNT, TEXTGET           $FD
HFE_T2:                ;   third temp variable for HyFedit
TEMP7:   .res 2        ;    AUTOLOAD, HyFedit                  $FE
;
; *** $B0-$FF total usage in ZP, including TEMP vars ***
;
;   HYDRA-16 serial/read buffers at $200 and $300 so skip those
;
;----------------------------------------------------------------------
;                   FORTH STACKS
;----------------------------------------------------------------------
.segment "BUFFERS"
INBUF:                                      ;    $400
      .res 256
DS:                          ; data stack (S)    $500
      .res 126
      .res 2
RT:                          ; return stack (R)  $580
      .res 126 
      .res 2
MEMSTK:                      ; memory manager    $600
      .res 510
      .res 2
PAD:                         ; pad memory         $800
;     .res 256
      .res 512               ; clipboard / command history (together with PAD for now)
;CLIP:
;      .res 256               
;
;
.segment "FORTH_ROM"              ; regular core $EC00 and RAM segment at $0A00 now
;
;
; ************ the real deal...
;

forth_main:
    jmp F_cold
    jmp COPYTORAM
HYPROMPT:
    .byte $0D, $0A
    .byte "HF>"
    .byte 0
;
HYLIBMSG:
    .byte $0D, $0A
    .byte "Libaries:"
    .byte 0
.ifdef DEBUG
WDISP:
    .byte $0D, $0A
    .byte "W="
    .byte 0
WATDISP:
    .byte "  [W]="
    .byte 0
.endif
;
;
;
F_cold:                         ; cold start - clears EVERYTHING
    cld
    jsr CLEAR                   ; zero out zero page, INBUF, DS, RT, SCRBUF
                                ;    
                                ; initialize HEAP pointers
    lda INROM+3                 ; standard 'heap' has been copied to RAM
    sta LASTHEAP + 1            ; and 'switcher' ('exit') code handles
                                ; the rest, with 'nest', 'unnest', 'keeps' 'next', 'jump'
                                ; 'spull', 'spush', 'comma' etc. all in ROM
    lda INROM+4                 ; wherever THAT ends up.
    sta LASTHEAP
                                ; next heap free cell
    lda INROM+5                 ; along with 'ends'
    inc a
    sta NEXTHEAP + 1
    stz NEXTHEAP
    stz ERRFLAG                ; clear ERROR flag
    stz DELIM                  ; clear string/search delimiter
    stz FLAGS                  ; HF flags register
    
    ldy #>(MEMSTK+MEMEND)       ; initialize memory manager area
    sty MEMPTR + 1
    ldy #<(MEMSTK+MEMEND)
    sty MEMPTR
    ldy #<MEMTOP
    sty MEMLAST
    ldy #>MEMTOP
    sty MEMLAST+1
    
    ldy #<SCRBUF                ; initialize screen pointer
    sty HFEBUF                  ; HFE_BPTR is set up when 
    ldy #>SCRBUF                ; HFE_COLD is called
    sty HFEBUF+1                ; done.  SCRBUF already cleared
    
;---------------------------------------------------------------------
; various reinitialization points
;
F_warm:                          ; warm start.  Clears TIB, DS, RT, and PAD
reset:                           ; leaves heap, memory area, and screen buffer alone
    ldy #INBUF_end
    sty TIBEND
    ldy #<INBUF
    sty TIB
    ldy #>INBUF
    sty TIB+1
    sty TIBEND+1
    sty CURBUF+1
    sty NXTTOK+1

    ldy #>DS                     ; DS and RT are now half page each
    sty DSPTR + 1
    ldy #>RT
    sty RTPTR + 1
    
    jsr PADINIT                  ; clear PAD
    
    lda #$FF                     ; DEBUG OFF by default
    sta DFLAG
;
    lda #<STARTAUTO                ; check to see if anything to autoload
    sta TEMP1
    lda #>STARTAUTO
    sta TEMP1+1
    ldy #0
    lda (TEMP1),y
    beq warm_next

    stz STATUS                   ; status is 'interpret' == \0  
    stz ALFLAG
    ldy #<DSEND
    sty DSPTR
    ;
    ;  stz DFLAG           ; start debug
    ;
    jmp CLOAD_ENTER
;
warm_next:
    stz ALFLAG                   ; autoload flag OFF
    
abort:                            ; clear DS (clear data stack)
    ldy #<DSEND
    sty DSPTR

errrtn:                          ; return from error w/o clearing DS
quit:                           
    ldy #<RTEND                  ; clear RT
    sty RTPTR

    jsr WERROR                   ; print any error messages, clear error flags
    ldy #0                       ; reset INBUF
    lda #0
    sta (TIB),y                  ; clear INBUF stuff
    stz CURBUF                   ; clear cursor  (pointer into INBUF)
    stz STATUS                   ; status is 'interpret' == \0

    .byte $2c       ; mask next two bytes, jump to resolve/okey
;---------------------------------------------------------------------
; the outer loop

resolvept:
    .word okey
;---------------------------------------------------------------------
okey:               ; well shit, I hope this is easy....
resolve:           ; get a token
    jsr token      ; then just process the regular way
.ifdef DEBUG
    lda DFLAG                 ; DEBUG
    bne RVPSKIP
    WCRLF_np
    lda #'P'
    jsr WRITE_CHAR            ; DEBUG
.endif

RVPSKIP:

RESFIND:                ; load last or 'latest' word on heap
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2

RESLOOP:              ; lsb linked list
    lda TEMP2
    sta WORKREG             ; so 'last' -> W
    ora TEMP2+1             ; only zero if both are zero
    bne RESEACH              ; PGS - did he forget this?  Sure did...

WORDNOTFOUND:
    lda #ERR_UKW           ; UNKNOWN WORD error
    sta ERRFLAG
    jmp errrtn ; end of dictionary, no more words to search, abort

RESEACH:                        ; msb linked list
    lda TEMP2 + 1
    sta WORKREG + 1           ; update next link

    ldx #WORKREG
    ldy #TEMP2
    jsr copyfrom                  ; W += 2, now pointing at size/flag byte from 'here'
    ldy #0              ; compare words
    lda (WORKREG), y    ; save the flag, first byte is (size and flag)
    sta STATUS + 1
            ;; *** start of mod for bit check
    and #$3F            ; mask off flags
    sec
    sbc (NXTTOK), y    ; compare lengths
    bne RESLOOP
    iny
; compare chars
RESEQUAL:
    lda (NXTTOK), y
    cmp #$20            ; space ends
    beq RESDONE
    sec                 ; verify
    sbc (WORKREG), y
    asl                 ; clean 7-bit ascii
    bne RESLOOP
    iny                 ; get next char
    bne RESEQUAL        ;  essentially 'bra' unless y is incremented past $FF

RESDONE:
    tya                ; increment W by y, W will point at CFA?
    jsr addwx

eval:
; executing ? if status = 0
    lda STATUS
    beq execute
;
; falls thru on compile, but...
; immediate ? if status+1 < 0 (bit seven set)
    lda STATUS + 1
    bmi immediate

compile:          ; otherwise compile
.ifdef DEBUG
    lda DFLAG          ; DEBUG, print C if here
    bne CMPSKIP
    WCRLF_np
    lda #'C'
    jsr WRITE_CHAR
CMPSKIP:
.endif
    jsr wcomma          ; copy W into NEXTHEAP ('here'), increment NEXTHEAP
    bcs immediate
    jmp resolve         ; if not 'immediate' go on to next token
;
immediate:
execute:

.ifdef DEBUG
    lda DFLAG         ; DEBUG, print E if here
    bne EXESKIP
    WCRLF_np
    lda #'E'
    jsr WRITE_CHAR
EXESKIP:
.endif
    lda #>resolvept     ; set up INSTPTR to run,
    sta INSTPTR + 1     ; or return to interpreter.
    lda #<resolvept
    sta INSTPTR
    jmp pick             ; almost done, 'next' and either ENTER or EXEC

;-----------------------START PROCESSING INPUT-----------------------
try:
    lda (TIB), y                   ; index is in y
    beq getline    ; if \0  - get a line if pointing at 0
    iny
    eor #$20    ; return 0 in  A if a space
    rts

;--------------------GET AN INPUT LINE ENDING WITH CR/LF ------------
getline:   ; drop rts of try, fall through to 'token'
    pla
    pla
;
;   DO AUTOLOAD HERE
;      load a space, then copy next line to buffer
;      calc y (length + 1) jump to GETLNEND
;
    lda ALFLAG
    beq GLNORMAL
    jsr ALOADTIB
    jmp GETLNSKIPCRLF

GLNORMAL:
    WSEQ_raw HYPROMPT    ; print prompt
;
    ldy #0   ; leave the first
GETLOOP:
    sta (TIB), y  ; dummy store on first pass, overwritten
    iny
    cpy TIBEND
    beq GETLNEND
    cpy #$FF
    bne GETREADLOOP
    ldy #1
GETREADLOOP:            ; character read loop
    jsr READ_CHAR_NE    ; read with no echo, so we can write back what we want
    bcc GETREADLOOP
    ;
    ;  will check here for ctrl-a,c,v,x
    jsr CTRLCHECK
    bcs GETREADLOOP
    ;
    cmp #$09         ; handle tab
    bne GETLNNOTAB
    WCRLF             ; yup, was a tab
    lda #$20          ; CRLF and indent
    jsr WRITE_CHAR
    jsr WRITE_CHAR
    jsr WRITE_CHAR
    jsr WRITE_CHAR
    jsr WRITE_CHAR
    bra GETLOOP      ; will store a space rather than tab
GETLNNOTAB:    
    jsr WRITE_CHAR    ; just write back what we got
    cmp #$0D
    beq GETLNEND
    cmp #$08         ; handle backspace
    bne GETLOOP
    dey              ; yup, backing up
    dey
    lda (TIB), y      ; make sure prev char not overwritten
    bra GETLOOP
GETLNEND:                ; clear all if y eq \0
    WCRLF                 ; macro, preserves A
GETLNSKIPCRLF:          ; SKIP to here if don't want CRLF
    lda #$20
    phy
    ldy #0
    sta (TIB), y       ; start with space
    ply
    sta (TIB), y        ; ends with space
    lda #0            ; mark eol with 0
    iny
    sta (TIB), y
    dey
; start it
    sta CURBUF

;------------------AWKWARD Brazilian english comment here...-----------
;
;    **** docs for 'token', the linchpin of the parser ***
;
; in place every token,
; the counter is placed at last space before word
; no rewinds
;
;  (i.e 'the length byte goes immediately before name of word')
;
;    to access the buffer after a line is entered, to something like...
;
;      jsr token
;      ldy #0
;      lda (NXTTOK), y       ; length will be in A
;      .... do some shit ...
;loop:
;      iny
;      lda (NXTTOK), y       ; first char of token
;      cmp #$20
;      beq done             ; if is space, token done
;      ... do some shit ...
;      bra loop             ; go get next char      
;      ... etc ....
;done:
;
token:
    ldy CURBUF   ; last position on INBUF

TOKENSKIP:   ; skip spaces
    jsr try 
    beq TOKENSKIP
    dey   ; keep y == <start of input word> + 1
    sty NXTTOK

TOKENSCAN:  ; scan spaces
    jsr try
    bne TOKENSCAN
    dey   ; keep y == <end of input word> + 1
    sty CURBUF

TOKENDONE:  ; find size and store it;
    tya
    sec
    sbc NXTTOK
    ldy NXTTOK    ; keep it
    dey
    sta (TIB), y  ; store size for counted string
    sty NXTTOK
    ;
    ;  During interpretive mode at least...do number and string capture here, before
    ;     looking at word list; will be pushed on stack.
    ;  This SHOULD have a general digit converter (any base up to 16); return C = 1 if no conversion
    ;   if SINGLE is defined, this will skip single digit numbers and use hardcoded ones.
    ;
    ;  Following check for #'s, check for quoted inline txt a la 'q^....^'
    ;
.ifdef numbers
    ldy #0
    lda (NXTTOK),y
    tax                ; store size in X, pass to conversion
    jsr DIGCONVT
    bcs CHKFERTXT       ; if some error in conversion, skip and continue processing
    bra TOKCLR0
.endif  ; 'numbers'
CHKFERTXT:
    jsr TXG3            ; TEXTGET - new version, WORKS!
    bcs TOKENEND
    ldy #0
    lda #$20
    jmp TOKCLR
TOKCLR0:
    ldy #0
    lda (NXTTOK),y     ; load length again
    tax
    inx
    lda #$20         ; copy spaces over entire converted string
TOKCLR:
    sta (NXTTOK),y
    iny
    dex
    bne TOKCLR
TOKNEXT:
    jmp token               ; and use 'token' to rebuild input buffer w/o converted #


TOKENEND:
    clc     ; clean - setup token
    rts
;
;--------------------UTILITIES----------------------------------------
;    A whole bunch of helper functions;
;  wcomma / comma increment WORKREG (or another reg) and NEXTHEAP ('here')
;  while copying into NEXTHEAP, uses incwx.
;
;  copyinto / copyfrom copy AND increment/decrement
;  spush/rpush - pushes something onto stacks indexed on ZP by Y (increment using addwx/incwx)
;  spull/rpull - pulls from stacks, copies into ZP indexed by Y (decrement builtin)
;
;  addwx/incwx/decwx do some of the inc/dec-rementing duties
;
;---------------------------------------------------------------------
;
;   COMMA allocates memory at top of heap for 'other stuff'
;   and makes sure heap and working reg pointers are updated.
;
; heap linked list (moves forward)
;
wcomma:
    ldy #WORKREG                  ; copy addr at WORKREG, change addr fld NEXTHEAP points to
comma:
    ldx #NEXTHEAP                 ; Y has source of address, change addr fld NEXTHEAP points to
    ; FALL THROUGH - copyinto, then rts after second incwx
;---------------------------------------------------------------------
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
;
copyinto:
    lda 0, y
    sta (0, x)
    jsr incwx
    lda 1, y
    sta (0, x)
    jmp incwx                        ; incwx ends with rts!
;---------------------------------------------------------------------
;
; generics - PUSH, PULL, incwx/addwx, copyfrom
;
;------------------------PUSH a cell--------------------------------
spush_2:
    ldy #TEMP3       ; push TEMP3 on top
    jmp spush
spush_1:
    ldy #TEMP2       ; push TEMP2 on top
    jmp spush
spush_0:             ; push TEMP1 to stack, probably top of stack
    ldy #TEMP1
     ; FALL THROUGH
;---------------------------------------------------------------------
; PUSH a cell
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush:
    ldx #DSPTR
    lda DSPTR
    cmp #<DS                
    beq ptrerr_s            ; DS boundary check
    jmp push
rpush:
    ldx #RTPTR
    lda RTPTR               
    cmp #<RT                ; RT boundary check
    beq ptrerr_r

    ; FALL THROUGH
;---------------------------------------------------------------------
; classic stack backwards
push:
    jsr decwx
    lda 1, y
    sta (0, x)
    jsr decwx
    lda 0, y
    sta (0, x)
    rts
;
;                      pointer error (DS or RT)
ptrerr_r:                      ; pop jsr off stack, throw error
    lda #ERR_RPTR
    bra ptrerr_cont
ptrerr_s:
    lda #ERR_SPTR
ptrerr_cont:
    sta ERRFLAG
    pla
    pla
    jmp errrtn
;
;---------------- PULL a cell, with convenience for TEMP 1/2/3 -----
;
spull_2:
    ldy #TEMP3              ; pull TEMP3 from top
    jmp spull

spull_1:                    ; pull TEMP2 from top
    ldy #TEMP2
    jmp spull

spull_0:
    ldy #TEMP1             ; pull TEMP1 from top of DS
;
;  FALL THROUGH
;
; PULL a cell
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
;
spull:
    ldx #DSPTR
    lda DSPTR         ; pointer bounds checking
    cmp #DSEND        ; ditto
    beq ptrerr_s      ; ditto
    jmp pull          ; pull includes rts from incwx so....
rpull:                ;
    ldx #RTPTR
    lda RTPTR        ; pointer bounds checking
    cmp #RTEND        ; ditto
    beq ptrerr_r        ; ditto
;
;  FALL THROUGH
;---------------------------------------------------------------------
;
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
pull:
copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx      ; NOTE:  not a jmp, returns here.
    lda (0, x)
    sta 1, y
 ;
 ;  FALL THROUGH
;---------------------------------------------------------------------
; increment a word in page zero, identified by X and offset to it from $00.
;
;   Usage: ldx #<pointer name> and then jsr incwx/addwx/decwx
;
;   THESE functions are SOLELY intended to increment/decrement
;   zeropage pointers.  Offsets indexed by
;   X are INTO the zeropage space, not relative to a specific
;   pointer location; X IDENTIFIES the 16-bit pointer in 
;   question, period.
;
incwx:
    lda #01
;---------------------------------------------------------------------
; add a byte in A to a word in page zero. X identifies the pointer
; being incremented, and is not itself dec'd or inc'd.
;
addwx:
    clc
    adc 0, x
    sta 0, x
    bcc addwx_end
    inc 1, x
    clc      ; keep carry clean.
             ; our convention is that functions SET the carry for positive results,
             ; clear carry for negative or neutral ones.
addwx_end:
    rts

;---------------------------------------------------------------------
;          decwx, heap moves
; decrement a word in page zero, identified by X and offset to it from $00.
;
;   Usage: ldx #<pointer name> and then jsr decwx
;
;   THESE functions are SOLELY intended to increment/decrement
;   zeropage pointers.  Offsets indexed by
;   X are INTO the zeropage space, not relative to a specific
;   pointer location; X IDENTIFIES the 16-bit pointer in 
;   question, period.
;
decwx:
    lda 0, x
    bne decwx_end
    dec 1, x
decwx_end:
    dec 0, x
    rts

;
;
ENGINEEND:
;                           END OF CORE ENGINE
;----------------------------------------------------------------------
;
;                        DICTIONARY and ADDITIONS
;
;    upper.s -- error messaging, CLEAR on start, debug, utilities
;------------------------------------------------------------------------
;
upper_ram:
   .include "upper.s"
;------------------------------------------------------------------------
;
;   hyf_edit.s -- the HyFedit screen editor stuff
;
   .include "hyf_edit.s"
;
;
ROMCODEEND:                         ; end of all code in OS ROM
;
;....and here's the rest:  
;       COPYTORAM, the RAM preamble, the heap, ftrain.s and bload.s
;
;------------------------------------------------------------------------
.segment "FORTH_PAGED_ROM"
;------------------------------------------------------------------------
;
;    hyf_rom.s -- COPYTORAM
;
.include "hyf_rom.s"
;
;
COPYSTART := $A100              ; marks beginning of copy in ROM space
;-----------------------------------------------------------------------
;           BELOW ENDS UP IN RAM after COPYTORAM has run
;-----------------------------------------------------------------------
.segment "FORTH_CODE"             ; at $0A00 now
RAMSTART:
    jmp forth_main             ; MAIN program start
    jmp reset
;-----------------------------------------------------------------------
;  'volatile data'...ie non-ZP, non-ROM data and code. The 'underheap'
;-----------------------------------------------------------------------       
;
;        32 bytes reserved for HyFedit (see hyf_edit.s)
;
HFE_RSV:
HFECOLS:        ; offsets to data in RAM
    .byte $40    ; 64 columns w/ $00 or $09 in rightmost
HFETSIZE:
HFEROWS:
    .byte $10    ; 16 rows - also use as length limit for title text
HFEBUF:
    .res 2       ; addr to buffer
    .res 6
HFE_TITLE:
    .byte "<-"
HFE_TTXT:          
    .byte "Generic ScreenXX" ; exactly 16 bytes
    .byte "->"
    .byte 0, 0
;--------------------------------------------------------------------
;   startup autoload?
;            load and run to 15 char command on startup
;
STARTAUTO:
   .byte " 1 lib autoload"    ; for some reason works better with a space
   .byte 0
;--------------------------------------------------------------------
;      library jump table
;
;    see ftrain.s and bload.s for examples of library format details
;
LASTLIB = 7
lib_jumptable:
    LIBENTRY (LT_FCORE + COPYSTART - RAMSTART), 0
    LIBENTRY (LT_FEXTRA + COPYSTART - RAMSTART), 0 
    LIBENTRY (LT_ANSI + COPYSTART - RAMSTART), 0 
    LIBENTRY (LT_RAMTEST + COPYSTART - RAMSTART), 0
    LIBENTRY (LT_BLOAD + COPYSTART - RAMSTART), 0
    LIBENTRY (LT_EDITTEST + COPYSTART - RAMSTART), 0
    LIBENTRY (LT_SYSVARS + COPYSTART - RAMSTART), 0
    LIBENTRY (LT_FASM + COPYSTART - RAMSTART), 0
    .res 32           ; keep 64 bytes reserved for libraries; keeping bank and extra byte now
lib_jumps_end:
;
;--------------------------------------------------------------------
;
;    error/system msg jump table  - see upper.s for ERR messages
;
LASTERR = 8
err_jumptable:
    .res 2                    ; padding for ???
    ERR_entry RPTR_ERR              ; RT stack full/empty  - error $01
    ERR_entry SPTR_ERR              ; DS stack full/empty  - error $02
    ERR_entry DIV_ERR               ; divide by zero - error $03
    ERR_entry OOM_ERR               ; out of memory  - error $04
    ERR_entry UKW_ERR               ; no existing word - error $05
    ERR_entry SEC_ERR               ; writing to dangerous RAM areas - error $06
    ERR_entry SYS_ERR               ; error on return from SYSCALL - error $07
    ERR_entry PAD_ERR               ; PAD out of memory - error $08
    .byte 0, 0, 0, 0, 0, 0   ; extra padding, dynamically add more messages
    .byte 0, 0, 0, 0, 0, 0   
    .byte 0, 0                     ; keep to 16 entries
err_jumps_end:
;    
;-----------------------------------------------------------------------
;
;   'RAMCODE' - subroutines that need to be in RAM, or at least part
;  of them.
;
;-----------------------------------------------------------------------    
;
;    FLAGSET  - 65C02 only; uses RMBx/SMBx
;     can just use RMBx / SMBx FLAGS if you know which bit...
;    but if you need to decide at runtime you need this.
;
RSBOP:
    .byte 0
    .byte FLAGS
    rts
FLAGSET:               ; bit # to chg is in X, neg bit means set
    txa
    and #$07           ; clear all bits but functional ones
    asl
    asl
    asl
    asl
    ora #$07
    cpx #$80
    bmi FGFINISH       ; will be RMBx
    ora #$80           ; will be SMBx
FGFINISH:
    sta RSBOP
    jsr WRITE_BYTE
    jmp RSBOP    
;
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
;               clear screen buffer; default is 16 rows of 63 + 1 columns
;           assembly format is two columns with 16 rows of 31 + 1 columns each
;
    lda HFEROWS
    sta TEMP5                       ; count rows from HFEROWS
    lda #<SCRBUF
    sta TEMP0
    lda #>SCRBUF
    sta TEMP0 + 1    
clrscrbuf0:
    lda #$20
    ldx HFECOLS                       ; count down from HFECOLS
    dex
    ldy #0
clrscrbuf1:
    sta (TEMP0),y
    iny
    dex
    bne clrscrbuf1               ; and last col in row is zero, so...
    lda #0                       ; all rows zero term'd but
    sta (TEMP0),y                ; don't know if really need
    lda TEMP0                    ; to clear rows this way or not, yet.
    clc
    adc HFECOLS
    bcc clrscrbuf2
    inc TEMP0+1
clrscrbuf2:
    sta TEMP0
    dec TEMP5
    bne clrscrbuf0
    rts
;
;
;
;---------------------------------------------------------------------
;        core and primitives - original AGSB hardcoded dictionary
;
;        loading order, what's where:
;
; HEAP
;    core.s
;  ----------------------------------------------------------- 
;  @ ! lit [ ] , : :$ ; ;$ I .R .S xR xS ?R ?S
;  dup swap rot over drop 0 to 9 $0 to $F %0 %1 < > <= >= = <>
;  0= bool FALSE TRUE not neg and or nand xor 
;  + - key emit ord . .be .C spc cr c! c@ words w&
;  in> >in rp sp x@ pp mp r> r> back here last
;  bye exec reset abort debug
;
;    primitives.s - memory, printing, math
;  ------------------------------------------------------------
;  var cons malloc mlen mem@ pad@ pad! xpad
;  hx2d dump .sz .rsz .psz .sn
;  * / */ max min << >> cbit sbit tbit
;
;    hywords.s - ADDITIONS, HyFedit words, ANSI, memory extras
;  -------------------------------------------------------------
;  bload cload autoload lib libs free
;  syscall disasm memcpy 
;  memw@ memwn@ wmemn! cmemn! rcmemn!
;  rand rand32 rseed Acol Aclr Ascr
;  ywrite ytest yinit
;  ferc@ fecol! ferow! felin feadd feclr fedit febuf fedisp
;  fa_mo@ fa_ms@
;
;  ---- and EXIT is always last ----
;  exit  
;
;
; ROM and ENGINE
;    upper.s
;    hyf_edit.s
;
;----------------------------------------------------------------------
;
;  The 'primitive' primitives
;
core:
.include "core.s"
;
;
;---------------------------------------------------------------------
;               must have words...
;
;---------------------ADD IN EXTRA HARDCODED LOGIC / NUMERALS
primitives:
.include "primitives.s"
;
;               ADDITIONS, HyFedit, ANSI, rand, memory extras
;
additions:
.ifdef HYWORDS
   .include "hywords.s"
.endif
;---------------------------------------------------------------------
; Thread Code Engine
;
;   INSTPTR is IP, WORKREG is W
;
;     unnest, next, pick, nest, and jump
;
;   nest aka ENTER or DOCOL  (do colon?)
;   unnest aka EXIT or semis?
;
;---------------------------------------------------------------------
; ( -- )
def_word "exit", "exit", 0
    jmp EXIT
;
;-----------------------------------------------------------------------
; BEWARE, MUST BE AT END! MINIMAL THREAD CODE DEPENDS ON IT!
;
ends:                            ; end marker of hardcoded primitives
;
;
;
.byte "***HEAPEND***"
;-----------------------------------------------------------------------
;                            SOUND DEMOS
;
.include "sound.s"
;-----------------------------------------------------------------------
;                            COMPILED LIBRARIES
;
; include training data
;
.include "ftrain.s"
;
;-----------------------------------------------------------------------
;                            BINARY LIBRARIES
;
.include "bload.s"
;
;
;-----------------------paged ROM banks ---------------------------------
;
;   Bank 1 is the current new experimental bank
;
;   Bank 2 has Hydra BASIC on it
;
.include "prom1.s"
;
;  end of hyforth.s
;