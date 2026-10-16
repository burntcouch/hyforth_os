.debuginfo
.macpack        cpu
.setcpu     "65C02"

.include "defines.s"
.include "zero.s"                          ; this should always be after defines.s
                                           ;
                                           ; I want these HERE so I can easily change the banner to reflect the
                                           ; latest version.
.segment "BIOS"
NamedHString HYDRA_WELCOME, "HYDRA-16 v1.8Da.01"          ; 10/15/26 <- update the date!

.include "bios.s"
.include "thunks.s"
;.include "math.s"
;.include "tasks.s"
.include "disasm.s"
.include "hyforth/hyforth.s"
.include "wozmon.s"
;.include "mmu.s"
.include "shell.s"
.include "sound.s"
.include "os_main.s"
