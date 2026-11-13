.debuginfo
.segment "SHELL"

SHELL_MAIN:
             jsr COPYTORAM                  ; COPYTORAM
             jmp RAMSTART                   ; forth_main -> F_cold
 ;           jsr     MON_START