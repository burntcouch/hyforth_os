.debuginfo
.setcpu     "65C02"
.segment "BIOS_THUNKS"
;
; usually ends up at $F800 (see os_rom_C02.cfg)
;
TH_READ_CHAR:
                jmp             READ_CHAR           ; $F800
TH_WRITE_CHAR:
                jmp             WRITE_CHAR          ; $F803
TH_WRITE_BYTE:
                jmp             WRITE_BYTE          ; $F806
TH_WRITE_HEX:
                jmp             WRITE_HEX           ; $F809
TH_WRITE_HEX_MASK:
                jmp             WRITE_HEX_MASK      ; $F80C
TH_WRITE_HSTRING:
                jmp             WRITE_HSTRING       ; $F80F
TH_WRITE_CRLF:
                jmp             WRITE_CRLF          ; $F812
TH_CLEAR_SCR:
                jmp             CLEAR_SCR           ; $F815
TH_DISASM:
                jmp             DISASM              ; $F818
TH_MEMCPY:
                jmp             MEMCPY              ; $F81B
TH_MEMCPY_AY:
                jmp             MEMCPY_AY           ; $F81E
TH_DUMPREG:
                stz             <DFLAG                 ; $F821, ZP temp DFLAG
                jmp             DUMPREG
TH_next:
;                                                   ; $F826
