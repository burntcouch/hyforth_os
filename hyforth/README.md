# HyForth for 6502
<h2>Hydra-16 version of MilliForth</h2>
----------------------------------------------------------------------
<p>
  Patrick Struthers - March 2026
<p>
      - THANKS to AGSB (https://github.com/agsb) for the starting point here....<p>
   MilliForth 6502 --> (https://github.com/agsb/milliForth-6502)
<p>
----------------------------------------------------------------------

<h3>INSTALLATION:</h3>
<p>This is (STILL) a very simple system, by design, so....it is a little bit messy to set up and use.  But we're getting there...</p>

<p>Essentially, we want to generate a RAM image of the running HyForth image at $0A00 by switching to the ROM, running the COPYTORAM routine (at approximately $A000), then starting HyForth at $0A00 through WozMon.  The input buffer stack (TIB) is the entire page at $0400, with the DS and RT stacks splitting $0500-$05FF.  Currently the end of the hardcoded word dictionary runs from $0A60 to about $2200, with user-compiled words extending above that.</p>

<p>If you are just using the Hydra-16 simulator (included in the project in the ./sim folder) then you can use the rom images created with the cc65 'make' and '.cfg' files to create the OS-ROM and paged-ROM images with no trouble; if actually have Hydra-16 hardware....</p>

<p>The Hydra-16 maps ROM chips into one of 256 16K banks, any one of which will show up at $A000 depending on the selected bank.  These are selected by putting the bank # at zeropage address $01...more or less.  The 'more' is that they work, the 'less' is that you have to find the bank.  Due to a flaw in the design of the 1.8C vesion of Hydra-16 (only one with extant hardware), you have to offset the upload of your ROM image by $2000, and then copy any data that spills over <base address + $4000> back to the $0000 offset of your base address for the bank.</p>

<p>Example:  My port of MSBASIC is approximately 11K at this point; if I am loading it in the first bank on the first ROM chip, I use Xgpro to load the binary at $2000, and then I cut and paste $4000 to ~ $5C00 to $0000 on the ROM.  If this is done carefully the code will mate together fine when it is plugged in.  If you make sure $00 is loaded to ZP $01 then your code will start in ROM at $A000.</p>

<p>HyForth itself...as of November 2026 it is very stable, and most of the described features work as described.  I added a lot of comments and debugging code to discover the various problems with the port from AGSB's milliforth original, and renamed many of the ZP variable labels and jump/branch points for more clarity.  Needless to say it is no longer 100% 'classic', according to AGSB's interpretation of Forth design standards.</p>

<p>One of the most difficult issues with the original source, is that AGSB assumes that the zero page and the page for the TIB (text input buffer at $0400, labeled INBUF in this version) to be preset to $00.  He also expected the zero-page area ($E0-$FF) used for most of the variables in this version to start at zero....So I wrote a routine (since I was using a ROM routine to copy the Forth binary to $0A00 anyway) to clear the zero page Forth area (approx $A0 - $FF), the input buffer, and the stacks.</p>

=======================================================================

<p>'Training data' for HyForth refers to the extra compiled words required for HyForth to have true conditional and looping structures.  Currently these words are loadable as a library using the 'autoload' and 'bload' words.  When HyForth boots you will see a list of loadable libraries and the Forth 'core' is the first of these.  if/else/endif, do/loop, and begin/while/until/repeat are included in the core along with some support words for these.</p>

=======================================================================

<h3> What IS HyForth?</h3>
-----------------------------------
<pre>
HyForth 0.930 11-12-2026
FCORE-C B763
FEXTRA-C BA08
ANSI-C BB20
RAMTEST-C BCAF
BLOAD-B BDF5
EDITTEST-C BD56

HF>
</pre>
-----------------------------------
<p>HyForth is a direct descendant of Alvaro G. S. Barcellos' MilliForth project.  AGSB intended MilliForth to be small enough to easily fit on a memory contstrained  8-bit SBC.  Size rather than efficiency was the intention, and the original MilliForth assembled image ran in as little as 400 bytes of RAM on the 6502.  The '02 is a good target for this kind of project because of its small, RISC-like instruction set and the 'zeropage' RAM area that almost acts like a set of 256 high-speed registers.</p>

<p>MilliForth has a very small core of basic Forth words; just enough functionality to 'meta-compile' almost any other traditional Forth 'word' using that core.  HyForth uses the same interpret/compile/execute engine as MilliForth, with considerable alterations, but the current engine is still ~ 1100 bytes.  Unlike the original MilliForth, the HyForth engine has minimal bounds checking, error capture and messaging, connection points for libraries, a screen editor, and text and number capture.</p>

<p>The HyForth 'heap', on the other hand, is quite a bit larger than the MilliForth one.  Many of the 'training' or meta-compiled words are now hard-coded into 6502 binaries, with the exception of the condtional and loop structures.  The traditional stack manipulation words like 'dup', 'swap', 'over', 'rot' are now hard-coded, along with a great many core functions like 'lit' (LITERAL), 'var' (VARIABLE) and 'cons' (CONSTANT).</p>

<p>HyForth words can be roughly tossed into four categories:  critical/core (AGSB core), primitive, standard Forth, and 'additional'.</p>
-------------LIST OF CURRENT FORTH WORDS-----------------------
<pre>
 1F17: exit       | 1EFC: ferc@      | 1EE9: fecol!     | 1ED6: ferow!     |
 1EA0: felin      | 1E73: feadd      | 1E65: feclr      | 1E06: fedit      |
 1DDC: febuf      | 1DCD: fedisp     | 1DB6: fa_mo@     | 1D9F: fa_ms@     |
 1D84: ywrite     | 1D76: ytest      | 1D68: yinit      | 1D55: mlen       |
 1D3D: malloc     | 1D00: syscall    | 1CAC: disasm     | 1C92: free       |
 1C60: memcpy     | 1C4E: xdrv       | 1BB4: */         | 1B69: /          |
 1B35: *          | 1B1A: max        | 1AED: min        | 1AC8: rand32     |
 1ABB: rand       | 1A9A: rseed      | 1A7D: Acol       | 1A50: Ascr       |
 1A43: Acls       | 19B5: bload      | 1952: cload      | 1935: autoload   |
 18D9: snip       | 18A5: pick       | 1878: 2over      | 1867: 2drop      |
 184B: 2dup       | 1832: tuck       | 1820: nip        | 1807: over       |
 17EC: rot        | 17D7: xR         | 17C2: xS         | 17B5: drop       |
 17A6: dup        | 178B: swap       | 1770: <          | 1754: >=         |
 1736: <=         | 1716: >          | 1705: 0=         | 16EC: =          |
 16D2: <>         | 16B3: neg        | 169D: not        | 1684: xor        |
 166C: or         | 1653: and        | 1649: %1         | 163F: %0         |
 1635: $F         | 162B: $E         | 1621: $D         | 1617: $C         |
 160D: $B         | 1603: $A         | 15F7: -9         | 15EB: -8         |
 15DF: -7         | 15D3: -6         | 15C7: -5         | 15BB: -4         |
 15AF: -3         | 15A3: -2         | 1598: 0          | 1590: $0         |
 1584: -1         | 157B: 9          | 1571: $9         | 1568: 8          |
 155E: $8         | 1555: 7          | 154B: $7         | 1542: 6          |
 1538: $6         | 152F: 5          | 1525: $5         | 151C: 4          |
 1512: $4         | 1509: 3          | 14FF: $3         | 14F6: 2          |
 14EC: $2         | 14DF: 1          | 14D7: $1         | 1438: cons       |
 13B5: var        | 1397: lit        | 1388: spc        | 1377: cells      |
 1363: c!         | 1350: c@         | 133A: in>        | 132A: r>         |
 131A: >r         | 1308: memptr     | 12FF: mp         | 12F6: rp         |
 12ED: sp         | 12E2: back       | 12D7: here       | 12CC: last       |
 12BB: >in        | 12A9: cr         | 1298: debug      | 128A: x@         |
 127B: FALSE      | 126D: TRUE       | 125A: bool       | 1241: -          |
 1229: +          | 120B: nand       | 11F9: emit       | 11E9: key        |
 11A3: cbit       | 1181: sbit       | 1153: tbit       | 1136: <<         |
 1119: >>         | 1102: decs!      | 10A7: rdcstk!    | 107A: dcstk!     |
 1048: dwstk!     | 1009: dsget@     | 0FD6: dsgetn@    | 0FC9: pad!       |
 0FBA: padclr     | 0FA5: pad@       | 0F87: .sn        | 0F5A: .sz        |
 0F4D: .psz       | 0F3E: .rsz       | 0F09: ord        | 0EF0: (          |
 0EBE: .C         | 0EA5: .          | 0E0B: w@         | 0D46: words      |
 0D18: dump       | 0CB1: .R         | 0C9F: ?R         | 0C84: ?S         |
 0C56: .S         | 0BE6: libs       | 0BB6: lib        | 0B8B: libcnt     |
 0B57: :          | 0B3B: ;          | 0B1F: ,          | 0B14: ]          |
 0B0B: [          | 0AED: I          | 0ACF: @          | 0ABB: !          |
 0AB3: ;$         | 0AAB: :$         | 0A9E: exec       | 0A93: reset      |
 0A88: abort      | 0A66: bye        |
</pre>
---------------------------------------------------------------

<h4>CORE:</h4>  Starting with 'bye' and 'abort', the basic stack access words up to about 'lit', 'var', and 'cons' ... and at the end of the list the rest of the essenstial words for basic Forthiness: 'I' ('immediate'), [, ], ',', ';', ':' (the compiler), @, ! and lastly 'exit'.  The core also includes a lot of words to manipulate the internal state of the Forth stacks and state variables:  'rp' (return stack), 'sp' (data stack), 's@' (status flag), 'in>/>in' (input buffer), and so on.</p>

<h4>PRIMITIVES:</h4> 
<p>Also all of the comparatives (=, not, <, >, >=, <=) are defined, as well as the basic logic functions (and, or, nand, xor). 'negate' and 'invert' as defined in traditional Forth have been changed to 'neg' and 'not', and AGSB's '0#' was changed to 'bool' (to convert the top-of-the-stack value to its boolean equivalent).  True and false values are still $FFFF and $0000 respectively.</p>

<p>Note on numbers:  the interpreter includes functions to handle inline #'s and text, but for speed and efficiency reasons all 'single digit' #'s (whether decimal, binary, or hex) have explicit definitions in native code, thus '0' - '9', '-1' - '-9', '$0' - '$F', '%0' and '%1'. Most of the stack manipulation functions are also in the group, such as 'dup' and 'swap' but including more tricky ones such as 'pick' (indexed stack access) and 'snip' (remove bottomost cell from stack).</p>

<h4>ADDITIONAL STUFF:</h4>  <p>This is the largest category.  I could not do without '*' and '/' for very long so I found very efficient 6502 algorithms for those; both return a 32-bit value; in the case of '/' this includes both the division result and the remainder...so 'mod' is just '/ swap drop'. '*' always gives a 32 bit result with the LSW on top of the stack.  The Forth workhorse '*/' is also implemented, and I found a very small and well-tested 32-bit Galois random generator that is also included.  All of the core math functions are now part of the regular OS (in 'utes.s') and Forth calls those routines as needed.</p>

<p>This group also includes a lot of debugging tools, including a disassembler ('disasm'), 'syscall' for system calls, some ANSI screen functions ('Ascr', 'Acls', 'Acol'), and the basic parts of the memory manager: 'malloc', 'mlen'.  The addition of the PAD area allows a meaningful distinction between temporary and permanent data, and the 'padclr', 'pad@' and 'pad!' words manipulate that area.</p>

<p>'dump' and 'debug' are mixed in with the CORE group but the former has also been generalized to dump any page in memory rather than just showing a binary dump of the heap, and also formatted to be more readable. 'debug' toggles the ROM routine 'DUMPREG' to non-invasively dump the status and PC/SP/A/X/Y registers, as well as options for looking at the hardware stack, zero page, TIB, and DS/RT stack areas.</p>
-----------------DUMP OUTPUT------------------------------
<pre>
HF>$17E0 1 dump
17E0:A9 00 A0 00 91 EA C8 91 EA 4C 45 EF D7 17 03 72  .........LE....r
17F0:6F 74 20 5C EE 20 57 EE 20 52 EE 20 1A EE 20 1F  ot \. W. R. .. .
1800:EE 20 15 EE 4C 45 EF EC 17 04 6F 76 65 72 20 5C  . ..LE....over \
1810:EE 20 57 EE 20 1A EE 20 1F EE 20 1A EE 4C 45 EF  . W. .. .. ..LE.
1820:07 18 03 6E 69 70 20 5C EE 20 57 EE 20 1F EE 4C  ...nip \. W. ..L
1830:45 EF 20 18 04 74 75 63 6B 20 5C EE 20 57 EE 20  E. ..tuck \. W. 
1840:1F EE 20 1A EE 20 1F EE 4C 45 EF 32 18 04 32 64  .. .. ..LE.2..2d
1850:75 70 20 57 EE 20 5C EE 20 1F EE 20 1A EE 20 1F  up W. \. .. .. .
1860:EE 20 1A EE 4C 45 EF 4B 18 05 32 64 72 6F 70 20  . ..LE.K..2drop 
1870:5C EE 20 5C EE 4C 45 EF 67 18 05 32 6F 76 65 72  \. \.LE.g..2over
1880:A0 CC 20 5E EE 20 52 EE 20 57 EE 20 5C EE 20 1F  .. ^. R. W. \. .
1890:EE 20 1A EE 20 15 EE A0 CC 20 21 EE 20 1F EE 20  . .. .... !. .. 
18A0:1A EE 4C 45 EF 78 18 04 70 69 63 6B 20 5C EE A5  ..LE.x..pick \..
18B0:F0 0A 18 65 E8 85 CA C9 7E B0 17 85 CA A5 E9 85  ...e....~.......
18C0:CB A0 00 B1 CA 85 F0 C8 B1 CA 85 F1 20 1F EE 4C  ............ ..L
18D0:45 EF A9 02 85 D7 4C 7D EC A5 18 04 73 6E 69 70  E.....L}....snip
</pre>
----------------------------------------------------------
<p>Lastly, you will see 'cload', 'autoload' and 'bload'. These three words are the essential for loading extra 'meta-compiler' word libraries as well as binary libraries.</p>

<h4>META-COMPILED WORDS:</h4>  <p>The traditional Forth conditionals and loop structures are NOT easy to implement in native code using AGSB's engine, so for now these are loaded (using 'cload' or 'autoload'). These include 'if', 'then', 'else', 'do', 'loop', 'begin', 'again', 'repeat', 'until', and 'while', as well as the 'i/j/k' loop indexes.</p>

<h3>USAGE:</h3> the # conversion and string capture functions in the interpreter diverge a bit from standard Forth. As noted above, single digit numbers are defined explicitly as Forth words, so they can be included in compiled words bare; but multdigit #'s require the use of ' lit [ ## , ] ' or similar in order to store them inline in a word.</p>

<p>Strings are even more divergent. The ' ." ... " ' construct does not exist, nor do 'parse', 'type', 'word', 'char', '[char]' etc. Instead, the q^/Q^...^ pair should be used; this construct creates a zero-terminated string and stores it in either the PAD or in tandem with 'malloc' to allocate memory for it. 'malloc' returns the handle (double indirection) of the string on the memory stack (see below). The '.sz' (or '.psz' for a PAD item) word will print the string on the screen if the address of the pointer to the string is on the top of the stack. You can store the address as a constant or in a variable to use it otherwise.</p>

<p>EXAMPLE: Q^this is a test.^ cons astr .sz</p>

<p>The above translates as:  'capture the string between ^...^; store the string in the memory area and return a handle to it; save that handle to a CONSTANT named 'astr'; print it on the screen as a zero-terminated string'.   The result of all this is 'this is a test.'. </p>

<p>The PAD: a small buffer is set aside specifically to store temporary data.  The 'hx2d' word, for instance, converts the top item in the DS stack from a 16-bit hexadecimal number into a 5-digit ASCII-coded decimal string and stores the string in the PAD.  The string capture variant q^...^ (as opposed to Q^...^) also stores the resulting captured text into the PAD.  '.psz' will write the string item on top of the PAD out on the screen, and other items in the PAD can be display by using 'pad@ @ @ ... @' to traverse the current items stored there.  'padclr' clears the PAD.   Lastly, 'pad!' will see the address (NOT a handle) of a zero-terminated string and copy it to the PAD, returning the PAD address of the string.</p><br>
<p>Example: if you want to copy of the latest 'permanently' stored string captured with Q^...^, you can just type 'memptr 2 + @ 3 + pad!'.</p><br>
<p>Lastly, you can use the ctrl-c (copy) and ctrl-v (paste) keystrokes at the command line to copy and paste items to/from the PAD.</p>

<p>Memory manager: 'malloc' is the main word to allocate memory for data types more complicated than variables and constants, which are still implemented as in traditional Forth, ie either the address or the value are returned from a single 16-bit word store inline within the instance.  'malloc' created items can be up to 64K in size, and space in the item header is also available to implement data types at some point, if needed.</p>

<p>'memptr' returns the current value of the pointer on the memory stack; it uses the same 'store' and 'decrement' strategy as the DS and RT stacks, so 'memptr' always returns the stack position that the NEXT allocated item's address will be stored in.  'mlen' is a general purpose function that returns the length of a 'malloc'-created item.</p>
=======================================================================

=======================================================================
My partners in this project, including Dan Struthers and others involved 
with testing and development for the Hydra-16 hardware and ROM design 
(https://github.com/danstruthers/hydra-16/tree/V1.8C), will be moving the 
functional core of HyForth entirely to ROM, along with a binary that will
load the base training data to make it a fully functional language.

In the meantime...please be free to take a look at this port and adapt it 
as necessary for your favority 6502-based SoC.  More when....
</pre>
<p>  
#see below for original intro from Sr. Barcellos
<p>
<p>----------------------------------------------------------------</p>
#From (https://github.com/burntcouch/hy_millif/blob/0.2/hy_millif.s)
<p>
<pre>
; ---------------------------------------------------------------------
;
;   A MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth and MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use page zero and lots of lda/sta
;
;   Focus in size not performance.
;
;   why ? For understand better my skills, 6502 code and thread codes
;
;   how ? Programming a new Forth for old 8-bit cpu emulator
;
;   what ? Design the best minimal Forth engine and vocabulary
  ;----------------------------------------------------------------------
;   Changes:
;
;   all data (36 cells) and return (36 cells) stacks, TIB (80 bytes) 
;       and PIC (32 bytes) are in same page $200, 256 bytes; 
;
;   TIB and PIC grows forward, stacks grows backwards;
;
;   no overflow or underflow checks;
;
;   the header order is LINK, SIZE+FLAG, NAME.
;
;   only IMMEDIATE flag used as $80, no hide, no compile;
;
;   As ANSI Forth 1994: FALSE is $0000 ; TRUE is $FFFF ;
;
;----------------------------------------------------------------------
;   Remarks:
;
;       this code uses 
;           Direct Thread Code, aka DTC or
;           Minimal Thread Code, aka MTC.
;
;       use a classic cell with 16-bits. 
;
;       no TOS register, all values keeped at stacks;
;
;       TIB (terminal input buffer) is like a stream;
;
;       Chuck Moore uses 64 columns, be wise, obey rule 72 CPL; 
;
;       words must be between spaces, before and after;
;
;       no line wrap, do not break words between lines;
;
;       only 7-bit ASCII characters, plus \n, no controls;
;           ( later maybe \b backspace and \u cancel )
;
;       words are case-sensitivy and less than 16 characters;
;
;       no need named-'pad' at end of even names;
;
;       no multiuser, no multitask, no checks, not faster;
;
;----------------------------------------------------------------------
;   For 6502:
;
;       a 8-bit processor with 16-bit address space;
;
;       the most significant byte is the page count;
;
;       page zero and page one hardware reserved;
;
;       hardware stack not used for this Forth;
;
;       page zero is used as pseudo registers;
;
;----------------------------------------------------------------------
;   For stacks:
;
;   "when the heap moves forward, move the stack backward" 
;
;   as hardware stacks do: 
;      push is 'store and decrease', pull is 'increase and fetch',
;
;   but see the notes for Devs.
;
;   common memory model organization of Forth: 
;   [INBUF->...<-DSPTR: user forth dictionary :NEXTHEAP->pad...<-RTPTR]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...NEXTHEAP...]
;   
;   At page2: 
;
;   |$00 INBUF> .. $50| <DSPTR..DSEND $98| <RTPTR..RTEND $E0|SCRIBB> ..$FF|
;
;   From page 3 onwards:
;
;   |$0300 cold:, warm:, forth code, init: here> heap ... tail| 
;
;   PIC is a transient area of 32 bytes 
;   PAD could be allocated from here
;
;----------------------------------------------------------------------
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; so sp must point to actual TOS.
;   
;   The movement will be:
;       pull is 'fetch and increase'
;       push is 'decrease and store'
;
;   Never mess with two underscore variables;
;
;   Not using smudge, 
;       colon saves "here" into "back" and 
;       semis loads "LASTHEAPest" from "back";
;
;   Do not risk to put stacks with $FF.
;
;   Also carefull inspect if any label ends with $FF and move it;
;
;   This source is hacked for use with Ca65.
;
;----------------------------------------------------------------------
;
;   Stacks represented as (standart)
;       S:(w1 w2 w3 -- u1 u2)  R:(w1 w2 w3 -- u1 u2)
;       before -- after, top at left.
;
;----------------------------------------------------------------------
;
</pre>
