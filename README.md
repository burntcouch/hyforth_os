# hyforth_os
Hydra-16 BIOS + HyForth OS

<a href="https://github.com/burntcouch/hyforth_os/blob/main/README.md/#updates"> UPDATES </a>
<br>
<a href="https://github.com/burntcouch/hyforth_os/blob/main/README.md/#buildrun"> BUILDING and RUNNING </a>
<br><br><br>
This project is an independent fork (not resident in same repository) as Dan Struthers' Hydra-16 hardware project:
<p> https://github.com/danstruthers/hydra-16 </p>

as well as my HyForth port of AGSB's 'milliForth' project:
<p>https://github.com/burntcouch/hy_millif </p>

This fork represents the first stable versions of the OS and HyForth (0.91) after integrating the latter into the OS proper.

I wanted to preserve the original primitive nature of the BIOS at that point so I can rewrite it to be more congruent with my intended path of development for HyForth.  I will also fold in my port of MS-BASIC at some point, if I can ever reduce the zero page footprint of it.  This version of BASIC will be available in it's current, somewhat clunk form:
<p> https://github.com/burntcouch/ehybasic </p>

..but it will be ROM resident only.  'ehybasic' is not entirely stable and there are major issues (ferinstance, some really sticky self-modifying ZP code for IO handling) that need to be addressed before it would really be a reliable 'beginning' language for the Hydra-16.  More when.

The root folder of the repos has the basic OS code, (I am excluding the hardware-specific section of Dan's repo), with subfolders for ehybasic and hyforth itself.

<p> Hydra-16 v1.8C README:  https://github.com/burntcouch/hyforth_os/blob/main/README_H16.md </p>
<p> HyForth v0.91 README:  https://github.com/burntcouch/hy_millif/blob/main/README.md </p>

<p>Lastly...I've included (as of 10/15) Dan's Hydra-16 simulator:   (in the ./sim folder).  This is an 'older' copy that I was able to tweak in order to use my generated paged ROM binaries.  Original version is here:  https://github.com/danstruthers/hydra-16/tree/main/old/sim </p>
  
<p>Read the header section at the start of 'hydrasim.js' in order to figure out the command line options.</p>
<p>  My usual usage of the simulator (after installing Node.js):</p>
<pre> >node hydrasim.js -i --rom ./tmp --prom-no-stagger </pre>

<p>...which assumes that your 'os_rom_C02.bin' and 'paged_rom_C02.bin' files are in '/tmp'.  You've been warned.</p>
<a name="buildrun"></a>
<h1> Building and running</h1>
<p>11/13/26 - more minor changes</p>
<p> With the use of the simulator, I've increased my dev cycle quite a bit, with generally minimal resulting chaos.</p>
<p> Due to the expansion and reorganization of the OS-ROM area and added parsing and editing functions in HyForth, RAM use is also slightly different.  The new 'running' procedure is...'boot the Hydra-16', ie the old COPYTORAM + RAMSTART routine ($A000R + $800) is now automatic.  HyForth now begins at $A00 in RAM rather than lower down, and zeropage use and buffers hog up some extra room.  The screen editor buffer also now occupies the top 1K of task RAM with memory items allocated by 'malloc' below that.  Free memory between the top of the 'heap' and the bottom of the 'screen' area is still around 20Kb before adding more words or data.</p>

<p>10/22/26 - very minor updates</p>
<p>The cc65 .cfg file for this project has been simplified in name to 'os_rom.cfg'.  This file handles all the details of the memory map and what files are generated for what sections of memory, etc.  The corresponding output files are now called 'os_rom.bin' and 'paged_rom.bin' rather than the more clunky '....C02.bin' versions.  The make file is now just 'make.bat' in corresponding fashion.</p>
<p>---------------------------------------------------------------------------</p>
This project uses the cc65 ( https://cc65.github.io/ ) assembler and linker to do the dirty work.  Look at the 'makeC02.bat' file to have a guess of how to customize for your installation of cc65.  The .bat script also expects a 'version' string so that backups of code are automatically created during the build (handy for backtracking, if you aren't actually using Git for versioning).  Sloppy but enough for a simple project like this.

The .bat file generates both a 'paged_rom' image and the main OS image.  The Hydra-16 hardware expects the OS image to be burned to at least an 8K ROM mapped at $E000 (this is actually an SST39SF010 1Mbit FLASH ROM on the current version).   

The 'paged_rom' image (one of eight SST39SF040 4Mbit ROMs on the Hydra-16) includes the Forth 'heap' image as well as some 'training data' (a basic compiled Forth library) and a 'bload' (binary library).  Because of some design issues with the Hydra-16 hardware, the paged ROM image (16K) actually gets split into two swapped halves that are mapped to $C000 and $A000 respectively; in other words, if your actual code image is larger than 8K (the BASIC ROM image was about 11K ferinstance) you will have to copy the first 8K at $C000 and the remainder at $A000 (or offset upward by 16K if this is not the first bank) in order for the image to actually be mapped into Hydra-16 memory space continguously from $A000-$DFFF.

The Hydra-16 still boots to Wozmon in this version.  To install the heap into RAM, switch to the correct ROM bank by writing the page # to ZP location $01, then enter 'A006R' (WAS 'A003' last week!  TAKE NOTE.)  to run the COPYTORAM routine.  Then just enter '800R' in WozMon to start HyForth.  See the README for HyForth linked above for more details.
<a name="updates"></a>
<h1> Updates </h1>
<h3> 11/13/26 </h3>
<h4> Memory map changes:</h4>
<p>(SEE BELOW)</p>
<p> After a lot of dragging and chopping and screaming of strangling subroutines, I managed to reorganize the non-BIOS area of OS-ROM ($E000-$F800) so that the basic OS utilities (not directly BIOS relate) such as MEMCPY, DISASM, DUMPPAGE, DUMPREG, the math routines, and the basic Yamaha sound init and utility functions were all wedged together above the shell/OS-init segment.</p>
<p> HyForth is also considerably bigger as a result of the more robust parser as well as the addition of the PAD, HyFedit, and the ANSI functions. </p>
<br>
<p>The lower end of the task RAM area has also changed quite a bit:  HyForth uses a little more zeropage now ($A0-$FF0) and the PAD uses the formerly 'reserved' page from $700 up.  Wozmon's input buffer now permanently resides at $300 instead of floating around and stomping on things, and the starting address of the Forth cold-start entry point, some jump tables, and the Forth heap now begin at $0A00.  This still leaves a page below for a larger PAD if that becomes neccesary.
</p>
<p>I am also slowly hacking through the main OS and BIOS code to eliminate the use of a lot of PRINT_xxx macros.  Macros may be very useful but too much cleverness results in extremely obfuscated code, and I prefer verbosity over trickiness any day of the week.</p>
<pre>
-------------------
MEMORY MAP as assembled, 10/15/25
-------------------
zeropage
$00     - shared RAM switch
$01     - paged ROM switch
$03-$06 -  *** reserved for task switcher ***
$07-$2E - BIOS / OS stuff
$2F-$9F - *** FREE TO USE ***
$A0-$FF - PAD, Debug, Math, ANSI, HyFedit and HyForth

buffers and Forth stacks
$0100       - 6502 stack
$0200       - INPUT_BUFFER (serial / input buffer)
$0300       - WOZ_IN  (buffer for Wozmon)
$0400-$04FF - INBUF  (Forth input buffer)
$0500-$057F - DS (Forth data stack)
$0580-$05FF - RT (Forth return stack)
$0600-$07FF - MEMSTK (Forth memory allocation stack)
$0800-$08FF - Forth scratch PAD
$0900-$09FF - clipboard/command history
Forth in RAM
$0A00-$0A05 - Forth startup
$0A06-$0A48 - editor vars, library jump table, err/msg jump table
$0A60~$2200 - current Forth words heap, working up
$2200-$7BFF - Forth heap (working up) <-> memory space (working down)  $5A00 (20Kb+)
$7C00-$7FFF - Forth screen buffer

paged_ram
$8000-$9FFF - **!! not used cuz some banks of shared RAM area unreliable !!**

paged_rom
    HyForth 0.91 ROM image:
$A000-$Bxxx - Forth COPYTORAM, initial heap, training words
    $A000->$0800->$EC00 - Forth cold start
    $A003 - Forth COPYTORAM  (copy RAM image from paged ROM)
    $A100 - $B622 - Forth heap
    $B622 - $BF4E - sound demo, instrument patches, etc
    $B74E - $BE66 - autoload core, extras, ANSI, tests, binary load tests
$BE66-$CFFF - *** available for other fun stuff ***

os_rom  (~$700 available space)
------------------------------
$E000-$E110 - OS_MAIN, SHELL
$E111-$E2FF - *** available for shell, initialization ***    ($1D0)
$E300-$E656 - utilites - sound init, debug, memcpy, math     ($120)
$E800-$EB80 - disassmbler                                    ($80)
$EC00~$F4BC - Forth ROM core
$F4BC~$F692 - HyFedit
$F6xx-$F7FF -  *** available for use ***                     ($160)
$F800-$F821 - thunks (BIOS entry point jump table)
    TH_READ_CHAR           ; $F800
    TH_WRITE_CHAR          ; $F803
    TH_WRITE_BYTE          ; $F806
    TH_WRITE_HEX           ; $F809
    TH_WRITE_HEX_MASK      ; $F80C
    TH_WRITE_HSTRING       ; $F80F
    TH_WRITE_CRLF          ; $F812
    TH_CLEAR_SCR           ; $F815
    TH_DISASM              ; $F818
    TH_DISASM_AY           ; $F81B
    TH_MEMCOPY             ; $F81E
    TH_MEMCOPY_AY          ; $F821
    TH_DUMPREG             ; $F824    
$F825-$F83F - *** more room for thunks, etc. ***               ($20)
$F840-$FBFF - BIOS
$FC00-$FDFF - *** more room for bios ***                      ($200)
$FE00-$FEFF - Wozmon
$FF00-$FFxx - IO ports, TUVW registers, interrupt vectors
    T_REGISTER   = $FFF0   (current task selector)
    U_REGISTER   = $FFF1   (current shared-ram macro page)
    V_REGISTER   = $FFF2   (interrupt vector selector)
    W_REGISTER   = $FFF3   (BIOS page selector)
    $FFF4-$FFF9   *** reserved for future use ***
    NMI Vector   = $FFFA
    Reset Vector = $FFFC
    IRQ Vector   = $FFFE

  
</pre>

<h3> 10/22/26 </h3>
<p>Lots of new things:</p>
<ul>
<li><p>Multi-line input using tabs</p>
<p>The HyForth / millif parser is simple, and works very fast and well...but there have been a few gotchas.  One of the problems is that (unlike any Forth book you will every read), it WASN'T possible to enter a long Forth statement on multiple lines...</p>
<p>But now you can:  if you want to introduce a carriage return in the middle of a statement for cosmetic / clarity purposes, just hit the tab button.  The parser will swallow the tab character and echo back a CRLF and 5 spaces for indentation, without terminating input.  The total character limit of ~255 for the buffer still stands, but this will give a user about 5-6 lines in any case. </p>
</li>
<li><p>Comments</p>
Another standard part of Forth I finally got around to.  ( <comment text> ) as per standard, including inline between valid words, e.g. "1 2 ( blah ) +" will ignore the text in parens and just do the math.
</li>
<li><p>'words' reworking and the w@ word</p>
<p></p>You can now use 'w@ <word name>' to return the address of the length in bytes, characters of the name, and the CFA.'  This is the equivalent of the single tick ' words in standard Forth.</p>
<p>The 'words' word also pauses every 20 lines (80 words) so it is easier to scan by eyeballs.</p>
</li>
<li><p>ANSI support</p>
This was already here, but for the editor I needed something more modular and robust.  Same basic functions are still available, and I added some convenience constants to use in particular with the 'Acol' word, to change background and foreground colors and other attributes.
</li>
<li><p>HyFedit - a screen editor for Hydra-16 and HyForth</p>
This sub-project will display and allow editing of Forth 'screens', which are 64 x 16 character memory buffers to store and run more complex (than single-line) programs.  ANSI will be heavily used to manage screen navigation and ultimately to add helpful color and other kinds of emphasis to make visualization and production of Forth code easier.  See the hyf_edit.s file for whatever is done with this.  NOT working yet.

</li>
</ul>
