# hyforth_os
Hydra-16 BIOS + HyForth OS

This project is an independent fork (not resident in same repository) as Dan Struthers' Hydra-16 hardware project:
https://github.com/danstruthers/hydra-16

as well as my HyForth port of AGSB's 'milliForth' project:
https://github.com/burntcouch/hy_millif

This fork represents the first stable versions of the OS and HyForth (0.91) after integrating the latter into the OS proper.

I wanted to preserve the original primitive nature of the BIOS at that point so I can rewrite it to be more congruent with my intended path of development for HyForth.  I will also fold in my port of MS-BASIC at some point, if I can ever reduce the zero page footprint of it.  This version of BASIC will be available in it's current, somewhat clunk form:
https://github.com/burntcouch/ehybasic

..but it will be ROM resident only.  'ehybasic' is not entirely stable and there are major issues (ferinstance, some really sticky self-modifying ZP code for IO handling) that need to be addressed before it would really be a reliable 'beginning' language for the Hydra-16.  More when.
