.debuginfo
.segment "ZEROPAGE"
.org $34
XAML  = $34                            ; Last "opened" location Low
XAMH  = $35                            ; Last "opened" location High
STOREL   = $36                            ; Store address Low
STOREH   = $37                            ; Store address High
WTEMPL     = $38                            ; Hex value parsing Low
WTEMPH     = $39                            ; Hex value parsing High
YSAV  = $3A                            ; Used to see if hex value is given
WMODE  = $3B                            ; $00=XAM, $7F=STOR, $AE=BLOCK XAM

.segment "BUFFERS"
WOZIN:                                       ; $300 ?
                .res            $100

WOZMON_E:
                LDA     #$1B           ; Begin with escape.

NOTCR:
                CMP     #$08           ; Backspace key?
                BEQ     BACKSPACE      ; Yes.
                CMP     #$1B           ; ESC?
                BEQ     ESCAPE         ; Yes.
                INY                    ; Advance text index.
                BPL     NEXTCHAR       ; Auto ESC if line longer than 127.

ESCAPE:
                LDA     #$5C           ; "\".
                JSR WRITE_CHAR

GETLINE:
                LDA     #$0D           ; Send CR
                JSR WRITE_CHAR

                LDY     #$01           ; Initialize text index.
BACKSPACE:      DEY                    ; Back up text index.
                BMI     GETLINE        ; Beyond start of line, reinitialize.

NEXTCHAR:
                JSR  READ_CHAR_NE
                BCC  NEXTCHAR
                STA     IN,Y           ; Add to text buffer.
                JSR  WRITE_CHAR
                CMP     #$0D           ; CR?
                BNE     NOTCR          ; No.

                LDY     #$FF           ; Reset text index.
                LDA     #$00           ; For XAM mode.
                TAX                    ; X=0.
SETBLOCK:
                ASL
SETSTOR:
                ASL                    ; Leaves $7B if setting STOR mode.
                STA     WMODE           ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.
BLSKIP:
                INY                    ; Advance text index.
NEXTITEM:
                LDA     IN,Y           ; Get character.
                CMP     #$0D           ; CR?
                BEQ     GETLINE        ; Yes, done this line.
                CMP     #$2E           ; "."?
                BCC     BLSKIP         ; Skip delimiter.
                BEQ     SETBLOCK       ; Set BLOCK XAM mode.
                CMP     #$3A           ; ":"?
                BEQ     SETSTOR        ; Yes, set STOR mode.
                CMP     #$52           ; "R"?
                BEQ     WRUN            ; Yes, run user program.
                STX     WTEMPL              ; $00 -> L.
                STX     WTEMPH              ;    and H.
                STY     YSAV           ; Save Y for comparison

NEXTHEX:
                LDA     IN,Y           ; Get character for hex test.
                EOR     #$30           ; Map digits to $0-9.
                CMP     #$0A           ; Digit?
                BCC     IS_DIGIT            ; Yes.
                ADC     #$88           ; Map letter "A"-"F" to $FA-FF.
                CMP     #$FA           ; Hex letter?
                BCC     NOTHEX         ; No, character not hex.
IS_DIGIT:
                ASL
                ASL                    ; Hex digit to MSD of A.
                ASL
                ASL

                LDX     #$04           ; Shift count.
HEXSHIFT:
                ASL                    ; Hex digit left, MSB to carry.
                ROL     WTEMPL              ; Rotate into LSD.
                ROL     WTEMPH              ; Rotate into MSD's.
                DEX                    ; Done 4 shifts?
                BNE     HEXSHIFT       ; No, loop.
                INY                    ; Advance text index.
                BNE     NEXTHEX        ; Always taken. Check next character for hex.

NOTHEX:
                CPY     YSAV           ; Check if L, H empty (no hex digits).
                BEQ     ESCAPE         ; Yes, generate ESC sequence.

                BIT     WMODE           ; Test MODE byte.
                BVC     NOTSTOR        ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

                LDA     WTEMPL              ; LSD's of hex data.
                STA     (STOREL,X)        ; Store current 'store index'.
                INC     STOREL            ; Increment store index.
                BNE     NEXTITEM       ; Get next item (no carry).
                INC     STOREH            ; Add carry to 'store index' high order.
TONEXTITEM:     JMP     NEXTITEM       ; Get next command item.

WRUN:
                JMP     (XAML)         ; Run at current XAM index.

NOTSTOR:
                BMI     XAMNEXT        ; B7 = 0 for XAM, 1 for BLOCK XAM.

                LDX     #$02           ; Byte count.
SETADR:         LDA     WTEMPL-1,X          ; Copy hex data to
                STA     STOREL-1,X        ;  'store index'.
                STA     XAML-1,X       ; And to 'XAM index'.
                DEX                    ; Next of 2 bytes.
                BNE     SETADR         ; Loop unless X = 0.

NXTPRNT:
                BNE     PRDATA         ; NE means no address to print.
                LDA     #$0D           ; CR.
                JSR WRITE_CHAR
                LDA     XAMH           ; 'Examine index' high-order byte.
                JSR     WRITE_BYTE        ; Output it in hex format.
                LDA     XAML           ; Low-order 'examine index' byte.
                JSR     WRITE_BYTE         ; Output it in hex format.
                LDA     #$3A           ; ":".
                JSR WRITE_CHAR

PRDATA:
                LDA     #$20           ; Blank.
                JSR WRITE_CHAR
                LDA     (XAML,X)       ; Get data byte at 'examine index'.
                JSR     WRITE_BYTE        ; Output it in hex format.
XAMNEXT:        STX     WMODE           ; 0 -> MODE (XAM mode).
                LDA     XAML
                CMP     WTEMPL              ; Compare 'examine index' to hex data.
                LDA     XAMH
                SBC     WTEMPH
                BCS     TONEXTITEM     ; Not less, so no more data to output.

                INC     XAML
                BNE     MOD8CHK        ; Increment 'examine index'.
                INC     XAMH

MOD8CHK:
                LDA     XAML           ; Check low-order 'examine index' byte
                AND     #$07           ; For MOD 8 = 0
                BPL     NXTPRNT        ; Always taken.

PRBYTE:
                PHA                    ; Save A for LSD.
                LSR
                LSR
                LSR                    ; MSD to LSD position.
                LSR
                JSR     WRITE_HEX         ; Output hex digit.
                PLA                    ; Restore A.

PRHEX:
                AND     #$0F           ; Mask LSD for hex print.
                ORA     #$30           ; Add "0".
                CMP     #$3A           ; Digit?
                BCC     ECHO           ; Yes, output it.
                ADC     #$06           ; Add offset for letter.

ECHO:
                JSR WRITE_CHAR
                RTS                    ; Return.
