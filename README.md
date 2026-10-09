# hyforth_os
Hydra-16 BIOS + HyForth OS

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

<h1> Building and running</h1>

This project uses the cc65 ( https://cc65.github.io/ ) assembler and linker to do the dirty work.  Look at the 'makeC02.bat' file to have a guess of how to customize for your installation of cc65.  The .bat script also expects a 'version' string so that backups of code are automatically created during the build (handy for backtracking, if you aren't actually using Git for versioning).  Sloppy but enough for a simple project like this.

The .bat file generates both a 'paged_rom' image and the main OS image.  The Hydra-16 hardware expects the OS image to be burned to at least an 8K ROM mapped at $E000 (this is actually an SST39SF010 1Mbit FLASH ROM on the current version).   The 'paged_rom' includes the Forth 'heap' image as well as some 'training data' (a basic compiled Forth library) and a 'bload' (binary library).  Because of some design issues with the Hydra-16 hardware, the paged ROM image (16K) actually gets split into two swapped halves that are mapped to $C000 and $A000 respectively; in other words, if your actually code image is larger than 8K you will have to copy the first 8K at $C000 and the remainder at $A000 (or offset upward by 16K if this is not the first bank) in order for the image to actually be mapped into Hydra-16 memory space continguously from $A000-$DFFF.

The Hydra-16 still boots to Wozmon in this version.  To install the heap into RAM, switch to the correct ROM bank by writing the page # to ZP location $01, then enter 'A003R' to run the COPYTORAM routine.  Then just enter '800R' in WozMon to start HyForth.  See the README for HyForth linked above for more details.
