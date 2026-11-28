;
;  training data
;
;
;    LIBRARY header in standard format (reachable from lib_jumptable entry)
;
;    LT_xxxx label, followed by 'sz' string, followed by 'C' or 'B' type
;    ..and then calculated ROM address of start of library, bigendian.
;
;    Library entries can be ':' definitions or regular commands. 
;
;   the 'sys_word' macro only works with names that are 'defined' labels
;    i.e. NOT labels for actual physical addresses.   LBLX = <number> vs LBLX:
;
.macro sys_word name
makelabel "sv_", name
  .byte .sprintf( "%i cons s_%s", .ident (name), name )
  .byte 0
.endmacro
;
;
LT_FCORE:
.byte "FCORE"
.byte 0
.byte "C"
.byte >(ftrain_0 + COPYSTART - RAMSTART)
.byte <(ftrain_0 + COPYSTART - RAMSTART)
ftrain_0:
.byte "q^Loading Forth core library...^ .psz"
.byte 0
.byte ": ?branch bool not rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;  : branch rp @ @ dup @ + rp @ ! ;"
.byte 0
.byte ": if lit ?branch , here @ 0 , ; I"
.byte 0
.byte ": endif dup here @ swap - swap ! ; I"
.byte 0
.byte ": else lit branch , here @ 0 , swap dup here @ swap - swap ! ; I"
.byte 0
.byte ": begin here @ ; I"
.byte 0
.byte ": again lit branch , here @ - , ; I"
.byte 0
.byte ": until lit ?branch , here @ - , ; I"
.byte 0
.byte ": while lit ?branch , here @ 0 , ; I"
.byte 0
.byte ": repeat swap lit branch , here @ - , dup here @ swap - swap ! ; I"
.byte 0
.byte ": do here @ lit >r , lit >r , ; I"
.byte 0
.byte ": loop lit r> , lit r> , lit lit , 1 , lit + , lit 2dup , lit = , lit ?branch , here @ - , lit 2drop , ; I"
.byte 0
.byte ": i rp @ 4 + @ ;  : j rp @ 8 + @ ;  : k rp @ lit [ 12 , ] + @ ;"
.byte 0
.byte " 7 lib autoload"           ; chain to 'sysvars' library
.byte 0, 0                           
ftrain_end0:
;
LT_FEXTRA:
.byte "FEXTRA"
.byte 0
.byte "C"
.byte >(f_extra + COPYSTART - RAMSTART)
.byte <(f_extra + COPYSTART - RAMSTART)
f_extra:
.byte "cr q^Loading extras library...^ .psz xR"
.byte 0
.byte ": pdump pad@ begin @ dup while dup dup .be lit [ $2D , ] emit .psz cr repeat ;"
.byte 0
.byte ": pp- pp @ @ dup not if pp ! endif ;"
.byte 0
.byte ": mp- mem@ dup s_MSBUF s_MEMEND + <> if 2 + mp ! else drop endif ;"
.byte 0
.byte ": prun pad@ @ dup not if 3 + cload endif drop ;"
.byte 0
.byte ": 2* dup + ;"
.byte 0
.byte ": pi* lit [ 355 , ] lit [ 113 , ] */ ;"   ; multiply by pi
.byte 0
.byte ": f* dup @ 3 + @ swap @ 5 + @ */ ;"       ; multiply times a stored constant
.byte 0
.byte ": mdump mem@ 2 + @ 1 dump ;"
.byte 0
.byte ": | lit [ 256 , ] / ;"
.byte 0
.byte ": || lit [ 256 , ] * swap drop + ;"
.byte 0
.byte ": ny|| swap lit [ 16 , ] * swap drop + ;"
.byte 0
.byte ": wny|| ny|| rot rot ny|| || ;"
.byte 0
.byte ": sz@ 1 + 2 * mem@ + @ 3 + ;"           ; obtain address for a string on mem stack
.byte 0
.byte ": feget 0 swap felin pad! ; "
.byte 0
.byte "cr q^Free Memory: ^ pad@ @ .psz free hx2d pad@ @ .psz xS xpad"
.byte 0, 0
f_extra_end:
;
LT_ANSI:
.byte "ANSI"
.byte 0
.byte "C"
.byte >(ansi_col + COPYSTART - RAMSTART)
.byte <(ansi_col + COPYSTART - RAMSTART)
ansi_col:
.byte "q^Loading ANSI attribute library...^ .psz"
.byte 0
.byte "30 cons Ablk 31 cons Ared 32 cons Agrn 33 cons Aylw 34 cons Ablu 35 cons Amag xS"
.byte 0
.byte "36 cons Acya 37 cons Awht" 
.byte 0
.byte "1 cons A_bon 22 cons A_boff"
.byte 0
.byte "21 cons A_duon 2 cons A_lton xS"
.byte 0
.byte "3 cons A_ion 23 cons A_ioff"
.byte 0
.byte "4 cons A_uon 24 cons A_uoff"
.byte 0
.byte "5 cons A_kon 25 cons A_koff"
.byte 0
.byte "7 cons A_von 27 cons A_voff"
.byte 0
.byte "9 cons A_ston 29 cons A_stoff xS"
.byte 0
.byte ": A_back $A + ;"
.byte 0
.byte ": A_norm 0 Acol ;"
.byte 0, 0
ansi_col_end:
LT_RAMTEST:
.byte "RAMTEST"
.byte 0
.byte "C"
.byte >(hyramtests + COPYSTART - RAMSTART)
.byte <(hyramtests + COPYSTART - RAMSTART)
hyramtests:
.byte ": srbank 0 c! ;"
.byte 0
.byte ": .srbank c@ lit [ 48 , ] + emit ;"
.byte 0
.byte ": sramd lit [ $8000 , ] + swap dump ;"
.byte 0
.byte ": sramw lit [ $8000 , ] + c! ; "
.byte 0
.byte ": sramr lit [ $8000 , ] + c@ ; "
.byte 0
.byte 0,0
hyramtests_end:
LT_EDITTEST:
.byte "EDITTEST"
.byte 0
.byte "C"
.byte >(edittest + COPYSTART - RAMSTART)
.byte <(edittest + COPYSTART - RAMSTART)
edittest:
.byte "This is a test "
.byte 0
.byte " Yeah a test "
.byte 0
.byte "  What a test! "
.byte 9
.byte "   What a test! "
.byte 9
.byte "    What a test! "
.byte 9
.byte "     sez Pat...woot, woot, I fuguered this out?   Yez.  "
.byte 9
.byte 0,0,0,0,0,0,0,0,0,0
.byte 0,0
edittest_end:
;
LT_SYSVARS:
.byte "SYSVARS"
.byte 0
.byte "C"
.byte >(sysvars + COPYSTART - RAMSTART)
.byte <(sysvars + COPYSTART - RAMSTART)
sysvars:
.byte "cr q^Loading system variables...^ .psz xR"
.byte 0
sys_word "MEMTOP"
sys_word "MSBUF"
sys_word "MEMEND"
sys_word "PADBUF"
sys_word "SCRBUF"
sys_word "MEMLAST"
;
;    examples of how to inject labeled memory addresses (which aren't available in macros) 
;
.byte "$"
.byte ((.hibyte(next) / 16) <= 9 ) * ((.hibyte(next) / 16) | $30) + ((.hibyte(next) / 16) > 9 ) * ((.hibyte(next) / 16) + $37)
.byte ((.hibyte(next) & $0F) <= 9 ) * ((.hibyte(next) & $0F) | $30) + ((.hibyte(next) & $0F) > 9 ) * ((.hibyte(next) & $0F) + $37)
.byte ((.lobyte(next) / 16) <= 9 ) * ((.lobyte(next) / 16) | $30) + ((.lobyte(next) / 16) > 9 ) * ((.lobyte(next) / 16) + $37)
.byte ((.lobyte(next) & $0F) <= 9 ) * ((.lobyte(next) & $0F) | $30) + ((.lobyte(next) & $0F) > 9 ) * ((.lobyte(next) & $0F) + $37)
.byte " cons s_next"
.byte 0
.byte "$"
.byte ((.lobyte(TEMP2) / 16) <= 9 ) * ((.lobyte(TEMP2) / 16) | $30) + ((.lobyte(TEMP2) / 16) > 9 ) * ((.lobyte(TEMP2) / 16) + $37)
.byte ((.lobyte(TEMP2) & $0F) <= 9 ) * ((.lobyte(TEMP2) & $0F) | $30) + ((.lobyte(TEMP2) & $0F) > 9 ) * ((.lobyte(TEMP2) & $0F) + $37)
.byte " cons s_T2"
.byte 0
.byte "0 cons os_Z0"
.byte 0
.byte "1 cons os_Z1"
.byte 0
.byte "$FFF0 cons os_T"
.byte 0
.byte "$FFF1 cons os_U"
.byte 0
.byte "$FFF2 cons os_V"
.byte 0
.byte "$FFF3 cons os_W  xS"
.byte 0
.byte " 2 lib autoload "                       ; chain to 'extras' library
.byte 0,0
sysvars_end:
;
LT_FASM:
.byte "FASM"
.byte 0
.byte "C"
.byte >(fasm + COPYSTART - RAMSTART)
.byte <(fasm + COPYSTART - RAMSTART)
fasm:
.byte "cr q^Loading Fasm...^ .psz xR"
.byte 0
.byte "var {org} drop"                      ; origin addr of program
.byte 0
.byte "var {curr} drop"                     ; current code append pointer
.byte 0
.byte "var {fat1} drop"                     ; temp variable 1 for fasm
.byte 0
.byte "var {fat2} drop"                     ; temp variable 2 for fasm
.byte 0
.byte ": +{curr} {curr} @ + {curr} ! ;"                  ; advance {curr} by n
.byte 0
.byte ": !{curr} {curr} @ c! 1 +{curr} ;"               ; save byte at {curr} and advance 1
.byte 0
.byte ": !w{curr} {curr} @ ! 2 +{curr} ;"               ; save word at {curr} and advance 2
.byte 0
.byte ": {_new lit [ $9000 , ] dup {org} ! {curr} ! ;"   ; clear {org} and {curr}
.byte 0
.byte ": {_run {org} @ xjsr ;"                           ; run a loaded program (it had better end with RTS)
.byte 0
.byte ": {_list {org} @ 1 dump ;"                        ; list loaded program
.byte 0
.byte ": {_dis {org} @ lit [ 10 , ] disasm ;"                        ; disasm on loaded program
.byte 0
.byte ": {_ip0a {_mnsz@ pad@ @ 3 + 3 insz ;"             ; pass 0a - lookup offset from mnemoic string
.byte 0
.byte ": {_ip0b {_mno@ bin& ;"                            ; pass 0b - lookup base op code from offset
.byte 0
.byte ": {_ip0c pad@ @ 6 + {_asz& {_bop& dup {fat1} ! ;"   ; pass 0c - lookup addr mode from mode string
.byte 0
.byte ": {_ip0d pad@ @ 3 + {_opa& ;"                      ; pass 0d - lookup final op code from mode and base op
.byte 0
.byte ": {_ip& xS {_ip0a {_ip0b {_ip0c dup 2 = if {_ip0d swap drop swap else dup 3 = if {_ip0d rot drop rot else drop endif endif ;"
.byte 0                                                   ; process parm list, collapse and rearrange to load
.byte ": {_ld+ {fat1} @ 0 do !{curr} loop ;"             ; load to memory (assumes parms and op code in order on stack) 
.byte 0
.byte 0,0
FA_OPLOOKUP:                                     ; about 263 bytes as of 11/20/26
;
; ADDRESS MODES
;  0 - A            A  -(1)
;  1 - #            n  -(2)
;  2 - (zp, x)      ix -(2)
;  3 - (zp), y      iy -(2)
;  4 - (zp)         iz -(2)
;  5 -  zp          z  -(2)
;  6 -  zp, x       zx -(2)
;  7 -  zp, y       zy -(2)
;  8 -  a, y        ay -(3)
;  9 -  a           a  -(3)
;  A -  a, x        ax -(3)
;  B - indirect     i  -(3)
;  C - indirect     ia -(3)
;
;------------------
;
;   8 opcode FAMILY tables.  **NOTE*** all subtables end with $03, which is not a valid opcode.
;    $03 is used to detect end of one table and switch to next.
;    $03, $03 is end of table.
;
;   14 x 14 bytes addressing mode / size table, so line terminations unnecessary
;
;   addr mode 0 is 1 byte, 1 to 7 are 2 bytes, 8 to C are 3 bytes
;
;   sng1, sng3 have none or one address mode
;
;   A, n, ix, iy, iz, z, zx, zy, ay, a, ax, i, ia are all SUFFIX's used on opcodes...so
;     e.g. instead of LDA ($XXXX),y  you will say 'LDAiy XXXX'.
;   Other examples
;     INC A ==> INCA
;     BIT #$45 ==> BITn 45
;     JMP (:00),x will be JMPia :00
;
;     but...BCC :B3 ==> BCC :B3  (before offset calculations)
;
;   ..and so on.
;
;    FULL PROGRAM EXAMPLE
;
;    .org 800
;    :80 F803   ( WRITE_CHAR )
;    :81 F0     ( TEMP1 )
;    :82 F1     ( TEMP1+1 )
;
;    JSR :00                 ( jump to start )
;    :01
;    .byte 41 42 43 44 00    (ABCD, zero term'd)
;    :00
;    LDAn <:01             ( top byte of address) 
;    STAz :81               ( TEMP1 in Forth )
;    LDAn >:01             ( bottom byte)
;    STAz :82              ( TEMP1+1 in Forth )
;    LDYn 00
;    :02                   ( top of loop )
;    LDAiy F0
;    JSR :80               ( print character )
;    BNE :02               ( branch to top of loop )
;    RTS
;
; ----------------------------
;   So...in HyForth itself you'd do something like this after startup:
;
;  HF> 10 lib autoload  ( load FASM library )
;  HF> feclr      ( clear screen buffer )
;  HF> fa+ .org 800
;  HF> fa+ :80 F803 ( WRITE CHAR )
;  ....
;  HF> fa+ RTS
;  HF> faasm      ( well, just do it, store in buffer )
;  HF> faload     (  put it in memory from buffer )
;  HF> $800 1 disasm
;
;  [ DISASM output of page at $800 ]
;
;
;   A bit Forthy and astringent, I agree, but....
;
;
;   PROCEDURE:
;      lookup mnemonic in MN_STRING to find offset table value
;      lookup offset value in MN_OFFSETS to get 'base' mnemonic op code
;      lookup 'base' code from MN_OFFSETS table in FAMILY tables FA_sng1, sng3, mb, br, tba, mma, mmb
;         if not there, look through first byte of addr sequence (STZ thru JMP)
;         this will give you the 'base family' code
;      SAVE base family code appearing in table where found
;      lookup address mode in corresponding row using base family code
;      ADD value in that row/column to mnemonic 'base' opcode (not base family code)
;      This should be correct OPCODE
;      
;      BYTES:  table sng1 and address mode 'A' (index 0) are single byte codes
;              tables mb, br, and modes 1 thru 7 are 2 byte codes
;              table sng3 and modes 8 thru C are 3 byte codes
;
;      BRANCHES:  note when opcode found and mark 'relative' byte with $00 or $FF until
;            label offset calculated and filled in.  BBR / BBS opcodes will also have to be adjusted
;            based on what digit follows mnemonic, e.g. (BBR lookup yields $0F, BBR6 requires
;            adding $60 to $0F...)
;
;      RMB/SMB:  these OPCODES will also have to be adjusted based on following digit
;
;--------------------- 34
;                           SZ TO ADDESS MODE
; 
FA_amtable1 = FA_xamt1 + COPYSTART - RAMSTART
FA_amtable2 = FA_xamt2 + COPYSTART - RAMSTART
FA_ops = FA_xops + COPYSTART - RAMSTART
FA_addr = FA_xaddr + COPYSTART - RAMSTART
FA_anofam = FA_xopnofam + COPYSTART - RAMSTART

FA_xamtablen1 = 10
FA_xamtablen2 = 24
FA_xamt1:
    .byte $41,0        ; A
    .byte $61,9        ; a
    .byte $69,11       ; i
    .byte $6E,1        ; n
    .byte $7A,5        ; z
FA_xamt2:
    .byte $61,$78,10   ; ax
    .byte $61,$79,8    ; ay
    .byte $69,$61,12   ; ia
    .byte $69,$78,2    ; ix
    .byte $69,$79,3    ; iy
    .byte $69,$7A,4    ; iz
    .byte $7A,$78,6    ; zx
    .byte $7A,$79,7    ; zy
;--------------------- 49
;                               OPCODE FAMILY
;
FA_FAMCNT = 6
FA_xops:
FA_sng1:                                         ; all single byte instructions
 .byte $00, $08, $18, $28, $38, $40, $48
 .byte $58, $5A, $60, $68, $78, $7A, $88, $8A, $98, $9A
 .byte $A8, $AA, $B8, $BA, $C8, $CA, $CB, $D8, $DA, $DB, $E8, $EA, $F8, $FA, 3
FA_sng3:  .byte $20, 3                           ; JSR  3 bytes
;FA_mb:  .byte $07, $87, 3                        ; RMB, SMB  2 bytes
FA_br:  
 .byte $0F, $10, $30, $50, $70                   ; all branch instructions
 .byte $80, $8F, $90, $B0, $D0, $F0, 3           ; 2 bytes
;------------------
;   below have multiple address modes
;
;-------------------- 18
FA_tba:                                          ; TBR, TBS
 .byte $04, $14, 3
FA_mma:                                          ; ORA, AND, EOR, ADC, STA, LDA, CMP, SBC
 .byte $01, $21, $41, $61, $81, $A1, $C1, $E1, 3
FA_mmb:                                          ; ASL, ROL, LSR, ROR
 .byte $06, $26, $46, $66, 3
FA_opend:
 .byte 3
;------------------- 196
;                              ADDRESS MODES
;
;       op   A    n    ix   iy   iz   z   zx   zy    ay   a   ax   i    ia
FA_AMRLEN = 14
FA_xaddr:
FA_tbaa:
 .byte $04, $FF, $FF, $FF, $FF, $FF, $00, $FF, $FF, $FF, $08, $FF, $FF, $FF
FA_mmaa: 
 .byte $01, $FF, $08, $00, $10, $11, $04, $14, $FF, $18, $0C, $1C, $FF, $FF
FA_mmba:
 .byte $06, $04, $FF, $FF, $FF, $FF, $00, $10, $FF, $FF, $08, $18, $FF, $FF
FA_xopnofam:
FA_STZ:
 .byte $64, $FF, $FF, $FF, $FF, $FF, $00, $10, $FF, $FF, $38, $3A, $FF, $FF
FA_LDX:
 .byte $A2, $FF, $00, $FF, $FF, $FF, $04, $FF, $14, $1C, $0C, $FF, $FF, $FF
FA_LDY:
 .byte $A0, $FF, $00, $FF, $FF, $FF, $04, $14, $FF, $FF, $0C, $1C, $FF, $FF
FA_CPX:
 .byte $E0, $FF, $FF, $FF, $FF, $FF, $04, $FF, $FF, $FF, $0C, $FF, $FF, $FF
FA_CPY:
 .byte $C0, $FF, $FF, $FF, $FF, $FF, $04, $FF, $FF, $FF, $0C, $FF, $FF, $FF
FA_STX:
 .byte $86, $FF, $FF, $FF, $FF, $FF, $00, $FF, $10, $FF, $08, $FF, $FF, $FF
FA_STY:
 .byte $84, $FF, $FF, $FF, $FF, $FF, $00, $10, $FF, $FF, $08, $FF, $FF, $FF
FA_INC:
 .byte $1A, $00, $FF, $FF, $FF, $FF, $CC, $DC, $FF, $FF, $D4, $E4, $FF, $FF
FA_DEC:
 .byte $3A, $00, $FF, $FF, $FF, $FF, $8C, $9C, $FF, $FF, $94, $A4, $FF, $FF
FA_BIT:
 .byte $24, $FF, $65, $FF, $FF, $FF, $00, $10, $FF, $FF, $08, $18, $FF, $FF
FA_JMP:
 .byte $4C, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $FF, $20, $30
 .byte 0     ; backstop at end
fasm_end:
;
; end of ftrain.s
;

