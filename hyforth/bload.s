;
;  BLOAD test code
;
;  ALL binary libraries loadable with 'bload' MUST be Forth words,
;   (not jsr subroutines or jmp destinations), fully relocatable.  That means NO direct jmp/jsr's
;   to internal labels.  Indirect jmps ($6C / $7C) to local locations can be used
;   once the word is loaded, with smart code.   Branches will work fine.
;
;   jsr's and jmp's to core primitive labels (next, keeps, this, etc) or 
;   OS ROM ($E000 - $FFFF) locations will also work.
;
;   These words will be loaded into the RAM heap, so there CAN be self-modding
;   sections that will help words to configure themselves.  Be creative!
;
;  Format below must be rigidly followed, with length of name followed
;   by that many bytes for the name.  'bit #0' ($89 $00) or $22 $00 (undocumented)
;   must be the first instruction in any native code word loaded past
;   'exit'.  Termination must be $00 $00 for each word, with "END"
;   to designate the end of a 'library'.
;
;    LIBRARY header in standard format (reachable from lib_jumptable entry)
;
;    LT_xxxx label, followed by 'sz' string, followed by 'C' or 'B' type
;    ..and then calculated ROM address of start of first loadable word, bigendian.
;
LT_BLOAD:
.byte "BLOAD"
.byte 0
.byte "B"
.byte >(bload0 + COPYSTART - RAMSTART)
.byte <(bload0 + COPYSTART - RAMSTART)
bload0:
;
.byte 6           ; length of name
.byte "BLtest"
     .byte $22
     .byte 0
     WCRLF
     lda #'T' 
     jsr WRITE_CHAR
     lda  #'E' 
     jsr WRITE_CHAR
     lda  #'S' 
     jsr WRITE_CHAR
     lda  #'T' 
     jsr WRITE_CHAR
     WCRLF
     jmp next
.byte 0, 0
.byte 7           ; length of name
.byte "BLtest2"
     .byte $22
     .byte 0
     WCRLF
     lda #'T' 
     jsr WRITE_CHAR
     lda #'E'
     jsr WRITE_CHAR
     lda #'S'
     jsr WRITE_CHAR
     lda #'T' 
     jsr WRITE_CHAR 
     lda #'Y'  
     jsr WRITE_CHAR
     WCRLF
     jmp next
.byte 0, 0
.byte "END"                  ; required to end library!
bload0_end: