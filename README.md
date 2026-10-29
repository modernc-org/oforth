![OctoForth](logo.png)

*May the Forth be with you.*

*Mascot based on the [Go gopher](https://go.dev/blog/gopher) by Ren&eacute;e
French, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
by way of [OctoGo](https://gitlab.com/cznic/ogo)'s.*

# OctoForth

OctoForth is to be a Forth for the
[Parallax Propeller 2](https://www.parallax.com/propeller-2/), written in
[OctoGo](https://pkg.go.dev/modernc.org/ogo), that compiles every colon
definition to P2 machine code the moment it is defined. Its short name, the
repository's, is `oforth`, as OctoGo's is `ogo` and OctoBeam's is `obeam`.
It is the third program of size in OctoGo, after
[p2-11](https://gitlab.com/cznic/p2-11), a PDP-11/40 that runs Unix V6, and
[OctoBeam](https://gitlab.com/cznic/obeam), a BEAM for Erlang and Elixir.

**Status, 2026-10-29: milestone M2 done, M4 begun.** A REPL on the serial
line compiles every colon definition to P2 machine code: 81 primitives
copied in as P2 instructions, literals folded into the instructions that
use them, small words inlined, a call in tail position made a jump, a loop
without calls run from cog RAM, a DO loop there with no branch in its body
repeated by REP, calls with the return address in a register
and the return stack in LUT RAM, and 130 words written in OctoGo that
compiled code calls back into. `INCLUDE` and the FILE words read and
write the host's files, over the serial line. It passes the CORE, CORE
EXT and FILE tests of the Forth-2012 test suite on the board, with 0
errors (`scripts/f2012.sh`, which INCLUDEs them), and `SEE` shows a
word's machine code as the words it was compiled from. There is no
FLOATING, no
multitasking within a cog, and nothing protects a word that jumps into
garbage: it takes the REPL down with it. The research and the decisions
behind it are in [ASSESSMENT.md](ASSESSMENT.md).

## Try it

With [OctoGo](https://gitlab.com/cznic/ogo) installed and a P2 board on the
serial port:

```sh
ogo run
```

```
OctoForth, a native-code Forth for the P2
: sq DUP * ;  ok
7 sq . 49  ok
SEE sq sq is a colon definition
24D24  ENTER                    F187CC01 FC33EFE6
24D2C  DUP                      FC37C1E1
24D30  *                        FAA7C3DF FD03C3E0 FD63C018
24D3C  EXIT                     FAA3EFE6 F107CC01 FD63EE2C
 ok
```

Pasted source works: a cog of its own reads the serial line.

To INCLUDE files, load it with the loader's file server, which serves a
directory of the host by 9P over the same serial line:

```sh
ogo build
ogo loadp2 -t -9 . -b 230400 oforth.binary
```

```
INCLUDE bench/oforth.fth
```

The FILE word set reads and writes files so too: `INCLUDED`,
`INCLUDE-FILE`, `REQUIRE`, `REQUIRED`, `OPEN-FILE`, `CREATE-FILE`,
`READ-LINE`, `READ-FILE`, `WRITE-LINE`, `WRITE-FILE`, `FILE-POSITION`,
`REPOSITION-FILE`, `FILE-SIZE`, `RESIZE-FILE`, `FLUSH-FILE`,
`RENAME-FILE`, `DELETE-FILE`, `FILE-STATUS`, `CLOSE-FILE`, `R/O`, `W/O`,
`R/W` and `BIN`. A name is a path in the directory served; `RENAME-FILE`
renames a file within its directory only, as 9P does. An error in a file
is reported with its name and the line's number, and a `(` comment in a
file may go on over lines. Under a
loader with no `-9`, such as `ogo run`'s, INCLUDE gives up after three
seconds, saying so, the bytes of its request showing on the terminal.

## Three Forths on one board

`scripts/bench.sh` runs the same five programs on OctoForth, on TAQOZ
Reloaded and on P2XCForth, one after the other on a P2-EDGE, each
timed by the system's own counter, in clocks, which do not depend on the
clock frequency. Fewer is faster.

| | OctoForth | P2XCForth | TAQOZ |
| --- | --- | --- | --- |
| an empty `DO LOOP`, 100,000 times | 200,124 | 7,200,129 | 3,200,288 |
| an empty colon word called 100,000 times | 200,132 | 13,600,129 | 9,600,288 |
| the Byte sieve, 8192 flags, one pass | 1,400,049 | 6,390,449 | 13,546,112 |
| `25 fib`, recursive | 18,080,718 | 53,969,641 | 97,114,008 |
| `10 fact` 10,000 times, recursive | 14,560,026 | 48,960,129 | 42,800,280 |

The sources are in [bench/](bench), the same algorithm in each system's
dialect; the sieve is BYTE's of 1981 as P2XCForth's archive has it, with
8192 flags, in the variant its author measured fastest, whose macros
`scripts/p2xc.sh` takes from his archive with his other block words, none
of them being in this repository. Taken as they are:

- TAQOZ is TAQOZ Reloaded V2.14.0, its author's image of 2024-02-19, from
  the board's flash at 200 MHz. Its empty loop takes the 32 clocks an
  iteration its documentation gives. Its sieve array is at a fixed hub
  address in its free room, its data space having no room for 8 KB, and is
  named `fl`, TAQOZ having a FLAGS of its own.
- P2XCForth is P2XCForthD, its author's newest, of 2026-04-07, attached to
  his forum post (the project has no repository), built for the P2-EDGE by
  `scripts/p2xc.sh` with four changes, which the script prints: the EDGE's
  20 MHz crystal, no SD card mounted, so no block loaded from it at start,
  and its Spin2 object's `#define`s applied by hand. Its empty loop takes
  the 72 clocks an iteration its documentation gives. Its `recurse` works
  as the one its author posted on 2026-04-08. Its timings move by up to a
  tenth with where its words land in memory (its calls took 15,200,129 in
  one build), and its archive of 2025-07-11 ran within that.
- OctoForth inlines the empty word since M4, so the second row is its loop
  alone, which runs from cog RAM by REP, 2 clocks an iteration, the
  increment of its index; `fib` and `fact`,
  recursive, measure its calls (34 clocks a call and return, 8 more for the
  frame). Its timings, too, move by a few percent with where code lands, a
  taken branch in hub RAM costing 13 to 20 clocks with its target's place:
  `fact` took 15,360,026 in one build of M4.

## Third parties' benchmarks

`scripts/third.sh` runs two collections others wrote and other Forths have
been compared with, fetched at pinned hashes and never committed: Anton
Ertl's four (the sieve, bubble sort, matrix multiplication and fib, from
his [Performance of Forth
systems](https://www.complang.tuwien.ac.at/forth/performance.html), which
Gforth's manual compares with too), and the Stanford integer benchmarks
John Hennessy gathered, in Martin Fraeman's Forth of 1989. Every system
runs at 200 MHz, timed by the host between two marks the system writes
around the work, in milliseconds; fewer is faster.

| | OctoForth | P2XCForth | TAQOZ |
| --- | --- | --- | --- |
| Ertl: sieve, 1000 times | 5,503 | does not run | 34,380 |
| Ertl: bubble sort, 6000 | 10,207 | 82,960 | 78,262 |
| Ertl: matrix multiply, 64 by 64 | 208 | 1,288 | 1,168 |
| Ertl: `34 fib` | 7,743 | 23,477 | 42,075 |
| Stanford Perm, 10 times | 784 | does not load | does not fit |
| Stanford Towers | 1,376 | | |
| Stanford Queens | 688 | | |
| Stanford Intmm | 1,680 | | |
| Stanford Puzzle | 6,607 | | |
| Stanford Quick | 864 | | |
| Stanford Bubble | 992 | | |
| Stanford Trees | 3,040 | | |

The programs run as their authors wrote them but for what the script
prints: the matrices are 64 by 64, not 200 by 200, which needs 480 KB;
Fraeman's word `Swap` is `pswap`, a Forth that ignores case taking it for
the stack's `swap` elsewhere in his file; for P2XCForth the files are in
lower case with spaces for TABs, and a name over its 19 characters cut; and
for TAQOZ they are in upper case, TAQOZ finding a name in another case only
when it was defined in upper case.
Each system loads a prelude first, [bench/third/](bench/third), with the
words the programs need and it lacks: for OctoForth seven words of
Fraeman's SC32 kernel; for P2XCForth, after its author's own block words
taken from his archive at run time, plain colon definitions of the ANS
words it lacks, `2@` and `2!` among
them, which costs it in bubble sort; for TAQOZ its ANS words under TAQOZ's
names, and a CREATE whose data is TAQOZ's code space, its own CREATE giving
none, with `2@` and `2!` again colon definitions. Ertl's sieve does not run
on P2XCForth, whose `+LOOP` ends only when the index equals the limit, and
Fraeman's file does not load there, lacking DOES>; on TAQOZ his arrays,
about 69 KB, do not fit the 62 KB of room it has. Every program that ran
gave its expected answer, and each Stanford one passed its own check.
The host's clock ticks every 16 ms, so a Stanford time moves by a tick or
two from run to run, and by up to 5% with where the code lands.

## The loop cache

A taken branch costs 13 to 20 clocks in hub RAM, where compiled code
runs, and 4 in cog RAM. So a loop with no call and no trap in it, at most
240 longs long, runs from cog RAM $000 to $0EF, which the OctoGo backend
uses for its own loops between runs of Forth code. Five longs before
the loop compare its tag, its address and length, with the tag of the
loop cog RAM holds. If they differ, the engine copies the loop in, one
long a clock. Then it jumps there, and the loop's last long jumps back to
hub RAM. A loop inside a cached loop goes with it. When a loop calls a
word, the loops inside it are cached instead, and the tag spares them the
copy when they are entered again. A loop not cached costs nothing: its
reserved longs are taken out when it ends.

Timed by the board's clock, one run of each Stanford program, as the mean
of eight builds that move the code by one to eight longs:

| | before the cache | with it | |
| --- | --- | --- | --- |
| Perm | 15,556,057 | 15,656,625 | +0.6% |
| Towers | 27,163,482 | 27,392,510 | +0.8% |
| Queens | 14,237,770 | 14,197,967 | -0.3% |
| Intmm | 33,771,079 | 33,800,549 | +0.1% |
| Puzzle | 132,637,964 | 132,084,310 | -0.4% |
| Quick | 17,798,260 | 17,367,053 | -2.4% |
| Bubble | 24,069,826 | 19,962,968 | -17.1% |
| Trees | 61,608,366 | 61,827,443 | +0.4% |

Moving the code alone moves Perm, Towers and Queens by 4 to 5%, so their
changes are placement, not the cache. Most of Fraeman's loops call his
small words that use the return stack, which are not inlined, so the
cache leaves them in hub RAM.

A DO loop in cog RAM whose body has no branch, call or trap repeats it by
REP, which costs nothing an iteration there: the block is the body and
LOOP's increment of the index, and three longs before it set the count,
the limit less the index. LOOP's compare and branch stay after the block
and run on only when the count is 0, a `DO` from a limit to itself being
2^32 iterations, which REP would take for none. The empty loop takes 2
clocks an iteration so, against 8, and Ertl's matrix multiplication,
whose inner loop is such a loop, 208 ms against 224. Fraeman's inner
loops branch or call, or are `BEGIN` loops over the return stack, so only
his set-up loops are repeated, and his times move by no more than where
the longer loops move the code to.

## Why another Forth for the P2

The P2 has good Forths: Peter Jakacki's TAQOZ, in its ROM, and Christof
Eberspaecher's P2XCForth, whose XBYTE core is up to twice as fast. Every
Forth for the Propeller 1 or 2 that could be found interprets something --
wordcodes, tokens, threads or bytecodes. OctoForth is to write machine code
instead, as Mecrisp-Stellaris does on ARM and as the author's own Forth for
the Intel 8080 did in the 1980s, on paper, on a Tesla JPR-1:

- the primitives are copied into a word as P2 instructions, literals become
  immediates, and a word runs at the address it was written to; small colon
  words are to be inlined too;
- the data and return stacks live in a cog's LUT RAM, two to three clocks an
  access, and the top of the stack in a register;
- the outer interpreter, the dictionary and the compiler are OctoGo, so a
  word calls into the OctoGo program it runs in, as `.` and `TYPE` already
  do; a word is to be sent to run on a cog of its own, as `go` sends a
  function.

ASSESSMENT.md has the prior art, the clocks per operation of TAQOZ, P2XCForth
and the design side by side, the facts checked on the hardware and in the
compiler, the milestones and the risks. The bar is P2XCForth's, and the
comparison is to be made on one board at one clock, the loops shown.

## License

BSD-3-Clause, see [LICENSE](LICENSE). The logo is drawn by
[scripts/logo.py](scripts/logo.py) from OctoGo's.
