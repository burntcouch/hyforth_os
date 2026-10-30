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
LT_FTRAIN:
.byte "FTRAIN"
.byte 0
.byte "C"
.byte >(ftrain_0 + COPYSTART - RAMSTART)
.byte <(ftrain_0 + COPYSTART - RAMSTART)
ftrain_0:
.byte "q^Loading ftrain libary...^ .sz"
.byte 0
.byte ": 2* dup + ;"
.byte 0
.byte ": pi* lit [ 355 , ] lit [ 113 , ] */ ;"   ; multiply by pi
.byte 0
.byte ": f* dup @ 3 + @ swap @ 5 + @ */ ;"       ; multiply times a stored constant
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
.byte ": mdump memptr 2 + @ 1 dump ;"
.byte 0
.byte ": decsz! xdrv 6 4 malloc decs! ;"
.byte 0
.byte ": | lit [ 256 , ] / ;"
.byte 0
.byte ": || lit [ 256 , ] * swap drop + ;"
.byte 0, 0                               ; to mark end?
ftrain_end0:
LT_ANSI:
.byte "ANSI"
.byte 0
.byte "C"
.byte >(ansi_col + COPYSTART - RAMSTART)
.byte <(ansi_col + COPYSTART - RAMSTART)
ansi_col:
.byte "q^Loading ANSI attribute libary...^ .sz"
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
; end of ftrain.s
;

