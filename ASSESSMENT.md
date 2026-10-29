# OctoForth: a native-code Forth for the Propeller 2, in OctoGo

Assessment of 2026-10-28, before any code. The idea, as the user put it: a
Forth for the P2 written in OctoGo, after the user's own Forth for the Intel
8080 of the 1980s, which compiled every colon definition straight to 8080
machine code as it was defined and kept the Forth stack on the CPU's stack;
a language experiment, and a third OctoGo program after p2-11 (../p2-11) and
obeam (../obeam). The language is OctoForth; the repository, today
`octoforth`, will be `oforth`, as OctoGo's is `ogo` and OctoBeam's `obeam`.

This file consolidates what was checked in this session against the OctoGo
tree (../ogo, v1.0.0-rc.2; the installed `ogo` is
v0.58.1-0.20261025171618-793f3a0b9a7b+dirty), the backend's own listing of
p2-11 and of a test build made here, flexspin's documentation, the
measurements p2-11 and obeam recorded, the sources and glossaries of TAQOZ,
the P2XCForth archive the user downloaded (`P2XCForthC.zip`, Christof
Eberspaecher, 2025-07-11), the sources of Mecrisp-Stellaris and zeptoforth,
Stephen Pelc's two VFX papers, Brad Rodriguez's Moving Forth and CamelForth,
the fig-FORTH 8080 listing, and the P2 datasheet, documentation and
instruction spreadsheet. Two surveys were made for it by agents. The
Parallax forum answers every fetch with a captcha, so the user saved six
of its pages into `forum/` on 2026-10-28, and they were read in full: the
P2XCForth thread 176239 (22 posts, 2025-07-11 to 2026-10-28), the csForth
thread 175463 (2 posts, 2023-08), both pages of "Understanding the
performance costs of hub execution" 174869 (33 posts, 2022-09), "Study
about an Inline Compiler" (6 posts, 2023-01 to 2023-03, saved as
`forum/1548794/`) and "Pondering about another Forth for P2", the thread
P2CCForth was born in (10 posts, 2025-02, saved as `forum/1565554/`).
Every quotation from those five threads is now verbatim from the page; two
figures an agent had taken from a search engine's snippet of the inline
compiler study were wrong and are corrected below (sections 1 and 3.4). A
fact from a forum thread that was not saved still comes from a snippet and
stays marked [forum snippet].

## 1. Verdict: go

The user decided go on 2026-10-28, after probe M0. The verdict as it was
proposed: go; the one probe asked for is done. The idea is sound, the hardware fits it unusually
well, and nobody has done it: no Forth for the P1 or the P2 has ever
compiled a colon definition to machine code (section 3.4). The P2 executes
code from hub RAM, so a word compiled into hub RAM runs the moment it is
written; the backend leaves sixteen cog registers and a quarter of the LUT
to the program, which is a Forth engine's whole register file and its two
stacks at two to three clocks an access; and OctoGo already carries PASM as
Spin2 objects, so nothing new is needed of the compiler to start. The one
integration point not seen working in OctoGo before -- inline PASM in a
Spin2 method calling into generated hub code and coming back -- had a
precedent in P2XCForth, whose C inner interpreter enters its PASM core so
(section 3.2), and was probed on the board on 2026-10-28 (M0, section 4,
"Probe M0"): it works, a trap from a word back into OctoGo and into the
word again works, from a nested word too, and the fallback, a word
compiled at run time started on a cog of its own, works as well. The
measured costs agree with the model of section 3.6 but for one item, `REP`,
which gains nothing in hub RAM.

Three corrections to the idea as it was put:

1. **"JIT" is the native-code Forth family, not a novelty of Forth.**
   Compiling a definition to machine code as it is defined, with the
   primitives inlined, is what Mecrisp-Stellaris does on ARM, zeptoforth on
   the RP2040, SwiftForth and VFX on x86 (section 3.5); on the 8080 in the
   1980s it was unusual, the Forths of the day being threaded, and no 8080
   Forth of that time compiling to machine code could be found documented.
   What is new is doing it on the P2, where every Forth so far interprets
   tokens or threads. The one study of inlining there (Christof Eb., 2023,
   inside TAQOZ, section 3.4) found that copying the primitives' code in
   place of calling them gains little by itself (TAQOZ's fibonacci loop
   went from 590 to 461 percent of hub PASM's time), that the loop must be
   compiled with them (210 percent), that a macro assembler over TAQOZ's
   stack reaches 184 percent, and that leaving TAQOZ's stack handling
   behind "would need a complete rewrite of the Forth system". Two years
   later the same author pondered "a new direct threaded Forth
   implementation" whose "Code is machine code", with small words inlined,
   and set it aside because such a machine "would not be capable of
   calling high level code of other languages", writing P2CCForth and
   P2XCForth instead. This is that rewrite, with the compiler in a
   high-level language, and the call into OctoGo is the hinge he lacked.
2. **The P2 has no one CPU stack to put the data on.** The 8080 design kept
   the data stack on SP because PUSH and POP were the fastest memory
   operations the chip had, which is Moving Forth's rule too ("If the CPU
   has few address registers and PUSH/POP are faster than explicit memory
   references, use the hardware stack as the Parameter Stack") and what
   fig-FORTH 8080 and CamelForth/Z80 did. The P2 has three candidates: an
   eight-level hardware stack (CALL/RET, PUSH/POP), too shallow for data; a
   hub stack through PTRA (CALLA/RETA), which the C backend already uses for
   its own frames and which costs a hub access of 3 to 26 clocks each way;
   and the LUT, 512 longs of a cog's own memory at 2 clocks a write and 3 a
   read, addressed with the same auto-incrementing PTRx forms as hub RAM.
   The LUT is the P2's PUSH/POP, so the data stack goes there, as TAQOZ's
   does below its four register cells. The return stack may be the C stack
   (CALLA/RETA on PTRA), which echoes the 8080 design, or the LUT with a
   link register; M0 measured both, and the LUT wins: 34 clocks a call and
   return against 70.
3. **"Competitive" has a shape, and the competitor is XBYTE, not TAQOZ.**
   TAQOZ's primitives cost 24 to 128 clocks each and its empty loop 32
   (section 3.1); P2XCForth's XBYTE core does `1+` in 8, a stack operation
   in 16, an empty loop in 72, and is "as fast as Taqoz or even faster, up
   to twice as fast" (section 3.2). Inlined native primitives cost 2 to 5
   clocks, so on arithmetic and stack work a native Forth should be several
   times faster than either. But a taken branch from hub RAM costs 13 to 20
   clocks against 4 in cog RAM, a word call is two of them, and `@` and `!`
   cost the same hub access in every Forth. So the gain is large on
   straight-line code, moderate on loops and calls, and nil on memory-bound
   code -- unless small words are inlined and hot loops are copied into cog
   RAM, both of which the design provides for and both of which Christof's
   figures say are where the time is: hubexec PASM is 2 times slower than
   cog PASM, C with FCACHE is 6 times faster than TAQOZ (1 : 4 : 24 against
   P2CCForth), and on his fibonacci loop a native Forth that called its
   primitives instead of copying them would sit at TAQOZ's own speed
   (section 3.6). Pelc's rule of thumb from the PC Forths says the
   same: plain subroutine threading "is usually twice as fast as any ITC or
   DTC Forth", an inlining and pattern-matching generator four times or
   more. M0 measured the parts (section 4); the headline numbers are M2's,
   on whole programs, not this file's to guess; section 3.6 has the model.

## 2. What is being proposed, in one paragraph

An OctoGo program (and later a library any OctoGo program imports) holding
the outer interpreter, the dictionary and the compiler. A line typed at the
serial console is parsed in OctoGo; a number is pushed, a word is executed; a
colon definition is compiled to P2 machine code written into a hub RAM array
with `unsafe`, each primitive copied in from a PASM template and the control
structures emitted by a small instruction encoder, and the word is then
executed by calling its address. The generated code uses only what the
backend leaves free of the cog it runs on -- registers $1E0-$1EF, of which
PR0-PR7 are the first eight, PTRB, and LUT $200-$2FF -- so the same code
runs on the main cog beside the OctoGo program and on any free cog started
as an engine, which is how a word is sent to run on its own cog, as `go`
sends a function. The primitives are written once, in PASM, in the Spin2
object that also holds the entry trampoline and the engine image. The
interpreter and compiler are Go once given a package clause, so the parser,
the number conversion, the dictionary and the encoder are tested on the
host, the encoder against flexspin's own assembler.

## 3. Prior art

### 3.1 TAQOZ (Peter Jakacki)

Read: taqoz.spin2 V2.8 (2021-04-01) and the 2024-02-13 build with their
listings, the ROM listing, the V2.8 glossary with its measured cycle column,
the inline-assembly guide (Bob Edwards), the SourceForge project.

- **Versions.** The ROM holds "V1.1--v33h 190219-1900", 432 words, about
  11.6 KB of the 16 KB boot ROM (the booter and monitor take 4.1 KB). TAQOZ
  Reloaded is the full system loaded from SD or flash: V2.8 'CHIP'
  210401, V2.14.0 'CHIP' 230821, the last image published 2024-02-19 on
  SourceForge (project tachyon-forth), MIT licence. Peter's work since 2024
  is a Tachyon for the ESP32-C3; the P2 community around TAQOZ (Christof
  Eb., Bob Edwards) maintains the glossaries and the link list. This
  project's P2-EDGE has TAQOZ Reloaded in its flash (ogo's CLAUDE.md, "The
  board": it boots about 218 ms after a reset no loader follows, at 921600
  baud).
- **Execution model** (from the source). Code is a stream of 16-bit
  wordcodes in hub RAM; the instruction pointer is PTRA. The inner loop
  reads a wordcode (`rdword x, PTRA++`) and classifies it by range: below a
  threshold it is the address of a PASM primitive in cog RAM or in the
  hubexec area, called directly ("only have a 4 instruction overhead via
  doCALL"); from $2000 up it is a colon definition, entered by pushing PTRA
  on a LUT return stack; the range $1800-$1FFF encodes 10-bit literals,
  7-bit conditional branches, unconditional jumps and 9-bit register
  indexes; longer literals follow inline. The data stack is four cog
  registers (a, b, c, d) over a 32-deep overflow stack in LUT addressed by
  PTRB, with a depth counter; `+` in that model, as the inline compiler
  study wrote it out (section 3.4), is `add b,a`, a decrement of the depth,
  three `mov`s to close the gap and a `rdlut` to refill the fourth cell,
  six instructions where one register over a LUT stack needs two. The
  return stack is 64 longs of LUT, the loop stack and an auxiliary stack
  more of it. Cells are 32 bits. The dictionary is separate from the
  code, with 16-bit code addresses, which is why addresses past 64 KB need
  PAGE prefixes. Colon definitions compile to wordcodes only; native code
  enters by hand: `code ... end` words written in the built-in assembler
  and run by hubexec, `ASM:`/`FORTH:` inside a definition, and `COGMOD`,
  which copies up to 24 instructions into cog RAM for about 1.75 times the
  speed. The whole kernel runs with its own registers and its LUT stacks, so
  it does not share a cog with anything else, and `pause`-style
  multitasking within a cog is not provided for that reason.
- **Timing** (the source's own comments and the V2.8 glossary's TIME
  column, at 200 MHz): an empty `FOR NEXT` is 32 clocks an iteration
  (1,000,000 in 32,000,089 cycles, 160 ms); `1+` 24, `@` and `C@` 32,
  `SWAP` 40, `DUP`, `DROP`, `OVER`, `+`, `AND` 48, `-` 56, `!` 64, `*` and
  `U/` 128. A 100-element byte-array increment: 38,136 cycles as a Forth
  word, 5,096 as a `code` word, "around a 7x improvement" (Bob Edwards). The
  SourceForge page's "single TAQOZ operations execute in under 100 ns" is
  the marketing form of the same numbers.
- **Size.** The V2.14 image: 50,090 bytes of code and 18,455 of names; it
  uses the bottom 128 KB of hub RAM, the ROM version the bottom 64 KB.
- **Multi-cog.** `NEWCOG` loads an idle TAQOZ into a cog, `' WORD n RUN`
  runs a word there, `TASK`, `COGATN`; cog 7 drives VGA in Reloaded.
- **Hardware support shipped:** FAT32 with a formatter and a flat file
  system, SD at sysclk/4 through smart pins, VGA text and bitmaps, audio,
  SPI RAM, an RTC, I2C, smart-pin words, an interactive assembler, a
  decompiler, Ethernet and PS/2 in Forth source, SPI flash boot. Twelve
  years of a working engineer's words: the breadth no new Forth matches
  soon, and the reason to be different rather than complete.

### 3.2 P2XCForth and P2CCForth (Christof Eberspaecher)

Read here, from the archive: `P2XCForthA.pdf` (2025-07-11), `P2XFC.c`
(1,632 lines) and `P2XFC.spin2` (the XBYTE core), built with FlexC 7.1.0 for
a P2 Kiss board (25 MHz resonator, 200 MHz clock); the zip also carries a
`_BOOT_P2.BIX` for that board, blocks on SD, the FED editor and an online
glossary. And the whole forum thread, `forum/176239/`, 22 posts from
2025-07-11 to 2026-10-28, most of them the author's and Bob Edwards'.

- **P2CCForth** (2025-02) is a Forth written in C and compiled by FlexC,
  portable (it also runs on the RP2040), its inner interpreter a `switch`
  over 32-bit codes; "about 3.8 times slower than Taqoz" on the Byte sieve,
  which the author counts as the price of writing it in C (the PDF, section
  2). It was born in the thread "Pondering about another Forth for P2"
  (`forum/1565554/`, 2025-02-11 to 2025-02-15), whose motivations are
  OctoForth's too: "use drivers, others have written and placed in OBEX",
  "Forth as a script language inside FlexProp", "an ANSI Forth. Because of
  portability and documentation", and multitasking without "swap[ping]
  loads of longs in and out of LUT and COG ram". After days of trying to
  port ESP32Forth, lbForth, ceForth33 and pForth ("none of them worked
  with FlexProp. No low hanging fruits...."), the author wrote his own
  "within one day", a `switch` "compiled into jmprel", and measured
  "P2CCForth : TaQoz : C_with_FCACHE = 1:4:24", adding the next day, for a
  reader who had read it backwards: "it's 4 times SLOWER. Taqoz is very
  well optimized (over years!) for P2 and completely written in assembler,
  you cannot hope to beat that with something written in C."
- **P2XCForth** (2025-07) keeps the C interpreter and puts under it an
  XBYTE core: 43 core words as 8-bit bytecodes, their PASM in 188 longs of
  the first 256 longs of LUT, dispatched by the P2's XBYTE hardware, which
  fetches a bytecode through the FIFO and looks its routine up in the LUT
  with 6 clocks of overhead. A bytecode $00 is a TRAP: the next byte names
  a word written in C; the core saves its state and returns to the C inner
  interpreter, `inner()`, which runs a `switch` on the trap code and then
  re-enters the core -- `__asm { call startXbyte }` with `startXbyte` a
  local holding $230, the core's entry in LUT -- which resumes at the saved
  instruction pointer. The stacks are in hub RAM, because the C words must
  reach them; TOS, a scratch, a temporary and the three pointers are the
  registers PR0 to PR6, which both the C and the Spin2 side name; the
  parameter stack is addressed through PTRB with auto-increment, PTRB saved
  and restored around the core. The author: "I was astonished to find, that
  it is possible to load permanently a XBYTE machine into a COG, that is
  also executing FlexC or SPIN2" -- the existence proof for a Forth engine
  sharing a cog with flexspin-compiled code, which section 5 rests on. The
  thread's first post gives the two reasons for the layout: "As the stacks
  have to be accessible both from assembler and C they reside in HUB RAM.
  Forth registers are COG registers for speed and also to keep them
  separated, when multiple COGs are executing Forth" -- the second reason
  holds for OctoForth's registers at $1E0-$1EF as well, which are a cog's
  own by construction. Cooperative `pause` multitasking swaps a 1 KB user
  area in under 10 us; words run on other cogs through `cogstart`; locals a
  to e on an auxiliary stack; no `DOES>` yet.
- **The code it compiles** (the thread, 2025-07-16, a `see test` listing):
  a core word is one byte (`8 swap`, `21 >r`, `22 r@`, `25 exit`), a literal
  five (`3 lit 1000`), a trap two (`trap: 2 .`), `doloop` two with a signed
  byte offset (`2a doloop -8`), and a call to a compound word five: `$26 c,
  ,`, the `wcall` bytecode and the code field address, as the author's
  `recurse` of 2026-04-08 compiles it. `i` is a macro for `r@`. There is no
  tracing in the XBYTE machine: "As wcall and exit are done in the XBYTE
  machine, it would be necessary to insert low level tracing there, which
  would slow down everything very much" (2025-07-20) -- native code has the
  same property, so OctoForth's tracing, if any, is a hook `:` compiles.
- **Timing** (the PDF's table, 200 MHz): `1+` 8 cycles; `dup`, `drop` 16;
  empty `do loop` 72 an iteration; call and exit of an empty word 70; the
  trap `j` 167; the trap `*` 280. The Byte sieve (8,192 flags, one pass):
  P2CCForth 293,268 us, P2XCForth 79,460 us, 59,700 with the size compiled
  as a literal, 33,274 with the flags' address compiled as a literal too;
  by the 3.8 ratio TAQOZ takes about 77 ms on the same test, so the core
  is TAQOZ's speed as written and 2.3 times it with the literals -- "P2XCForth
  beats Taqoz in this test, which does not contain any TRAPs in it's loops."
  The author's own reading: "The general rule for speed of P2 is to avoid
  HUB access", and a TRAP "come[s] with much overhead" because the core is
  stalled and the FIFO refilled.
- **A second benchmark, published** (the thread, 2026-04-08): `fact`, the
  recursive factorial, and `fBench`, which counts the iterations of `10
  fact drop` in 10 s of `getms`: 372,018 in the post and 372,552 in a
  second run, so 26.9 us an iteration at 200 MHz, that is 5,380 clocks for
  eleven calls and returns, ten trapped multiplications, the tests between
  them and the loop's own `getms` test; "That's 23 times faster than
  Micropython?!?", against a figure in the MicroPython thread 169862. The
  sieve measures straight-line speed and `fBench` the call path; M2 runs
  both.
- **Where it stands** (the thread, 2025-07-23 to 2026-04-07): P2XCForthD,
  the current archive (742.9 KB), "can now execute machine code routines",
  and an assembler in RPN syntax ("xx d ptra s rdlong" style, the outer
  interpreter doing the assembly) is planned, because "In my opinion it must
  have an assembler to be as useful as TAQOZ"; the author uses it for his
  embroidery machine and for the PropellerBraider, written in the on-board
  editor FED, and has added a Library System to the online help. A machine
  that writes PASM into words is a step toward what OctoForth does for every
  word.
- **Lessons the thread's last post adds** (2026-10-28, from IPS, Karl
  Meinzer's 1979 Forth for the 1802, in the January 1979 BYTE): a hash table
  for the dictionary rather than a linked list, and a task switch hooked
  into EXIT and fired by a timer -- every 20 ms in 1979, "every 4ms or so"
  on the P2 -- which he has tried in the XBYTE `i_exit`: a `jnct3` test of
  the CT3 event, then a LUT entry holding the word to run, a register being
  too scarce to spend. "I think, that the idea to hook the task switch into
  EXIT is a good idea, because this will slow down the system very little,
  as only compound words will be affected." Section 9 has what was
  decided of both; the event is polled, not taken as an interrupt, which matters
  in a flexspin cog (section 4, "The P2's timings").

### 3.3 pfth and the P1 Forths

- **pfth** (Dave Hein, 2012-2014): an ANS Forth in PASM and Forth, indirect
  threaded, two hub reads a word, stacks in hub; ported to the P2 FPGA in
  2014 (the return stack moved to what was then AUXRAM, the LUT); dormant
  since. On the P1 about PropForth's speed, 66 times slower than Tachyon on
  an empty loop [forum snippet].
- **Tachyon** (Peter Jakacki, 2012-): bytecodes on the P1 because "each cog
  only has 512 longs of RAM", about 1 us a bytecode "mainly limited by the
  RDBYTE access times"; V4 (2016) moved to 16-bit wordcodes, which TAQOZ
  inherited.
- **PropForth** (Sal Sanci, 2010-2013, MIT): 16-bit tokens, a cog address or
  a thread, both stacks in cog RAM, the kernel resident in a cog.
  **PropellerForth** (Cliff Biffle, 2007) and **JDForth** (Carl Jacobs,
  2008, a cross-compiler to a threaded image) round out the P1; JDForth's
  author reported Fib(28) in 28.7 s in Spin, 6.5 s in Forth and 0.86 s with
  inline assembly.

### 3.4 Native code on the P1 and the P2: never shipped

No Forth for either chip compiles a colon definition to machine code; every
one found interprets wordcodes, tokens, threads or XBYTE bytecodes. The
steps toward it, all Christof Eb.'s, in order:

- **"Study about an Inline Compiler - Speed, Stack and Inline Assembly"**
  (`forum/1548794/`, 2023-01-19 to 2023-03-13, inside TAQOZ V2.8). Two
  ideas from an earlier thread: "A) Make a compiler, that does not call
  Forth primitives but inlines their assembler code", and "B) Avoid (LUT)
  Stack handling, which involves several movs and a LUT operation each
  time. This would need a complete rewrite of the Forth system." Measured
  on fibonacci(46), 45 iterations of `swap over + loop`, in clocks at 200
  MHz: hub PASM 1176 (the reference, 26 a loop iteration), cog PASM with
  `djnz` 496 (42 percent, 11 an iteration), TAQOZ 6944 (590 percent, 154 an
  iteration), the primitives' code copied inline but the loop still TAQOZ's
  5432 (461 percent), the loop inlined as well 2496 (210 percent); the
  variable-based variants 4,500 to 7,000 percent. His conclusions: "If
  speed is important in Forth, do not use any type of variables but use
  stack words"; inlining "is of low merit, if loop command is not part of
  the inlined code. So the inlining compiler must have own working control
  structures. Then a gain of speed of factor 2.5 is possible using the
  existing stack structure. The code size penalty is factor 4!" Four days
  later, a macro assembler: primitives rewritten as hub code words ending
  in a standalone `ret` -- `In+` is `add b,a`, `sub $18,#1` (the depth),
  `mov a,b`, `mov b,c`, `mov c,d`, `rdlut d,--ptrb`, `ret`: six
  instructions to add, in a model with four register cells and a depth
  counter -- copied without their `ret` between `FOR:` and `inNEXT:`, which
  compiles a `djnz`: 2168 clocks (184 percent, "factor 6944/2168= 3.2 of
  the speed of Taqoz. And about half the speed of Hub assembler code"), and
  1728 (145 percent) with the loop cached in cog RAM. "Unfortunately many
  existing words of Taqoz are not suitable to be inlined, because they end
  with a jump instead of a separate ret." The agent's snippet had read
  "speed gain of 4,6/5,9" as a gain of 4.6 to 5.9 times; it is the move
  from 5.9 to 4.6 times slower than hub PASM, a gain of 1.3.
- **csForth** (the thread `forum/175463/`, 2023-08-09 and 2023-08-13), "this
  tiny just-in-time-compiler": at run time, `csBegin` walks the wordcodes of
  an innermost loop up to `csUntil`, adds each to the encoding of `call`
  ("$FDA0_0000 + the wordcode") and writes the sums into a LUT cache,
  appends the loop test and a `ret`, and runs the cache; only `code` words
  (wordcodes below $17FF, about 260 of them, TAQOZ's locals among them) may
  appear, with no checks, "because they will be treated to calculate jump
  destinations". TAQOZ's `1_000_000 FOR NEXT` takes 160 ms (32 clocks an
  iteration at 200 MHz, the figure in section 3.6); the cached loop 20 ms;
  a counted loop with locals 280,058,648 clocks against 157,044,824, "about
  factor 1.8"; and the fibonacci ratio "cog-assembler : hub-assembler :
  csForth : Forth 42% : 100% : 302% : 590%". So a subroutine-threaded TAQOZ
  with cog-resident primitives sits at 3 times hub PASM.
- **"Pondering about another Forth for P2"** (`forum/1565554/`,
  2025-02-11): beside porting a C Forth and "a Forth compiler for the
  FlexProp nucode-machine", the author laid out "a new direct threaded
  Forth implementation": "Use direct threaded or subroutine threaded code,
  that can inline small core words like Forth09 ... Inlining is limited by
  a size limit per word. IP is the program counter. Code is machine code.
  The idea would be, that this enables the micro cache of P2 to chime in.
  Downside is low code density"; the data stack on PTRA with PUSHA/POPA,
  "only TOS and NOS (2nd) in cog ram", the return stack on PTRB with
  CALLB/RETB, "So the stacks are in HUB Ram and can be switched easily";
  and the obstacle: "As this machine would not be capable of calling high
  level code of other languages (at least I don't know how) perhaps a
  ServerCog could be used." Wuerfel_21 answered the stack question the
  same day: "PUSHA and POPA are just aliases for WRLONG x,ptra++ and RDLONG
  x,--ptra. These are capital-S Slow instructions (3..10 cycles and 9..16
  cycles, respectively), so there's your motivation to use the LUT
  instead", and on task switching, "If the stack isn't close-to-full,
  simply swapping it in/out of LUT should come out faster than having it in
  hub to begin with unless you're switching tasks only to run a few
  instructions and switch back." Three days later the author had started
  P2CCForth in C instead, and five months later P2XCForth; the machine-code
  direction was named, costed and left. OctoForth is that direction with
  the two answers the thread gave: the stacks in LUT, and a call into the
  host language, which P2XCForth's TRAP later showed possible for its
  bytecode engine and section 5 makes the native engine's.

The reasons given for wordcodes were compactness ("each assembly language
instruction consumes 32 bits of memory whereas TAQOZ high level words only
need 16 bits", the inline-assembly guide) and the ROM's 12 KB; on the P1 the
496 cog longs decided it. A 2018 idea of a Forth backend for fastspin
stalled on local variables [forum snippet]. The one JIT on the P2 is not a
Forth: Eric Smith's riscvp2 translates RISC-V to P2 instructions into a
cache in hub RAM or LUT and runs them "at full speed on the P2, except that
there is some latency for the initial compilation"; its documentation takes
no FIFO precautions, so the write-then-branch pattern of section 4 is in
production there.

### 3.5 Native-code Forths elsewhere

Read: the Mecrisp-Stellaris and zeptoforth sources, the Mecrisp folkdoc,
Pelc's EuroForth papers of 1998 and 2000, Moving Forth, the CamelForth/Z80
source, the fig-FORTH 8080 listing.

- **Mecrisp-Stellaris** (Matthias Koch, GPL v3+, Cortex-M). "Generates
  native code with constant folding and inlining of short words"; the core
  is about 14 KB of flash and 1.5 KB of RAM. TOS in r6, the data stack
  pointer r7, the return stack on the CPU stack (r13), r4 and r5 the loop
  index and limit. `:` writes `push {lr}` and `;` writes `pop {pc}`; the
  register-allocating kernel leaves a leaf definition with no prologue and
  a `bx lr`. A call is a 4-byte `bl`. Inlining is copying: "Copy the whole
  code of a definition into Dictionary. There are three special opcodes:
  push {lr} will be skipped, pop {pc} is end of definition, bx lr is end
  often used in core" -- which is why literals are built with `movs`,
  `movw` and `movt` and never read from a literal pool: the code must stay
  position-independent to be copied. Constant folding is by count: each
  word says how many constants it folds (`+` and `swap` two, `rot` three),
  literals are kept pending on the stack rather than compiled, and a word
  meeting enough of them is run at compile time instead of compiled. `if`
  is `cmp tos, #0` and a `beq` patched by `then`; `do` saves the outer loop's
  r4 and r5 on the return stack and loads the new ones, so `i` is always a
  register and `j` a read of the return stack. `<builds` leaves a slot that
  `does>` patches with a call. The RA kernel "keeps track of the top five
  stack elements and maps them to registers whenever possible" and returns
  the stack to canonical form (TOS in r6, the rest in memory) before any
  call. Mecrisp-Quintus does the same on RISC-V and Mecrisp-Across, a
  cross-compiler for the MSP430, adds whole-program optimization. These are
  the design to follow where the P2 allows it.
- **zeptoforth** (Travis Bemann, MIT, Cortex-M and RP2040/RP2350). "Basically
  subroutine threaded, but a significant portion of words, especially
  primitives, are inlined"; the same registers as Mecrisp (TOS r6, data
  stack r7, return stack on sp); `inlined_flag` words copied up to a marker,
  `fold_flag` words folding a pending literal into `adds tos, #imm` and its
  kin; DO/LOOP parameters on the return stack; `<builds`/`does>` by a
  patched literal and a `bx r0` tail jump; a preemptive priority
  multitasker with a 100 us tick and per-core queues on the RP2040.
- **SwiftForth** (FORTH, Inc.): subroutine threaded, "direct code in place
  of subroutine calls wherever possible", an INLINE flag, EXIT as RET or a
  tail call, a rule-based optimizer; TOS in EBX, the data stack through EBP,
  the return stack the CPU's. **VFX Forth** (MPE; Pelc 1998, 2000): "The
  optimiser defers code generation for as long as possible", keeps a stack
  model in which "pure stack operations such as SWAP and DUP simply modify
  the stack model", and restores "a canonical stack representation
  consisting of the top of the data stack in a register, the other items
  being indexed from a data stack pointer" at procedure boundaries; "about a
  fourfold improvement over simple subroutine threading and inlining";
  source-level inlining of short factors superseded binary inlining. Pelc's
  rule of thumb: "Basic STC is usually twice as fast as any ITC or DTC
  Forth, but it will be larger (say 20%)", pattern-matching generators 4:1
  or more, analytical compilers 10:1 or more.
- **The 8080 and Z80 precedents.** CamelForth/Z80 (Rodriguez, 1994): "SP =
  PSP Param Stack Pointer; IX = RSP Return Stack Pointer", BC = TOS, DE = IP,
  direct threaded; Moving Forth gives the reason, SP because the parameter
  stack is used more and IX/IY are slow, and the rule quoted in section 1.
  fig-FORTH 8080: SP "SHOULD BE USED ONLY AS DATA STACK", the return stack
  pointer a memory variable RPP, IP in BC, W in DE. Loeliger's Z80 TIL
  (1981): SP the parameter stack, IX the return stack. All threaded: a return
  address never lands on the data stack. The one documented native-code
  Forth that puts the data stack on the CPU stack is M4_FORTH (DW0RKiN, Z80,
  modern): TOS in HL, NOS in DE, the third cell on [SP], and a called word
  pops its return address first and stores it into its own exit jump, so it
  is not reentrant; a variant leaves the return address on the stack and
  then reaches only TOS and NOS. That is the 8080 idiom the user's Forth
  will have lived by -- `POP H` at entry, `PUSH H` and `RET` or `XTHL` to
  reach data under a return address -- and no 1980s system doing it could
  be found, so the user's may stand alone.
- For citation: Loeliger, Threaded Interpretive Languages (BYTE Books,
  1981); Ertl's "Threaded Code" page and the RAFTS papers (EuroForth 1992,
  1996, 1997; Gforth 3.3 to 4.5 times on small benchmarks); Ertl and Gregg
  on dynamic superinstructions and stack caching (PLDI 1995, IVME 2004);
  Jonesforth (Jones, 2009, ITC, %esp the parameter stack).

### 3.6 The anchors, side by side

Clocks per operation at one frequency; TAQOZ's and P2XCForth's measured by
their authors at 200 MHz, OctoForth's for code in hub RAM with the data
stack in LUT through PTRB and TOS in a register (section 5), measured by
probe M0 where the cell says so (section 4, "Probe M0") and estimated from
the instruction spreadsheet otherwise:

| Operation | TAQOZ V2.8 | P2XCForth | OctoForth |
| --- | --- | --- | --- |
| `1+` | 24 | 8 | 2 (`add tos, #1`), measured |
| `DUP` | 48 | 16 | 2 (`wrlut tos, ptrb++`); with DROP 5, measured |
| `DROP` | 48 | 16 | 3 (`rdlut tos, --ptrb`) |
| `+` | 48 | 8 + a hub read | 5 (`rdlut t, --ptrb`, `add tos, t`); `3 +` 9 unfused, measured, 2 folded |
| a literal | 10-bit inline | 8 + a hub read | 4 (`wrlut`, `mov`) to 511, 6 with `augs` |
| `@` | 32 | 8 + a hub read | 9 to 26 (`rdlong tos, tos`, in hubexec); 17 to 18 a read in a row, measured |
| `!` | 64 | 8 + two hub accesses | 9 to 26 (`rdlut`, `wrlong`, `rdlut`) |
| `*` | 128 | 280 (a trap) | about 60 (CORDIC `qmul`, `getqx`) |
| empty loop, an iteration | 32 | 72 | 16 in hub RAM (an `add` and a `djnz`), the same under `REP`; 6 in LUT RAM, 2 under `REP` there; measured |
| call and return of an empty word | not measured | 70 | 34 (`calld pb` and `jmp pb`), 8 more for a word that calls, measured; 0 when inlined; CALLA/RETA 70, measured |
| a fibonacci iteration, `swap over + loop` | 154 (measured, section 3.4) | not measured | 35 in hub RAM by M0's branch cost, primitives copied; 19 in LUT RAM under `REP`; 112 to 161 if the primitives were called |

The last row is the check against the one measured series on the P2 (the
inline compiler study, section 3.4, at 200 MHz): hub PASM 26 clocks an
iteration, cog PASM 11, TAQOZ 154, csForth about 79, TAQOZ with the
primitives and the loop inlined 55, the macro assembler's loop 48 and 38
cached in cog RAM. SWAP in the model here is `rdlut t, --ptrb`, `wrlut tos,
ptrb++`, `mov tos, t` (7 clocks), OVER `wrlut tos, ptrb++`, `rdlut tos,
ptrb[-2]` (5), `+` 5, and LOOP an `add`, a `cmps` and a taken `jmp` (18 in
hub RAM by M0's 14-clock taken branch, 8 in LUT RAM, and under `REP` in LUT
RAM nothing but the index's `add`; `REP` in hub RAM costs what the branch
does).
So, on the study's scale where hub PASM is 100 and TAQOZ 590: primitives
called, 430 to 620, TAQOZ's own band; primitives copied, 130 to 157, which
is the study's best figure with one TAQOZ stack shuffle less per word;
copied and cached in cog RAM, 65 to 73, where hand-written cog PASM is 42.
Hence section 5 copies every primitive, as Mecrisp does, and calls only
colon words above a size threshold.

The estimates say where the design must put its effort: a taken branch from
hub RAM is 13 to 20 clocks (the spreadsheet; 19 measured by p2-11), which is
a third to a half of every loop iteration and of every call, so copying
the primitives is the design and not an option (it is the difference
between TAQOZ's speed and 4 times it), inlining small colon words is the
same saving again on the call path, and running hot loops from cog RAM is
the difference between 4 times TAQOZ and 8. The memory-bound case is a
draw by construction: `@` is one `rdlong` in every Forth, and in hub
execution a hub read can cost up to 10 clocks more than in a cog-resident
kernel while the FIFO refills after a branch (TonyB_, 2022-09-26: "hub RAM
reads and writes in hub exec mode can be 10 cycles slower than in cog/LUT
exec mode. This is due to the FIFO reloading when six longs are free, i.e.
every six instructions after a branch"; a write "as high as 20 cycles in
hub exec mode, compared to 10 max for cog/LUT exec"; `forum/174869/`).

## 4. Facts established in this session

**OctoGo today** (../ogo at v1.0.0-rc.2, 2026-10-28; README.md, specs.go,
CLAUDE.md):

- The compiler emits C, which flexspin's C compiler (flexprop v7.7.0,
  spin2cpp pinned at b5993a84, transpiled into `ogo` itself) compiles to P2
  assembly. There is no heap and no garbage collector; a goroutine is a cog;
  a channel is a hardware lock over a cell in hub RAM.
- `unsafe` has `Pointer`, `Add`, `Slice`, `Sizeof`, `Alignof` and `Offsetof`;
  a `Pointer` converts to and from `uintptr`; a store through a converted
  pointer, `*(*uint32)(p) = v`, works; a value is read at a fixed hub
  address, `*(*uint32)(unsafe.Pointer(uintptr(0x14)))`. That is all a code
  generator needs to write instructions into a package array and to hand
  their address on.
- A function value is a C function pointer, one word, and the spec allows a
  pointer to one function type to be read as another through
  `unsafe.Pointer` (noteFuncValuePun), so a function's address is a number
  a program can take.
- **A function declared without a body is a Spin2 object's PUB method**
  (specs.go, "Functions implemented in Spin2"): a `.spin2` file beside the
  package's `.ogo` files; arguments and the single result cross as longs; the
  method may start PASM on a cog of its own or run inline PASM on the calling
  cog, "where every clock counts". p2-11's `core` package is the model: 122
  lines of OctoGo binding `start`, `stop`, `execute` and `bind` to a 1,420
  line PASM core started with `coginit(16, @entry, b)`, its cog and LUT
  loaded from a hub image, its handshake a long the program writes and the
  core clears, polled in the method's inline assembly. A package with a
  Spin2 object builds for the board only; its host twin leaves it out.
- The `p2` package wraps the serial line both ways (`ReadByte`, `WriteByte`,
  `SetBaud`), pins and smart pins, timing and the clock, the locks, and the
  LUT at addresses 0 to 255 (`ReadLUT`, `WriteLUT`), that is LUT $200-$2FF,
  "which flexcc leaves to the program while no function is placed in LUT
  (nothing OctoGo emits is)". Measured there, hub execution on a P2-EDGE:
  RDLUT 3 clocks, WRLUT 2, against RDLONG 15 and WRLONG 8 (15 for one alone).
- A function's locals live in cog RAM, 480 longs for the backend's whole pool;
  a function outgrowing it fails to build. Small functions are inlined (six
  statements at most). A dense constant `switch` is a C switch since
  2026-10, dispatched through a jump table.
- A minimal program is small: `_examples/life` built with `--report` takes
  11,468 bytes of hub RAM (header 1,028, cog runtime 1,332, code 7,284 in 44
  functions, the rest data and tables), leaving 511,576. p2-11, 219
  functions, is 79,872 bytes of code.
- `ogo build` writes the backend's listing beside the binary, `<name>.p2asm`,
  which is how the two register facts below were read.

**What the backend does with the cog** (p2-11's listing `p2-11.p2asm`, a test
build made here, and flexspin's `doc/general.md`, `doc/c.md` and
`doc/spin.md`, read 2026-10-28):

- Compiled code runs from hub RAM (hubexec), from $400 up. The cog's own
  code (`orgf 256`, `fit 480`) occupies $100-$1DF: the FCACHE loader, the
  fills, the register pool `_var01`..., `arg01`..., `local01`..., `result1`
  to `result4`, `objptr`, `fp`, and the pointers to each object's data.
- **COG $000-$0FF is the FCACHE**: a loop that calls nothing is copied there
  (`FCACHE_LOAD_` reads it to `$0` and jumps to `$0`) and runs at cog speed.
  flexspin: "When no FCACHE is in use, it may be used as scratch."
- **COG $1E0-$1EF "is left free for application use"** (flexspin, verbatim),
  the sixteen longs below the special registers at $1F0-$1FF. **PR0-PR7 are
  $1E0-$1E7**, measured here: a three-method Spin2 object (`PR0 := v`,
  `r := PR0`, and `mov r, #PR0` in an `org`/`end` block) built with `ogo
  build` into a listing writing `mov pr0, #123` and `mov _var01, #pr0`, the
  binary decoded to D = $1E0 and S = $1E0. So a Spin2 method reads and
  writes the engine's registers by name, with no PASM, which is how the
  REPL will see TOS and the stack pointers; and P2XCForth's use of PR0-PR6
  under FlexC is the same fact in production.
- **LUT $200-$20F is always free; $210-$2FF is free when no function is
  placed in LUT** (OctoGo places none); **$300-$3FF is the backend's** and
  must not be touched. P2XCForth's 188-long core lives in exactly this
  range beside FlexC code.
- **PTRA is the stack pointer**, the stack growing up; "applications should
  avoid using it". `pushregs_` and `popregs_` save a non-leaf function's
  shared locals there (`wrlong local01, ptra++`), which is why such a call
  costs 150 to 160 clocks. A leaf's return address stays on the eight-level
  hardware stack (`call`/`ret`); `pushregs_` pops it into `RETADDR_`.
- **PA is the FCACHE loader's**; **PTRB** is used by the loader and restored
  (`fcache_tmpb_`); the listing of p2-11 has no other use of PTRB and none of
  PB. P2XCForth uses PTRB as its parameter stack pointer and saves and
  restores it around the core; the engine here does the same, in the
  trampoline.
- **Inline assembly** in a Spin2 method comes in three forms: `org`/`end`
  is copied into the FCACHE and runs from cog RAM, 128 longs by default,
  "not optimized", with "`call` instructions may not be used" (spin.md);
  `orgh`/`end` runs from hub RAM, unoptimized; `asm`/`endasm` runs from hub
  RAM and is optimized with the surrounding code. It may name only hardware
  registers and the method's locals; "branching outside the function or
  calling another function is not supported" and "may appear to work in some
  cases" before failing (general.md). What P2XCForth shows is that a `call`
  through a local, from C's optimized `__asm { }` -- the form Spin2's
  `asm`/`endasm` is -- into code that keeps the backend's conventions and
  returns with `ret`, works in production; M0 did the same from a Spin2
  method's `orgh`/`end` block into generated hubexec code on 2026-10-28,
  and it works (below, "Probe M0"). The trampoline must
  not be `org`/`end`, both for the `call` rule and because generated code
  may use the FCACHE area itself (section 5).
- `_coginit(cogid, cogpgm, ptra)` starts PASM on a cog with PTRA set, and a
  Spin2 object's `coginit(16, @entry, ptrb)` the same with the next free cog;
  p2-11's core loads the rest of its image itself from the address in PTRB.

**The P2's timings** (the official instruction spreadsheet, the datasheet of
2021-07-09 and the Propeller 2 Documentation, as the second survey read
them; a column "Cog Exec Mode / LUT Exec Mode" beside one for "Hub Exec
Mode", so LUT execution costs what cog execution costs). Every math and
logic instruction 2 clocks, the same in hub execution, with "a five-stage
pipelined execution architecture" and "the first instruction following the
branch will take at least five clock cycles". `JMP`, `CALL`, `RET`, `CALLD`,
`JMP D`: 4 clocks in cog or LUT, 13 to 20 from hub, "a minimum of 13 clock
cycles" plus one if the target is not long-aligned; the conditional branches
(`TJZ`, `DJNZ` and their kin) 2 when not taken, 4 taken in cog, 13 to 20
taken from hub. `RDLONG` 9 to 16 in cog, 9 to 26 in hub execution; `WRLONG`
3 to 10 and 3 to 20, the spread the hub's rotating slot and, in hub
execution, the FIFO refilling after a branch. `CALLA` 5 to 12 in cog and 14
to 32 from hub; `RETA` 11 to 18 and 20 to 40. `RDLUT` 3, `WRLUT` 2, and both
take the PTRx forms (`wrlut tos, ptrb++`, `rdlut tos, --ptrb`), so a LUT
stack needs no pointer arithmetic of its own. `AUGS` and `AUGD` 2 clocks
each, the pair shielded from interrupts, so `mov reg, ##imm` is 4 clocks
and two longs. `ALTS`/`ALTD` 2 clocks, so a cog-RAM stack costs 4 an access.
`REP` repeats a block with a 0-clock loop-back in cog and LUT RAM; the
spreadsheet lists it for hub execution too, with no statement of what the
loop-back costs there, and M0 measured it: what a taken branch costs, so
`REP` gains nothing in hub RAM. XBYTE dispatch is 6 clocks of overhead, 8 for a
minimal bytecode. `COGINIT`: the started cog gets S in PTRB and a preceding
`SETQ`'s value in PTRA, and a `%1_x_xxxx` D starts it at a hub address
directly, in hub execution, without the 504-long load of a cog image.

**The P2 itself** (the datasheet). Eight cogs, each with 512 longs of cog
RAM ($000-$1EF general purpose, $1F0-$1F7 general purpose unless their
interrupt, PA and PB functions are used, $1F8-$1FF the pointers and pins)
and 512 longs of LUT, 512 KB of hub RAM shared by all; 32-bit instructions;
9-bit immediates, extended to 32 bits by AUGS or AUGD; branches carry a
20-bit absolute or relative address, so one instruction reaches the whole
space, and "absolute addressing is highly recommended, and forced by the
assembler, when crossing between cog and hub domains"; CALLA/RETA and
CALLB/RETB push and pop through PTRA and PTRB; `CALLD` writes the return
address and flags to any register, PA, PB, PTRA or PTRB among them with the
20-bit form, and `JMP D` returns through it; the CORDIC does a 32x32
multiply or a 64/32 divide in about 55 clocks, pipelined, where the 2-clock
MUL is 16x16; sixteen hardware locks; `cogid`, `coginit`, `cogstop`. Code
executes from any hub address from $400 up ($000-$3FF address the cog and
the LUT), so a program array is a code space. The FIFO that feeds hub
execution holds 19 longs and reloads whenever "a full branch takes place";
so code written up to 19 longs ahead of the instruction being executed may
already be fetched, and code reached through a taken branch is read fresh.
A compiler that never runs the word it is writing, and enters every word by
a branch, meets no hazard; riscvp2 runs on the same assumption.

**What a clock buys on this target, measured.** p2-11/OCTOGO.md, on a P2-EC
at 160 MHz, code in hub RAM, 2026-10-02: a taken jump 19 clocks from hub RAM
and 4 from cog or LUT RAM; a hub read 25 to 37, a write about 10; a leaf
call about 40 with its return; a function that calls another 150 to 160 a
call besides. These agree with the spreadsheet's ranges.

**Hub execution against cog execution, measured by others** (the thread
`forum/174869/`, 2022-09, FlexProp at 200 MHz, fibonacci(46) as a loop of
45 iterations):

- The same loop from the FCACHE and from hub RAM (`--fcache=0`, evanh,
  2022-09-28): 5.37 us against 7.40 us, 1.4 times; unoptimized, Christof
  Eb. measured 1.7 ("Cog exec will have ~2 * speed vs Hub exec"). That is
  the whole gain of a cog cache for a loop body of ALU instructions; the
  gain is larger when the body is short and the branch a larger share.
- The loop's own shape in cog RAM (Wuerfel_21, 2022-09-28): a `for` loop
  compiled to `cmps`, a conditional `jmp` and a `jmp` back, 22 clocks an
  iteration; the same body under `rep` after a `do while (--n)`, 8 clocks,
  which is the four ALU instructions alone -- `REP`'s loop-back is free
  in cog RAM, as the spreadsheet says, and the reason M4 wants it.
- Where the variables live matters more than where the code runs: locals
  in cog registers against globals in hub RAM, 5.7 us against 33.6 us, "about
  6 times"; evanh: "HubRAM data accesses will be bigger negative impact
  than hubexec code because hubexec has the FIFO providing substantial code
  prefetching. That said, a small inner loop is still costly for hubexec.
  Each branch is a reload of the FIFO." Hence TOS in a register and the
  stacks in LUT, not in hub RAM as P2XCForth's are.
- Interrupts: "The Flex suite is not written as interrupt safe. Mixing an
  ISR with compiled code on the same cog will cause data corruption in the
  compiled code" (evanh, 2022-09-24; Chip's Spin2 interpreter shields its
  critical sequences with `REP #1`). So under design A nothing in OctoForth
  may run from an interrupt; a timer-driven task switch (section 9, point
  7) polls the CT event, as P2XCForth's `i_exit` does with `jnct3`. An
  engine cog (design B) runs no flexspin code and may take interrupts.

**Probe M0, measured 2026-10-28** (`probe/m0`, ogo
v0.58.1-0.20261025171618, the P2-EDGE at 160 MHz; the counts are clocks,
which do not depend on the clock frequency). A Spin2 object holds PASM
templates in its `DAT` and a method `run(xt, fresh)`, an `orgh`/`end` block
that saves PTRB, sets it to the data stack pointer kept in PR7, takes
`getct`, enters the word by `calld pb, xt` and takes `getct` again. OctoGo
copies templates from the `DAT`'s hub address, read through
`unsafe.Pointer`, into a package array, ORs addresses into the `calld`
and `calla` templates, and runs the result. Each figure is the code's own,
the cost of entering an empty word subtracted, and the same within 8
clocks over three loads, and again so with ogo v1.0.0-rc.3 on
2026-10-29:

| What | Clocks |
| --- | --- |
| `add pr0, #1`, a hundred in hub RAM | 2.0 each |
| a push and a pop, `wrlut tos, ptrb++` and `rdlut tos, --ptrb` | 5.0 |
| `3 +` unfused: a push, `mov tos, #3`, a pop to a temporary, `add` | 9.1 |
| `rdlong`, ten in a row at one address | 17 to 18 each |
| a loop iteration in hub RAM, `add` and a taken `djnz` | 15.9 |
| the same under `REP`, in hub RAM | 15.9 |
| the same in LUT RAM | 5.9 |
| the same under `REP`, in LUT RAM | 1.9 |
| a call and return of an empty word, `calld pb, #\B` and `jmp pb` | 33.6 |
| a calling word's frame, PB saved to and restored from the LUT return stack | 8 |
| a call and return by `calla` and `reta` on the C stack | 70.4 |
| entering an empty word from the Spin2 method and back | 30 |
| a trap: from the word to OctoGo, a dispatch that does nothing, and back | 228 |

What it showed:

- **Design A works.** The method compiles to a leaf that keeps its state in
  `_var01` to `_var05`; the generated code touches only PR0-PR7, PTRB, PB
  and LUT 0-255, and the program's listing has no other use of PB. A Spin2
  method cannot be named after a register: names are case-insensitive, and
  `pR0` collided with PR0.
- **Templates copy.** A relative branch assembled in the `DAT`
  (`djnz pr1, #$-1`) runs unchanged copied into hub RAM and into LUT RAM:
  its offset counts instructions in both. Nothing in the probe needed an
  encoder but the 20-bit address ORed into `calld pb, #\0` and `calla #\0`.
- **Traps work.** A word asks with a request in PR2 and `calld pr3, pr5`,
  PR5 holding the method's return point; OctoGo serves it -- printing TOS
  and popping the data stack with `p2.ReadLUT` directly -- and re-enters at
  PR3 through the same method, leaving PB alone, so a word that traps from
  inside another returns to its caller afterwards. `7 8 + .` compiled to
  code printed 15 through OctoGo and went on to `1+`; a word B called from A
  printed and returned to A. 228 clocks a round trip against P2XCForth's
  167 to 280, most of it OctoGo's dispatch.
- **Design B works.** A word compiled at run time, started with Spin2's
  `coginit(HUBEXEC_NEW, xt, par)`, ran on a cog of its own from its hub
  address and wrote its result where PTRA pointed. PTRA gets the parameter
  and PTRB the start address: the first try wrote through PTRB and
  overwrote its own first instruction.
- **The return stack is the LUT's.** 34 clocks a call and return with
  CALLD and PB, 8 more for a word that calls, against 70 with CALLA/RETA.
- **`REP` pays only in cog or LUT RAM.** In hub RAM its loop-back costs
  what a taken branch does. A loop copied into LUT with `p2.WriteLUT` and
  called at $200 plus its index runs 2.7 times faster, 8 times under `REP`:
  the cog cache of M4 is where `REP` belongs.
- Against section 3.6's estimates: the ALU, LUT and call costs as estimated
  (a call and return 34 against 35 to 49), a hub loop iteration 16 against
  17 to 24, and `REP` in hub RAM the one estimate that was wrong.

**The board and the room.** The P2-EDGE on /dev/ttyUSB0 is shared with the
ogo, p2-11 and obeam sessions under `flock -w 900 /tmp/p2-board.lock`. Its
flash held TAQOZ Reloaded until obeam wrote its hello program there on
2026-10-17; at the user's word it holds TAQOZ Reloaded V2.14.0 again since
2026-10-28 (the image of 2024-02-19, written by its own `BACKUP FLASH`),
which the board boots after a reset with no loader, and which M2's
comparison measures. The ROM's TAQOZ, V1.1 of 2019-02-19, which the loader
enters with `-xTAQOZ`, was measured first, when the flash held obeam's.
P2XCForth's `_BOOT_P2.BIX` is built for a 25 MHz Kiss board and does not
run as it is; its C and Spin2 sources compile for the EDGE with the flexspin
`ogo` embeds, which M2 did (`scripts/p2xc.sh`), so all three Forths ran on
one board. The machine is shared with
the builder VMs: one heavy run at a time, after `uptime` and `free -g`. The
ogo session is in rc.2's two-week public window; a request to OctoGo from
here should be small and late.

## 5. The shape of version 1

**Two places the engine can run, and the call.**

A. **On the OctoGo program's own cog.** The REPL calls `run(xt)`, a Spin2
method whose hub-resident inline PASM saves PTRB, points it at the data
stack in LUT, calls the word's code and restores PTRB when it returns. The
generated code owns $1E0-$1EF, PTRB, LUT $200-$2FF and, while it runs, the
FCACHE area $000-$0FF; the OctoGo program reads TOS and the stack pointers
through methods that return PR0-PR7, sees the dictionary and the LUT
directly, prints with `printf`, reads the serial line with `p2.ReadByte`,
and a word calls back into OctoGo by returning to the trampoline with a
request (a trap, P2XCForth's mechanism: the trampoline hands the request to
OctoGo, which serves it -- `EMIT`, `KEY`, `COMPILE,`, the SD card -- and
re-enters the code at the continuation the word left in a register;
P2XCForth's traps cost 167 to 280 clocks, which is the budget for words
that are not hot). No handshake, no second cog, and the Forth has the
program's functions within reach. Its risk is the probe above and a crash:
a word that jumps into garbage takes the REPL's cog with it, which TAQOZ's
users know well; the mitigation is a REPL on a goroutine's cog with `main`
as a watchdog, later.

B. **On an engine cog of its own**, p2-11's `core` pattern: `coginit` with
a PASM image that sets up its stacks and waits on a command long; the REPL
writes an xt and waits; the engine runs it and clears the long; the top of
the stack is mirrored to hub at each return so `.S` can print it; `EMIT` goes
through a ring in hub RAM the REPL drains. Proven in every part, isolated
from crashes (`cogstop` and start again), the whole cog's registers and LUT
free, and the natural way to run a word on another cog. Its costs are a
handshake per interactive word (a few microseconds, irrelevant), and that a
word cannot call an OctoGo function, only ask the REPL to.

**The call: A for the REPL, with B's image for `RUN`**, the generated code
written to run on either, which costs it nothing since the sixteen registers
and the LUT are enough; and B alone if A had failed. M0 found both working
(section 4, "Probe M0"), so the call stands, for the user confirmed
with the decisions of section 9.

**The engine's register file.** The data stack pointer is PTRB, so a push is
`wrlut tos, ptrb++` and a pop `rdlut tos, --ptrb`, 2 and 3 clocks. Of the
sixteen free registers: TOS in PR0; the loop index and limit in two
registers, the outer loop's saved on the return stack at `DO`, as Mecrisp
does, so `I` is a register and `J` a LUT read; RP, the return stack's LUT
index (or none, if the return stack is PTRA's); a scratch W for addresses
and literals; four temporaries for the primitives (ROT needs two, `!` one);
the rest spare for later peephole work (NOS in a register, as VFX's stack
model would want). The flags C and Z are the word's own between instructions
and nothing is assumed across a call.

**The two stacks in the LUT.** 256 longs between them to begin with, say 160
data and 96 return, depth checked at a word's entry in a checked build and
not in a release one, as OctoGo does with its own stacks. On an engine cog
the whole LUT is free and both can be deeper. The return stack's alternative,
PTRA with CALLA/RETA, was measured by M0: 70 clocks a call and return,
against 34 with CALLD and PB as the link register and 8 more for a word
that calls, which saves PB on the LUT return stack. So the return stack is
the LUT's, as Wuerfel_21's answer to P2XCForth's author about PUSHA/POPA
foretold (section 3.4). A task switch, if one comes, copies the used part
of both LUT stacks to and from hub RAM with `SETQ2` block transfers, which
Wuerfel_21 judged cheaper than keeping the stacks in hub RAM in the first
place.

**The compiler.** The primitives are PASM in the Spin2 object's DAT, each
between a begin and an end label, position-independent (branches within them
relative, nothing on the hardware stack, no absolute reference but to hub
addresses that do not move), and a PUB method hands OctoGo their offsets, as
p2-11's core hands the places of its labels. Compiling a primitive is copying
its longs, Mecrisp's way, and literals are `AUGS` and `MOV` for Mecrisp's
reason: a word with no literal pool and no absolute branch inside it can be
copied into its callers. The compiler's own encoder emits a dozen shapes:
`mov tos, ##n`, the data-stack push and pop, `calld` to a word, the word's
return, `jmp` and the conditional branches of IF, ELSE, THEN, BEGIN, UNTIL,
WHILE, REPEAT, DO, LOOP, +LOOP, and the DOES> prologue. Two optimizations
are in from the start because they are cheap and change the numbers:
Mecrisp's pending literals, so that a literal followed by an arithmetic
primitive folds into the immediate form (`3 +` is `add tos, #3`, 2 clocks;
P2XCForth's sieve went from 79 ms to 33 ms on literals alone) and literals
meeting a foldable word are computed at compile time; and a word whose code
is under a threshold (eight longs, say) is inlined into its callers rather
than called, since a call and its return are two hub branches. A third,
copying a hot loop into LUT RAM (M0 ran one there: 6 clocks an iteration
against 16 in hub RAM, 2 under `REP`), the FCACHE area or an engine cog's
spare RAM, is designed and measured in M4, which took the FCACHE area:
the LUT's free half holds the stacks, and the other half is the
backend's. VFX's full stack model is not version 1's.

**The dictionary** is OctoGo's: a package array of headers (name, flags, the
code address, the code's length for inlining, a link), looked up by the
interpreter in OctoGo -- hashed, as IPS did in 1979 and P2XCForth's author
now recommends, since OctoGo has arrays and no maps; a word's code lives in
a package array of longs sized at build time (256 KB to begin with), which
`HERE`, `ALLOT`, `,` and `C,` address. CREATE/DOES>, VARIABLE, CONSTANT,
IMMEDIATE, POSTPONE, `'`, `[']`, EXECUTE, `>R` `R>` `R@`, `."` and `S"` with
their strings in the code space, `<# # #S #>` and `.`, are the ANS CORE words
version 1 carries; files, the heap words and the search-order words are not.
Case-insensitive names, 32-bit cells, decimal and hex, as TAQOZ users expect.

**The P2 words** mirror the `p2` package name for name as obeam's `p2` module
does, so the three documentations agree: `PIN-HIGH`, `PIN-LOW`, `PIN-TOGGLE`,
`PIN-IN`, `PIN-START`, `WAIT-MS`, `GET-CT`, `CLOCK-FREQ`, `RND`, the LUT and
the locks, and `RUN` for a word on a cog with `COG-ID` and `COG-STOP`.

**Tests.** The interpreter, the dictionary, the number conversion and the
encoder are Go once given a package clause and run under `go test` on the
host, as p2-11's and obeam's twins do; the encoder's oracle is flexspin's own
assembler, fed the same instructions through `ogo`'s backend and compared
word for word. On the board, `ogo test` runs the words' tests under the board
lock, and a benchmark package runs the Byte sieve and the empty loop that
TAQOZ and P2XCForth published, all three at one clock on one board, which is
the comparison the forum post rests on.

## 6. Milestones

| | What it shows | Mostly |
| --- | --- | --- |
| M0 | **Done 2026-10-28** (section 4, "Probe M0"; `probe/m0`). The probe: a Spin2 object with the hub-resident `run(xt)`, a word hand-assembled into a hub array by OctoGo, run on the main cog and back; the trap to OctoGo and back; `calld`+LUT against `calla`/`reta` for a call; `+`, `@`, a literal, a loop iteration, measured against section 3.6; the same word on an engine cog. Decides A or B and the return stack. | board, one or two sessions |
| M1 | **Done 2026-10-28**, with two changes: the encoder's test runs on the board, against what flexspin assembled of the same instructions into the engine's DAT, not on the host; and the inlining of small colon words, which section 5 had in from the start, moved to M4 with the rest of the speed work. The kernel: about sixty primitives as PASM templates, the encoder with its host test against flexspin's assembler, `: ;`, literals with folding, IF ELSE THEN, BEGIN UNTIL WHILE REPEAT, DO LOOP +LOOP, the dictionary, the REPL on the serial line, `.` and `.S` | OctoGo, PASM |
| M2 | **Done 2026-10-28**, and more: the CORE and CORE EXT tests of the Forth-2012 test suite pass on the board with 0 errors; SEE reads a word's code back as the templates it was made of rather than disassembling instructions. CREATE DOES>, VARIABLE CONSTANT, IMMEDIATE POSTPONE `'` `[']` EXECUTE, `."` `S"`, the pictured numbers, comments, `SEE` (a disassembler of the generated code, which debugging needs anyway); the sieve, the empty loop and `fBench` (the recursive factorial, section 3.2) against TAQOZ and P2XCForth on the same board | breadth, the numbers |
| M3 | The P2 words; `RUN` on a cog with the engine image; the embedding API, `import "oforth"`, with a table of OctoGo functions a program exports as words; a Forth monitor in one of the sibling programs as the demo. **Done 2026-10-29**, the demo an example program of this repository's, as decided (section 9, point 6). First the P2 words: the `p2` package's functions as PASM primitives named after them (`PIN-HIGH`, `PIN-IN`, `PIN-START`, `READ-PIN`, `WAIT-MS`, `GET-CT`, `CLOCK-FREQ`, `RND`, the LUT, the locks, `REBOOT`, with `COG-ID` and `COG-STOP`), thirty more primitives, 111 in all, their arguments in the functions' order; a literal pin is folded into the instruction's D field, AUGD before it over 511, so `56 PIN-TOGGLE` is `DRVNOT #56`, and 1,000 toggles in a DO loop repeated by REP take 4,133 clocks, 4 a toggle (9,135 with the pin from the stack). The embedding has its shape already: `forth/` imports only `p2` and `unsafe`, so a program copies the directory, OctoGo taking no external dependencies, and gives `Init` its code and data spaces. Then `RUN ( x1 .. xn n xt -- cog )`, the same day: the engine's image on a free cog, the runner, gives the word registers, stacks and a loop cache of its own, the n cells its stack, and stops the cog when the word returns; a word that calls OctoGo, whose traps only the REPL's cog serves, is refused, the compiler marking a definition that traps or calls one that does; two words blinking the EDGE's LEDs on two cogs ran beside the REPL, and a `RUN` takes 5,282 clocks. Then the embedding: `forth.Define(name, in, f)` makes a function of the program a word, which takes its `in` cells, checked first, by `forth.Pop` and gives its results by `forth.Push` (the user's choice of Push and Pop), a trap numbered after its place in a table of 64; `forth.Serial` gives a program the REPL's console, the reader cog and its ring, and `main.ogo` is four calls. `example/` makes three of its functions words, LEDS, BLINK and PINS, and defines a Forth word with one of them at start by `forth.Evaluate`; it ran on the board | multi-cog, interop |
| M4 | **Begun 2026-10-28**: small colon words inlined (a body of at most 16 longs with no call, branch, trap, EXIT or return-stack word), a call in tail position made a jump, FILL in PASM (378,290 clocks to 73,793 for 8 KB); the Stanford programs, which call many small words, 1.0 to 2.1 times as fast for it (Queens 1,312 ms to 688, Quick 1,808 to 880, Intmm 2,976 to 1,680), Ertl's sieve 9,871 to 8,335. Then the loop cache, the same day: a loop with no call or trap, at most 240 longs, runs from cog RAM $000, the FCACHE area, which the backend uses only between runs of Forth code; five longs before it compare its tag (hub address, and length in bits 27:20) with CTAG, the tag of the loop cog RAM holds, and on a miss the engine copies it in by SETQ and RDLONG; its last long jumps back to hub RAM. A cached loop's inner loops go with it; an impure loop has the loops inside it cached, and the tag spares them the copy when entered again (Quick lost 4.8% when every entry copied, and gained 2.4% with the tag); a loop not cached has its reserved longs cut out when it ends, so it costs nothing; DOES> and a header made inside a loop turn the cache off for the rest of the definition, since their code must stay put. The empty `DO LOOP` 24 clocks an iteration to 8, the Byte sieve 1,771,993 to 1,400,057, Ertl's sieve 8,335 ms to 5,503 and bubble sort 12,558 to 10,207, Fraeman's Bubble 17% faster; the other Stanford programs within placement, as the mean of eight builds that shift the code shows, placement alone moving them by up to 5%. Then `REP`, 2026-10-29: a DO LOOP in cog RAM whose body has no branch, call or trap (nor EXIT, UNLOOP or FILL) is repeated by REP, the block being the body and LOOP's increment of the index, three longs before it setting the count, the limit less the index; LOOP's compare and branch stay after the block for a count of 0, 2^32 iterations, for which the REP is not executed. A loop that cannot be one has the three longs taken out at LOOP. The empty `DO LOOP` 8 clocks an iteration to 2 (800,113 clocks to 200,124), Ertl's matrix multiplication 224 ms to 208; nothing else moved by more than placement, Fraeman's inner loops branching, calling or being `BEGIN` loops. Then `INCLUDE`, 2026-10-29, over the serial line now and from the SD card later behind the same file layer, the user's choice, the card being out of the slot: OctoForth speaks 9P2000, which the loader `ogo` embeds serves from a directory of the host (`ogo loadp2 -t -9 DIR`; a message after $FF $01, the reply found among the console's bytes by its header), so no host program of its own is needed; INCLUDED, INCLUDE-FILE and the read-only FILE words over the same layer, an error reported with the file's name and line, `(` going on over a file's lines; `scripts/f2012.sh` INCLUDEs the suite, 0 errors. Then the whole FILE word set, writing too, the same day: CREATE-FILE, WRITE-FILE, WRITE-LINE, the positions and sizes, RENAME-FILE (within a directory, as 9P renames), DELETE-FILE, FILE-STATUS, FLUSH-FILE, REQUIRED and REQUIRE, SAVE-INPUT and RESTORE-INPUT of a file, two buffers for an interpreted S"; the suite's `filetest.fth` passes, 0 errors. Then CATCH and THROW, the EXCEPTION word set, the same day, beside the milestones: the system's errors are THROWs with ANS's codes (-13 an undefined word, -4 a stack underflow, -1 ABORT, -2 ABORT", whose message only an uncaught one writes), unwound as every error is, each EVALUATE and INCLUDE restoring its input on the way; CATCH runs the word nested and after a THROW puts back the stacks' depths and the innermost loop's index and limit; the suite's `exceptiontest.fth` passes, 0 errors. Then the DOUBLE and STRING word sets, the same day: a number ending in a point is a double; D+ to 2ROT are templates, branchless (ADDX, SUBX and CMPSX carry the low cells' carry and borrow to the high ones), M*/ has a product of three cells, and the substitutions of REPLACES and SUBSTITUTE are kept in a pool, 1 KB then; the suite's `doubletest.fth` and `stringtest.fth` pass, 0 errors. The two cost 10.8 KB of hub RAM, 9.3 KB of it OctoGo's code; 22.7 KB was saved after them, the same evening: the OctoGo words' names a table (4.5 KB of code), the templates' names read in the engine's table and their lengths in their headers (6.2 KB), a word's header 28 bytes, not 36, its places in the code space 16 bits (8.2 KB), the compiler's branch list 16 bits and the output buffer the tests' own (3.8 KB), and then the pool of the substitutions 256 bytes, not 1 KB, 56,128 bytes of the hub to spare in the REPL's binary. Then the SD card behind the file layer, the same night, a card being back in the slot: a name after `sd:` is the card's, a FAT32 volume with long names read and written, every FILE word and INCLUDE working on it (the user's choices); the driver is p2-11's `sd`, pin by pin, a block in 1.43 ms at 160 MHz. The card held another program's boot file, which had to stay: every block in use was copied to the host first, and after every change of the code the card was dumped again and its image passed `fsck.fat -n`; a bug of a first version lost four clusters, mended from the host, and the FAT code since refuses to touch a block outside the FAT. The suite's `filetest.fth` passes on the card, 0 errors (`scripts/f2012.sh -sd`), and `TestCard` too. It costs 27 KB of hub RAM, about 20 KB of it code, OctoGo checking every index and pointer; 29,132 bytes are left to spare, 51,156 if built `--unchecked`. Still to do: the forum post | speed, the showcase |

M1's first numbers, on the P2-EDGE at 160 MHz with ogo
v0.58.1-0.20261025171618, in clocks: an empty `DO LOOP` iteration 24
(TAQOZ 32, P2XCForth 72); a call and return of an empty colon word 40, its
frame included (P2XCForth 70); P2XCForth's own sieve source, one pass,
2,107,257, of which `FILL`, written in OctoGo byte by byte, 378,290, against
6,654,800 for P2XCForth's best (33,274 us at 200 MHz, its author's figure);
`25 fib` 18,118,669. The comparison on one board, with both systems'
loops shown, stays M2's.

M2's comparison, on one P2-EDGE, each system timed by its own counter, in
clocks, the sources in `bench/` and the run `scripts/bench.sh`:

| | OctoForth | P2XCForth D | P2XCForth C | TAQOZ Reloaded V2.14.0 | TAQOZ ROM V1.1 |
| --- | --- | --- | --- | --- | --- |
| an empty `DO LOOP`, 100,000 times | 2,400,020 | 7,200,129 | 7,200,129 | 3,200,288 | 3,200,360 |
| an empty colon word called 100,000 times | 6,400,021 | 13,600,129 | 13,600,129 | 9,600,288 | 9,600,360 |
| the Byte sieve, P2XCForth's source, one pass | 2,077,473 | 6,390,449 | 6,525,649 | 13,546,112 | 15,903,624 |
| `25 fib` | 18,080,718 | 53,969,641 | 54,572,929 | 97,114,008 | 113,623,952 |
| `10 fact` 10,000 times | 14,560,026 | 48,960,129 | 48,320,129 | 42,800,280 | 44,240,360 |

P2XCForth's timings move by up to a tenth with where its words land (one
build of D took 15,200,129 for the calls and 6,611,169 for the sieve); the
column is the build `scripts/p2xc.sh` makes and `scripts/bench.sh` runs.
OctoForth is 2.1 to 3.4 times P2XCForthD's speed and 1.3 to 6.5 times
TAQOZ Reloaded's, the least on the empty loop and on calls, where a hub branch of 14
to 20 clocks is most of the cost, and the most where primitives dominate.
P2XCForth beats TAQOZ where bytecodes do the work (the sieve, fib), and
TAQOZ beats it on the empty loop, the calls and the factorial: TAQOZ's loop
and call machinery runs in cog RAM, and P2XCForth's `*` is a trap. The two
measurements its author and TAQOZ's documented, the empty loop's 72 and 32
clocks, came out exactly, which says the three ran as their authors run
them. The conditions are the README's: TAQOZ Reloaded from the flash (the
ROM's V1.1 measured first, while the flash held obeam's), P2XCForth's
newest, P2XCForthD of 2026-04-07 (attached to its author's forum post; the
project has no repository), built for the EDGE with four changes, its
archive of 2025-07 measured first, and OctoForth's `FILL` written in OctoGo.

Third parties' benchmarks, so that the comparison is not only the
benchmarks of this repository (`scripts/third.sh`, README.md "Third
parties' benchmarks"): Anton Ertl's four and Martin Fraeman's Stanford
suite of 1989, fetched at pinned hashes, run with the changes the script
prints and a published prelude per system, at 200 MHz, timed by the host.
On OctoForth all twelve run and pass their checks: Ertl's sieve 9,871 ms,
bubble sort 12,558, matrix multiply 240, `34 fib` 7,743; Fraeman's Perm 896,
Towers 1,904, Queens 1,312, Intmm 2,976, Puzzle 6,671, Quick 1,808, Bubble
1,920, Trees 3,167. On P2XCForthD Ertl's bubble sort takes 82,960 (its `2@`
and `2!` being the prelude's colon definitions), matrix multiply 1,288 and
`34 fib` 23,477; its sieve does not run (its `+LOOP` ends at equality) and
Fraeman's file does not load (no DOES>). On TAQOZ Reloaded the sieve takes
34,380, bubble sort 78,262, matrix multiply 1,168 and `34 fib` 42,075, its
prelude making CREATE's data its code space; Fraeman's arrays, about 69 KB,
do not fit its 62 KB of room. On Ertl's four OctoForth is 3.0 to 6.6 times
the speed of the other two. The
call is the next thing to make cheaper: inlining small words and a tail
call, M4's.

M0 to M2 is the experiment the user asked about, answered with numbers; M3
is what makes it different from every Forth on the P2; M4 is polish. At
p2-11's and obeam's cadence M0 is a day, M1 and M2 a week or two of
sessions, M3 another; the estimate rests, as obeam's did, on OctoGo not
blocking for long, the ogo session being a directory away.

## 7. Risks

- **The trampoline.** flexspin's rule against calls out of inline assembly
  could have held for generated code too. M0 ran it on 2026-10-28 and it
  works: an `orgh`/`end` block in a leaf method, which keeps its state in
  `_var01` to `_var05`, and generated code that touches none of them and
  uses no hardware stack. It works by convention, not by promise: the
  optimizer of another backend could move the method's state elsewhere, so
  `probe/m0` is re-run after any change of `ogo`, a minute, and B, also
  seen working, stays the fallback.
- **The backend's conventions are documented, not promised.** $1E0-$1EF
  and PR0-PR7's place in it, the FCACHE at $000-$0FF, LUT $200-$2FF, PTRA
  and PTRB's freedom are flexspin's choices, pinned with the backend `ogo`
  carries; a regeneration of the backend re-runs M0's probe, which is cheap,
  and the engine-cog image depends on none of it.
- **XBYTE is the bar, and it is high.** A bytecode costs 6 clocks of
  dispatch and runs its routine from LUT at cog speed; a native word in hub
  RAM pays 13 to 20 clocks for every taken branch and up to 10 more for a
  hub read after one. On loops, calls and memory the two are close until
  the native code inlines or runs from cog RAM; the design does both, and
  section 3.6's table is what M0 and M2 are held to. If the measured gain
  over P2XCForth's core is small, the honest result is still a result, and
  the embedding story (section 8) stands on its own.
- **Hub RAM is one pool.** The REPL and compiler in OctoGo (60 to 100 KB, by
  p2-11's code density), the code space, the dictionary and the OctoGo
  program a library version is embedded in share 512 KB; `ogo build
  --report` says what is left, and the code space's size is a build
  constant. Native code is 4 bytes an instruction where a wordcode is 2 and
  a bytecode 1, the argument TAQOZ's author made for wordcodes and the 20
  percent Pelc counts for STC; a word of ten primitives is about 120 bytes
  here and 20 there, and inlining multiplies it, as Christof's 4 times says.
- **A crash is a cog.** Generated code that is wrong takes its cog down; on
  the main cog that is the REPL. Mitigations in order: `SEE` and the host
  twin's checks of every byte the encoder writes, stack checks in a checked
  build, the REPL on a goroutine's cog with a watchdog, and B's isolation.
- **Scope creep from Forth's side.** ANS has 133 CORE words and a dozen word
  sets; TAQOZ has twelve years of P2 words, a file system, video and audio;
  P2XCForth has locals, values, an editor and a help system; Mecrisp and
  zeptoforth have register allocation and a preemptive multitasker. Version
  1 is CORE without files and heap, plus the `p2` mirror; the README says
  so in its first screen, as obeam's does.
- **Honesty of the claims.** The code runs from hub RAM, where TAQOZ's kernel
  and P2XCForth's core run from cog and LUT RAM; the comparison is made on
  the same board at the same clock, both compilers' loops shown, and the
  memory-bound case is reported beside the arithmetic one.
- **Time.** ogo is in its rc window, p2-11's phase 2 and obeam's later
  milestones are open, and this is a fourth project for the same person and
  the same board. Maciek's question to P2XCForth's author when he pondered
  a new Forth (2025-02-11) applies: "can you commit hundreds of hours to
  it's development (and that's just for starters, until the feasibility
  study is complete)?" The answer there was P2CCForth in a day and a usable
  system in five months, in C; the milestones here each leave something
  whole, M0 a measured answer on its own.

## 8. What OctoGo gets out of it

- A third program of a third shape: a compiler that writes and executes
  code at run time, which exercises `unsafe` stores, `uintptr` arithmetic,
  function addresses and Spin2 objects in ways p2-11 and obeam do not.
- What M0 found about inline PASM calling generated code -- it works from
  an `orgh`/`end` block, and the method's own state is in `_var` registers
  the called code must leave alone -- becomes a paragraph of specs.go's
  "Functions implemented in Spin2"; and PR0-PR7 as the documented way a Spin2 method and the cog's PASM
  share a register deserves a sentence there now.
- The intrinsics obeam already asked for and this needs too: `p2.CogID`, a
  `cogstop`, and perhaps a `p2.CogInit(image, ptra, ptrb)` so an engine
  needs no Spin2 object to start.
- A reason to write down what the backend leaves to the program -- the LUT
  below $300 is already the program's by `ReadLUT`; the sixteen registers
  are not mentioned anywhere in OctoGo's documentation.
- A host twin for a board-only package: the encoder's oracle, flexspin's
  assembler run on the host through `ogo`'s embedded backend, may become a
  script other projects use.

## 9. Decisions of 2026-10-28

The open points of the discussion, settled by the user after probe M0, all
as proposed:

1. **Where the engine runs:** design A, the REPL's own cog, with B's image
   for `RUN`. M0 found both working, with traps from A into OctoGo at 228
   clocks.
2. **The return stack:** the LUT with PB as the link register, 34 clocks a
   call and return plus 8 for a calling word, against 70 for CALLA/RETA on
   the C stack.
3. **The dialect:** ANS CORE as the target, with the P2 words beside it; a
   small compatibility file for TAQOZ's users may come later.
4. **The console:** `printf` and `p2.ReadByte` on the main cog; a buffered
   serial cog only if pasted source turns out to lose characters. It does,
   by OctoGo's own measurement (`_examples/protocol`: "NOTHING IS BUFFERED
   behind p2.ReadByte"), so M1 reads the line on a cog of its own into a
   ring, still with `p2.ReadByte`, and writes with `p2.WriteByte`, `printf`'s
   `%c` writing runes.
5. **The word that runs a word on a cog:** `RUN`, TAQOZ's name.
6. **The first demo:** the REPL alone, at M1 and M2. The embedding of M3 is
   shown by a small example program in this repository that exports a few
   of its functions (the board's LEDs and pins) as Forth words. A monitor
   inside p2-11 is not this repository's to write: another session works
   there, the embedding API exists only from M3, and p2-11's binary,
   389,980 bytes, leaves about 130 KB of the hub, room for a small Forth
   only. It may come later, as a joint step the user arranges.
7. **IPS's ideas:** the hashed dictionary now; the task switch hooked into
   a word's return later, and only if measured nearly free.
8. **Mecrisp's register-allocating kernel:** considered after M2's numbers,
   not before.

## 10. Housekeeping

- Rename the repository to `oforth` when the first code lands; the language
  stays OctoForth.
- Licence BSD-3-Clause as ogo, p2-11 and obeam; nothing taken from TAQOZ
  (MIT), P2XCForth, Mecrisp (GPL) or zeptoforth (MIT) but ideas, which are
  not licensed; the primitives are written here. `P2XCForthC.zip` and the
  saved forum pages in `forum/` sit untracked in the repository's directory
  for reference and should not be committed: move them beside the
  repository or ignore them.
- The board lock and the load coordination are the siblings' (`flock -w 900
  /tmp/p2-board.lock`); heavy runs only after checking the machine's load.
- The Parallax forum blocks fetching. Saved and read: P2XCForth (176239),
  csForth (175463), "Understanding the performance costs of hub execution"
  (174869), "Study about an Inline Compiler" (1548794) and "Pondering about
  another Forth for P2" (1565554). The remaining [forum snippet] marks are
  minor: pfth's speed on the P1, the 2018 fastspin-backend idea, and the
  thread on placing assembler routines in LUT (175395).

## Sources

- Probe M0: `probe/m0` in this repository, built with ogo
  v0.58.1-0.20261025171618 and run on the P2-EDGE at 160 MHz on
  2026-10-28, three loads.
- OctoGo: ../ogo (README.md, DIFFERENCES.md, specs.go "Functions implemented
  in Spin2", "Package unsafe", "Function types and function values";
  CLAUDE.md "The p2 package", "The board", "Language feature policy");
  `ogo build --report _examples/life`, 2026-10-28; the PR0 test build and
  its listing and binary, 2026-10-28 (a three-method Spin2 object, decoded
  with a MOV-immediate scan).
- p2-11: ../p2-11 (OCTOGO.md sections 1-4, the measurements of calls, jumps
  and hub accesses, and the PASM core; core/core.ogo and core/core.spin2;
  p2-11.p2asm, the backend's listing, for the cog layout and the calling
  convention).
- obeam: ../obeam (ASSESSMENT.md, the form of this file and the XBYTE
  figure; DESIGN.md section 8, the interpreter's costs).
- flexspin documentation, read 2026-10-28:
  https://github.com/totalspectrum/spin2cpp/blob/master/doc/general.md
  (memory model, FCACHE, "$1e0-$1ef are left free for application use", the
  LUT ranges, PTRA, PA, inline assembly rules);
  https://github.com/totalspectrum/spin2cpp/blob/master/doc/c.md (`__asm`
  forms, `_coginit`, `@@@`);
  https://github.com/totalspectrum/spin2cpp/blob/master/doc/spin.md
  (`org`/`end` in FCACHE, 128 longs, no `call`; `asm`/`endasm` hubexec).
- P2XCForth: `P2XCForthC.zip` in this directory (P2XCForthA.pdf of
  2025-07-11, sections 2, 5.3, 11 and 15; P2XFC.c; P2XFC.spin2;
  Blocks/block10PrimeA.fth with the sieve timings), and the whole thread,
  saved by the user as `forum/176239/` on 2026-10-28 (22 posts, 2025-07-11
  to 2026-10-28; posts 1, 6, 9, 15, 17, 19, 21 and 22 are cited):
  https://forums.parallax.com/discussion/176239/p2xcforth-a-fast-hybrid-xbyte-and-c
- TAQOZ: https://sourceforge.net/projects/tachyon-forth/ (MIT, files:
  TAQOZ/taqoz.spin2 V2.8 210401 and its .lst, TAQOZ/binaries/_BOOT_P2.TXT
  of 240219 with the V2.14.0 banner, TAQOZ/ROM/p2rom_v33h.lst);
  https://github.com/speccy88/TAQOZ (docs mirror, gem.md); Bob Edwards'
  TAQOZ RELOADED GLOSSARY, TAQOZ ROM GLOSSARY and "Taqoz v2.8 - Writing
  inline assembly language" at
  https://github.com/bob-g4bby/Bob-Edwards--Forth-Stuff/tree/main/Parallax%20Propeller%202;
  the TAQOZ ROM intro: https://docs.google.com/document/d/e/2PACX-1vQKKl_A9gQ8VooCfrLOqw6a_rp9ddyAqiFeo1RopL2AtnHTaWIfvojYq-yfNlqoPD81a2EU1EJsQpRG/pub;
  https://sourceforge.net/p/tachyon-forth/discussion/taqoz-p2/thread/e7a9c46cb8/
- P2 documentation: Propeller 2 datasheet 2021-07-09
  (https://embdev.net/attachment/589229/Propeller2-P2X8C4M64P-Datasheet-20210709.pdf);
  the Propeller 2 Documentation,
  https://docs.google.com/document/d/1gn6oaT5Ib7CytvlZHacmrSbVBJsD9t_-kmvjd7nUR6o/edit,
  read through https://p2docs.github.io/mirror/p2silicon.html; the P2
  instruction spreadsheet,
  https://docs.google.com/spreadsheets/d/1_vJk-Ad569UMwgXTKTdfJkHYHpc1rZwxB-DcIiAZNdk/edit
  (its clock columns); https://p2docs.github.io/ (branch.html, hubmem.html,
  lutmem.html, fifo.html, indir.html, xbyte.html, cog.html, errata.html).
- Mecrisp-Stellaris: https://mecrisp.sourceforge.net/ ;
  https://mecrisp-stellaris-folkdoc.sourceforge.io/ (ra-kernel, folding,
  machine-code, glossary, benchmarks); the source mirror
  https://github.com/jjonethal/mecrisp-stellaris (common/compiler.s,
  controlstructures.s, doloop.s, datastackandmacros.s, codegenerator-m0.s,
  interpreter.s, ra/ra-kompilator.s, ra/ra-infrastructure.s).
- zeptoforth: https://github.com/tabemann/zeptoforth (README; src/m0/macro.s,
  asm.s, cond.s; src/rp2040/common.s; src/common/forth/basic.fs; the wiki
  "Multitasking and Multiprocessing").
- SwiftForth and VFX: https://www.forth.com/swiftforth/ ;
  https://www.mpeforth.com/software/pc-systems/vfx-forth-common-features/ ;
  S. Pelc, "The MPE VFX Forth code generator", EuroForth 1998,
  https://vfxforth.com/arena/VFXgen.pdf ; S. Pelc, "Inside the MPE VFX code
  generator", EuroForth 2000, https://vfxforth.com/arena/insidevfx.pdf ;
  https://groups.google.com/g/comp.lang.forth/c/OAv3r0zsHoA (Pelc's rule of
  thumb, 2021).
- Moving Forth, CamelForth, fig-FORTH, M4_FORTH:
  https://www.bradrodriguez.com/papers/moving1.htm and moving2.htm ;
  https://github.com/jamesbowman/camelforth-z80 (camel80.asm.m4, the
  register table); https://gist.github.com/tschak909/c45014672024b15b5244576783d011c1
  (fig-FORTH 8080 listing); https://codeberg.org/DW0RKiN/M4_FORTH ;
  https://groups.google.com/g/comp.lang.forth/c/Ha1hi3bEVvg
- Classic references: R. G. Loeliger, Threaded Interpretive Languages, BYTE
  Books, 1981; https://www.complang.tuwien.ac.at/forth/threaded-code.html ;
  http://www.complang.tuwien.ac.at/projects/rafts.html ;
  https://raw.githubusercontent.com/nornagon/jonesforth/master/jonesforth.S
- The saved forum pages, `forum/`, 2026-10-28: `forum/175463/` (csForth,
  Christof Eb., 2023-08-09 and 2023-08-13, with the cached-call listing and
  the fibonacci ratio); `forum/174869/page1/` and `page2/` ("Understanding
  the performance costs of hub execution", brianh, 2022-09-23 to
  2022-09-28; posts 2, 3, 13, 16, 17, 18, 19, 20, 24, 27, 28, 31, 32 and 33
  are cited, by pik33, Wuerfel_21, evanh, TonyB_ and Christof Eb.);
  `forum/1548794/` ("P2 Taqoz 2.8: Study about an Inline Compiler - Speed,
  Stack and Inline Assembly", Christof Eb., 2023-01-19, edited 2023-01-23,
  with the fibonacci table; posts 2 and 5, 2023-01-23 and 2023-03-13, the
  macro assembler and its `ret` rule); `forum/1565554/` ("Pondering about
  another Forth for P2", Christof Eb., 2025-02-11 to 2025-02-15; posts 1,
  2, 3, 7, 8 and 10 are cited, by Christof Eb., Wuerfel_21 and Maciek).
- pfth, Tachyon, PropForth, PropellerForth, JDForth: forum threads 143472,
  149632, 141061, 165490, 162381, 97440, 100820 at
  https://forums.parallax.com/discussion/ [forum snippets];
  https://www.forth.org/propforth.html ; https://github.com/prof-braino/propforth
  (01-PropForth.spin); https://groups.google.com/g/comp.lang.forth/c/9HSmf25qB_Q
  (Tachyon's design, 2013); http://www.jacobsdesign.com.au/software/jdforth/jdforth.php
- Christof Eb.'s TAQOZ work:
  https://forums.parallax.com/discussion/175463/p2-taqoz-v2-8-csforth-cached-call-sequences-for-speed-of-innermost-loops
  (saved, see above); https://forums.parallax.com/discussion/comment/1548794
  ("Study about an Inline Compiler", saved); https://forums.parallax.com/discussion/comment/1565554
  ("Pondering about another Forth for P2", P2CCForth's origin, saved);
  https://forums.parallax.com/discussion/175395/p2-taqoz-v2-8-placing-assembler-routines-into-lut-ram
  [forum snippet]; the IPS manual the last P2XCForth post points to,
  http://www.jrmiller.online/IPS/IPS.pdf, and BYTE January 1979, p. 146
  (not read here).
- riscvp2: https://github.com/totalspectrum/riscvp2 and
  https://forums.parallax.com/discussion/comment/1411177
- TAQOZ on this board: ../ogo/CLAUDE.md, "The board"; ../obeam/ASSESSMENT.md
  section 4, "Prior art on the P2".
