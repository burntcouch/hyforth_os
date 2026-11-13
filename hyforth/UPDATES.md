# Updates:  HyForth for 6502
<h2>HyForth Updates</h2>
<p> 
<h3>Updates, 11/13/26</h3>
----------------------------------------------------------------------
<p>Since May, a lot more has changed with Forth.  I split the larger Hydra-16 OS project from the 'reborn' effort in order to concentrate on a smaller, more comprehensible version of Forth that fits the Hydra-16 hardware environment.  I also have a strong affinitiy for C-like and C-derived languages, and my version of Forth adopts a lot of conventions and nomenclature that will be more familiar to programmers of more popular languages like Perl, Ruby, JS and of course C.  This is more of a personal comfort issue than for any functional reason; Forth requires an entirely different kind of approach for application development and making HyForth a little bit more relatable has kept me motivated to continue on this project. </p>
<p>The OS itself has been trimmed down and clarified from the May 2026 builds (1.8Cz in my versioning).  Version 1.8Da is my latest series, and work is slowly continuing on that front. <a href="https://github.com/burntcouch/hyforth_os/blob/main/UPDATES.md"> Updates</a> and <a href="https://github.com/burntcouch/hyforth_os/blob/main/README.md">documentation</a> on the 1.8Da OS can be found by following the links.</p>
<h4>What's New?</h4>
<p>Very little of the HyForth vocabulary has changed, but a lot has happened organizationally, and also underneath:</p>
<ul>
<li>OS integration:  The Hydra-16 now boots directly to Forth; you can exit to Wozmon by entering 'bye' but the intent is to provide everything a programmer of the hardware would need in order to develop applications.  This currently includes a crude text editor, a 6502 disassembler, and of course all the very powerful native Forth 'words'.  Every memory location and every BIOS and OS function can be accessed and manipulated directly from Forth, although there is currently a shortage of OS-specific 'convenience' words and functions built-in.  The debugger I wrote to accomplish the MilliForth->HyForth port is still my most useful tool for system tasks.</li>
<li>'Screen' editor:  the traditional Forth 'screens' have been partially implemented; the top kilobyte of 'task RAM' ($7C00-$7FFF) is the default buffer for this feature.  The HyForth command line is the primary interface to the screen display, and the visual display of a screen is read-only.  Instead of creating a keyboard navigable screen, I've decided on a simpler and more compact version that leverages the power of Forth rather than sitting on top of it.  Since RAM and ROM space are limited in the 64K that the 6502 can access without banking, any 'shell' that acts as the OS should be a small and fast as possible, to minimize overhead due to task switching if for no other reason.</li>
<li>'permanent' vs 'temporary' memory management:  One of the widest divergences from traditional Forth involves number and text capture, base conversion, and data structures.  Minimal Threaded Code (MTC) versions of Forth generally embed data structures within the body of compiled words, but HyForth has the basic VARIABLE ('var') and CONSTANT ('cons') structures hard-coded, and more complicated structures can be allocated memory in a more C-like way.  All of the task RAM between the 'heap' (Forth vocabulary structure) and the screen buffer, about 20K with all the optional vocabulary loaded, can be used for data.  There is also a smaller temporary buffer (the PAD) where temporary items like single-use strings and strignified hex-to-base numbers are stored.</li>
<li>More flexible parser:  the command line currently has limited copy-cut-paste functions, with more coming.  The PAD is also used for this, so Forth words can generate temporary items that can be pasted onto the command line, and vice-versa.</li>
<li>Libraries!  With the 'lib/libs', 'autoload' and 'bload' words, you can view, manage, create, save, and reload both compiled and hard-coded Forth words, as needed.  Considering the flexibility of Forth, a 'library' can also be a loadable data structure with appropriate code to manipulate it.</li>
</ul>
<p>For detailed documentation on the current HyForth vocabulary, go <a href="https://github.com/burntcouch/hyforth_os/blob/8Da_12/hyforth/README.md"> here.</a></p>


----------------------------------------------------------------------
<p>  
Update, 5/3/26:
<p> Hell of a lot has changed in a month or so.  ROM conversion still works as noted below in 3/21/26 notes, and installation now proceeds very simply: </p>
<p> -- change to appropriate ROM bank in Wozmon (I use bank $03 for testing most of the time) by saving the bank number to location ZP $01 --  e.g '1:3' in Wozmon if you are using bank $03.</p>
<p> -- Run the COPYTORAM routine from the jmp point at A003.  'A003R' in Wozmon.</p>
<p> -- Start HyForth at $0800 by entering '800R'</p>
<p>   You will see a 'HyForth 0.xx MMDDYY' version banner and then the HF> prompt. </p>
----------------------------------------------------------------------
<p>   As you can below, a lot of words have been added in the last month and a half; the list is a screenshot of the output of 'words' on the most current version (0.88 5/2/26).</p>
<p>  The list is only very loosely organized at this time, into 4 main sections:</p>
<p> CORE:  starting with 'bye' and 'abort', the basic stack access words up to about 'lit', 'var', and 'cons' ... and at the end of the list the rest of the essenstial words for basic Forthiness:  'I' ('immediate'), [, ], ',', ';', ':' (the compiler), @, ! and lastly 'exit'. </p>
<p>  PRIMITIVES:  the interpreter includes functions to handle inline #'s and text, but for speed and efficiency reasons all 'single digit' #'s (whether decimal, binary, or hex) have explicit definitions in native code, thus '0' - '9', '-1' - '-9', '$0' - '$F', '%0' and '%1'.  Also all of the conditionals are defined, as well as the basic logic functions.  'negate' and 'invert' as defined in traditional Forth have been changed to 'neg' and 'not', and AGSB's '0#' was changed to 'bool' (to convert the TOS value to it's boolean equivalent).  Most of the stack manipulation functions are also in the group, such as 'dup' and 'swap' but including more tricky ones such as 'pick' (indexed stack access) and 'snip' (remove bottomost cell from stack).</p>
<p>  ADDITIONAL STUFF:  I could not do without '*' and '/' for very long so I found very efficient 6502 algorithms for those; both return a 32-bit value; in the case of '/' this includes both the division result and the remainder...so 'mod' is just '/ swap drop'.  '*' always gives a 32 bit result with the LSW on top of the stack.</p>
<p>  This group also includes a lot of debugging tools, including a disassembler, 'syscall' for system calls, a random # generator, some ANSI screen functions ('Ascr', 'Acls', 'Acol'), and the basic parts of the memory manager:  'malloc', 'mlen', 'mktemp', and 'purge'.  'dump' and 'debug' are mixed in with the CORE group but the former has also been generalized to dump any page in memory rather than just showing a binary dump of the heap, and also formatted to be more readable.  'debug' toggles the ROM routine 'DUMPREG' to non-invasively dump the status and PC/SP/A/X/Y registers, as well as options for looking at the hardware stack, zero page, TIB, and DS/RT stack areas.</p>
<p>  Lastly, you will see 'cload', 'autoload' and 'bload'.  These three words are the essential for loading extra 'meta-compiler' words and binary libraries.</p>
<p>  META-COMPILED WORDS:  the traditional Forth conditionals and loop structures are NOT easy to implement in native code using AGSB's engine, so for now these are loaded (using 'cload' or 'autoload').  These include 'if', 'then', 'else', 'do', 'loop', 'begin', 'again', 'repeat', 'until', and 'while', as well as the 'i/j/k' loop indexes. </p>
<pre>
 1BE7: |          | 1BDF: |          | 1BCA: decsz!     | 1BB4: mdump      |
 1BA6: k          | 1B96: j          | 1B86: i          | 1B41: loop       |
 1B2A: do         | 1B01: repeat     | 1AE9: while      | 1AD1: until      |
 1AB9: again      | 1AAB: begin      | 1A84: else       | 1A6D: then       |
 1A58: if         | 1A3B: branch     | 1A0B: ?branch    | 1A00: 2*         |
 194A: exit       | 1916: :          | 18FA: ;          | 18DE: ,          |
 18D3: ]          | 18CA: [          | 18AC: I          | 1876: @          |
 1862: !          | 185A: ;$         | 1852: :$         | 1845: exec       |
 181B: mlen       | 1793: malloc     | 1745: purge0     | 172B: mktemp     |
 1704: syscall    | 16D5: disasm     | 16BB: free       | 168F: memcpy     |
 167B: xdrv       | 1638: /          | 160C: *          | 15F1: max        |
 15C4: min        | 159F: rand32     | 1592: rand       | 1571: rseed      |
 1542: Acol       | 14F8: Ascr       | 14DA: Acls       | 144C: bload      |
 13E9: cload      | 13A3: autoload   | 1347: snip       | 1313: pick       |
 12E6: 2over      | 12D5: 2drop      | 12B9: 2dup       | 12A0: tuck       |
 128E: nip        | 1275: over       | 125A: rot        | 1245: xR         |
 1230: xS         | 1223: drop       | 1214: dup        | 11F9: swap       |
 11DE: <          | 11C2: >=         | 11A4: <=         | 117C: >          |
 116B: 0=         | 1152: =          | 1138: <>         | 111C: neg        |
 1106: not        | 10ED: xor        | 10D5: or         | 10BC: and        |
 10B2: %1         | 10A8: %0         | 109E: $F         | 1094: $E         |
 108A: $D         | 1080: $C         | 1076: $B         | 106C: $A         |
 1060: -9         | 1054: -8         | 1048: -7         | 103C: -6         |
 1030: -5         | 1024: -4         | 1018: -3         | 100C: -2         |
 1001: 0          | 0FF9: $0         | 0FED: -1         | 0FE4: 9          |
 0FDA: $9         | 0FD1: 8          | 0FC7: $8         | 0FBE: 7          |
 0FB4: $7         | 0FAB: 6          | 0FA1: $6         | 0F98: 5          |
 0F8E: $5         | 0F85: 4          | 0F7B: $4         | 0F72: 3          |
 0F68: $3         | 0F5F: 2          | 0F55: $2         | 0F48: 1          |
 0F40: $1         | 0E9E: cons       | 0E1B: var        | 0DFD: lit        |
 0DEE: spc        | 0DDD: cells      | 0DC9: c!         | 0DB6: c@         |
 0DA0: in>        | 0D90: r>         | 0D80: >r         | 0D6E: memptr     |
 0D65: rp         | 0D5C: sp         | 0D51: back       | 0D46: here       |
 0D3B: last       | 0D2A: >in        | 0D18: cr         | 0CFF: debug      |
 0CF1: s@         | 0CDA: bool       | 0CC1: -          | 0CA9: +          |
 0C8B: nand       | 0C79: emit       | 0C69: key        | 0C23: cbit       |
 0C01: sbit       | 0BD3: tbit       | 0BB6: <<         | 0B99: >>         |
 0B82: decs!      | 0B27: rdcstk!    | 0AFA: dcstk!     | 0AC8: dwstk!     |
 0A89: dsget@     | 0A56: dsgetn@    | 0A29: .sz        | 09F9: ord        |
 09E4: .C         | 09CB: .          | 0911: words      | 08E9: dump       |
 0882: .R         | 0869: ?R         | 0850: ?S         | 0822: .S         |
 0817: reset      | 080C: abort      | 0803: bye        |

</pre>
<p>  USAGE:  the # conversion and string capture functions in the interpreter diverge a bit from standard Forth.  As noted above, single digit numbers are defined explicitly as Forth words, so they can be included in compiled words bare; but multdigit #'s require the use of ' lit [ ## , ] ' or similar in order to store them inline in a a word.</p>
<p> Strings are even more divergent.  The ' ." ... " ' construct does not exist, nor do 'parse', 'type', 'word', 'char', '[char]' etc.   Instead, the q^...^ should be used; this construct creates a zero-terminated string and uses 'malloc' to allocate memory for it.  'malloc' returns the handle (double indirection) of the string on the memory stack (see below).  The '.sz' word will print the string on the screen if the address of the pointer to the string is on the top of the stack.  You can store the address as a constant or in a variable to use it otherwise. </p>
<p> EXAMPLE:  q^this is a test.^ cons astr .sz </p>
<p> ... this will print 'this is a test.'.  Using 'astr' in a compiled word will return the string handle as described above.</p>
<p> Memory manager:  'malloc' is the main word to allocate memory for data types more complicated than variables and constants, which are still implemented as in traditional Forth, ie either the address or the value are returned from a single 16-bit word store inline within the instance.</p><p>  'memptr' returns the current value of the pointer on the memory stack; it uses the same 'store' and 'decrement' strategy as the DS and RT stacks, so 'memptr' always returns the stack position that the NEXT allocated item's address will be stored in.  </p><p>  'mlen' is a general purpose function that returns the length of a 'malloc'-created item.</p><p> 'mktemp' marks an item in the memory storage area as temporary, while 'purge' (work in progress) will remove temporary items in the memory stack and reorganize the stack to re-use deallocated space. 
</p>
<pre>
LATEST CHANGES (3/21/26):
     ROM conversion is now done; this version resides almost entirely at $A000 and on;
  The 'COPYTOROM' routine at $A003 will load the dictionary into RAM at $0600, and 
  running from there will bring up HyForth with all the primitives and added words
  from 'hywords.s' into RAM.  Current RAM footprint is less than 2K, and ROM usage is
  around 3K with test scripts.  Zeropage usage is 38 bytes total, from $D8-$FB.
     And a lot MORE stuff.  All of the numerical conversions now work; a lot more hard-
   coded words, including:  2drop, 2dup, 2over, r>, >r, nip, tuck, xR (clear return
   stack), allot, sp, rp, >in, last, here, cr.
     More importantly, 'cload' will now load all of the scripts for compiled test words
  sequentially; usage is '$xxxx cload', where xxxx is the address of a zero terminated
  string of Forth words.  The 'ftrain.s' file is assembled into ROM as part of the 
  overall build, and the first word, '2*', ends up at $A5B9.  cload will automatically
  push the address of the next string onto the stack, so after you load the first
  one in the list you just type 'cload' until you've got them all loaded.
    AGAIN, this is now a stable, full featured forth, after the test words are loaded;
a lot still needs to be done with machine-coded words but we're getting there...
------------------------------------------------------------------------------------
LATEST CHANGES (3/14/26):
    A lot of the 'training' words in the my_bf.FORTH file have now been hardcoded, 
  include digits 0-9, -1 to -9, $A-F, %0 and %1 (binary digits); drop, dup, rot, over, 
  swap; xS (clear data stack); <, >, >=, <=, =, <>; not, and, or, xor, neg; .C (prints
   two characters packed in word).  I renamed the following:  .S / .R for %S / %R; << 
   and >> for asl / lsr - these latter now do multiple bit shifts, a la:
          ( w n -- w&lt;&lt;n )  and similar for &gt;&gt;
------------------------------------------------------------------------------------
    Decimal to 'word' conversions now working fine, and binary/hex are just around the 
  corner.  Per design, none of these will work as bare words inside a compiled word,
  but we are working on hardcoding literals (both numbers and strings).
     SIZE-WISE:  with all of the new hardcoded words and the number conversions, the 
  RAM code (engine, primitives and words) comes in at around 3K, with a lot of scope 
  for optimization.  Very promising if the other essential things like branch, IF/THEN,
  DO/LOOP, BEGIN...UNTIL/WHILE etc, as well as literals and CREATE can all be wedged-in.
     LOAD and SAVE for both hardcoded and compiled words also need to be done.  Just 
  hoping this stays under 8K at this point; ROM conversion down the road a bit, but 
  will help.
</pre>
-------------------------------------------------------------<p>
-------------------------------------------------------------<p>
