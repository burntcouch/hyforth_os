;
;   prom1.s
;
;   paged_rom bank 1 code and data
;
.segment "FORTH_LIB_BANK1"
FLIB_BANK1:
.byte "PROM BANK 1"
.res 5
.res $3FF0                     ; make sure these all add up to $4000, for now
;
;---------------------------------------------------
;   LOAD Hydra BASIC  - yep, it worked.
;
BASBANK = 2                   ; then Forth knows where BASIC is
BASSTART = $A000
.segment "HYBAS_BANK2"
.incbin "incbin/hydrabas.bin"  ; it is also a $4000 sized image
;
;
