.debuginfo

.segment "BIOS_P0"
;
; usually ends up at $E000 (see os_rom_C02.cfg)
;
RESET_VECTOR_START:
            lda     #0                    ; ZERO the W register
            sta     W_REGISTER
            cld                                                     ; We don't like decimal mode
            sta                 T_REGISTER                          ; Make sure task 0 is selected
            sta                 $00                                 ; Init RAM Bank selector
            sta                 $01                                 ; Init ROM Bank selector
            ldx                 #$FF                                ; Init stack pointer
            txs
            lda                 ZP_READ_PTR
            sta                 ZP_WRITE_PTR           ; remove when tasks_init is used

            jsr                 IRQ_VECTOR_INIT
            ;jsr                 TASKS_INIT                          ; Must be called before SERIAL_INIT and MMU_INIT
            ;jsr                 MMU_INIT
            jsr                 VIA_INIT
            ;jsr                 SPI_INIT
            jsr                 SOUND_INIT
            jsr                 SERIAL_INIT
            ;jsr                 SPI_TEST
            ;jsr                 SOUND_TEST
            jsr                 DO_WELCOME
            jmp                 SHELL_MAIN

DO_WELCOME:
            jsr                 CLEAR_SCR
            lda             #<HYDRA_WELCOME
            ldy             #>HYDRA_WELCOME
            jsr             WRITE_HSTRING
            PRINT_CRLF
            ldx     #0

@vector_loop:
            stx                 V_REGISTER
            phx
            PRINT_HEX           V_REGISTER
            PRINT_CHAR          #$08
            lda                 V_REGISTER
            PRINT_HEX
            PRINT_CHAR          #':'
            PRINT_BYTE          $FFFF
            PRINT_BYTE          $FFFE
            PRINT_SPACE
            plx
            inx
            cpx                 #$10
            bcc                 @vector_loop
            PRINT_CRLF_JMP

SPI_TEST:
            ldx                 #SPI_DEV_0
            jsr                 SPI_INIT_DELAY
            SPI_SEND_CMD        0, 0, 0, 0,   0, $4A                ; CMD0
            SPI_SEND_CMD        8, 0, 0, 1, $AA, $43                ; CMD8
SPI_T_LOOP:
            SPI_SEND_CMD        58, 0, 0, 0,   0                    ; CMD58
            SPI_SEND_CMD        41, $40, 0, 0,   0                  ; ACMD41
            bne                 SPI_T_LOOP
            rts

; A: S/W interrupt number
SW_INT:
            asl                                                     ; move int# to V[4..7]
            asl
            asl
            asl
            ora                 #$F
            sta                 V_REGISTER
            brk                                                     ; force an interrupt
            rts

.macro OTHER_PAGE_FILLER
            lda     #0                                              ; zero out W register
            sta     W_REGISTER
            .res                $1FF2, $EA
            jmp                 RESET_VECTOR_START
.endmacro

.segment "BIOS_P1"
            OTHER_PAGE_FILLER
.segment "BIOS_P2"
            OTHER_PAGE_FILLER
.segment "BIOS_P3"
            OTHER_PAGE_FILLER
.segment "BIOS_P4"
            OTHER_PAGE_FILLER
.segment "BIOS_P5"
            OTHER_PAGE_FILLER
.segment "BIOS_P6"
            OTHER_PAGE_FILLER
.segment "BIOS_P7"
            OTHER_PAGE_FILLER
.segment "BIOS_P8"
            OTHER_PAGE_FILLER
.segment "BIOS_P9"
            OTHER_PAGE_FILLER
.segment "BIOS_PA"
            OTHER_PAGE_FILLER
.segment "BIOS_PB"
            OTHER_PAGE_FILLER
.segment "BIOS_PC"
            OTHER_PAGE_FILLER
.segment "BIOS_PD"
            OTHER_PAGE_FILLER
.segment "BIOS_PE"
            OTHER_PAGE_FILLER
.segment "BIOS_PF"
            OTHER_PAGE_FILLER
