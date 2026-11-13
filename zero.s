.debuginfo

.zeropage
RAM_BANK_REG:                          ; pretty important considering lack of 
    .res  1                            ; commenting.  Switches, in tandem with W, the 8K shared-RAM banks
ROM_BANK_REG:                          ; select one of the 16K ROM banks, up to 256 depending on 
    .res  1                            ; installed 
;
; reserved, but not used
;
ZP_RESERVE:
    .res  1  ; STACK_SAVE_REG:
    .res  1  ; TASK_STATUS_REG:
    .res  1  ; TASK_PARENT:
    .res  1  ; TASK_SAVE_REG:
;
ZP_READ_PTR:
    .res  1
ZP_WRITE_PTR:
    .res  1
ZP_SER_SEND_STATUS:
    .res  1
ZP_TEMP:
    .res  1
ZP_TEMP_2:
    .res  1
ZP_SPI_DATA_IN:
    .res  1
ZP_SPI_DATA_OUT:
    .res  1
;
;                       ZP_xxxx_VECx locations used for MEMCPY and Yamaha sound stuff
;
MC_SRCA:                 ; MEMCPY source address
AZP0L:                   ; YM sound init
ZP_TEMP_VEC:             
    .res  1
AZP0H:
    .res  1
MC_ENDA:                 ; MEMCPY end address of source
YMTMP1:
ZP_TEMP_VEC2:            ; also used for YM sound init and tests
    .res  1
YMTMP2:
    .res  1
MC_DEST:                 ; MEMCPY destination address
YMN0L:
ZP_TEMP_VEC3:            ; also used for YM sound init and tests
    .res  1
YMN0H:
    .res  1
YMN1L:
ZP_TEMP_VEC4:            ; also used for YM sound init and tests
    .res  1
YMN1H:
    .res  1
; 
;    
;    
ZP_A_SAVE:
    .res  1
ZP_X_SAVE:
    .res  1
ZP_Y_SAVE:
    .res  1
ZP_T_SAVE:
    .res  1
ZP_U_SAVE:
    .res  1
ZP_V_SAVE:
    .res  1
ZP_W_SAVE:
    .res  1

;  BIOS
ZP_HS_TEMP:
    .res  2

;  WOZMON
ZP_WM_ST:
    .res  2      ; store address for WozMon
ZP_WM_XAM:
    .res  2      ; current 'examined' address
ZP_WM_HVP:
    .res  2      ; Hex Value Parsing
ZP_WM_MODE:
    .res  1      ; $00=ZP_D_XAM, $7F=STOR, $AE=BLOCK ZP_D_XAM

; DISASM
ZP_D_STATE:
    .res    1        ; op codes only or mnemonics
ZP_D_EXBYTES:
    .res    1
ZP_D_INST:
    .res    3
ZP_D_MODE:
    .res   1
ZP_D_XAM:
    .res    2       ; eXAMine address
;ZP_D_ICOUNT:       ; instruction count - removed need for this 11/1/26
;    .res    1


;
;  end of zero.s
;