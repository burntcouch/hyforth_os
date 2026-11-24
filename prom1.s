;
;   prom1.s
;
;   paged_rom bank 1 code and data
;
.segment "FORTH_LIB_BANK1"
FLIB_BANK1:
.byte "PROM BANK 1"
.res 5
.res $3FF0
;
;---------------------------------------------------
;   LOAD Hydra BASIC  - yep, it worked.
;
BASBANK = 2
.segment "HYBAS_BANK2"
.incbin "incbin/hydrabas.bin"
;
;
