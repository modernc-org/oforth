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

**Status, 2026-10-28: milestone M2.** A REPL on the serial line compiles
every colon definition to P2 machine code: 79 primitives copied in as P2
instructions, literals folded into the instructions that use them, calls
with the return address in a register and the return stack in LUT RAM, and
110 words written in OctoGo that compiled code calls back into. It passes
the CORE and CORE EXT tests of the Forth-2012 test suite on the board, with
0 errors (`scripts/f2012.sh`), and `SEE` shows a word's machine code as the
words it was compiled from. There is no file loading yet, no FLOATING, no
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

## Three Forths on one board

`scripts/bench.sh` runs the same five programs on OctoForth, on TAQOZ
Reloaded and on P2XCForth, one after the other on a P2-EDGE, each
timed by the system's own counter, in clocks, which do not depend on the
clock frequency. Fewer is faster.

| | OctoForth | P2XCForth | TAQOZ |
| --- | --- | --- | --- |
| an empty `DO LOOP`, 100,000 times | 2,400,020 | 7,200,137 | 3,200,288 |
| an empty colon word called 100,000 times | 6,400,021 | 15,200,129 | 9,600,288 |
| the Byte sieve, 8192 flags, one pass | 2,077,473 | 6,611,169 | 13,546,112 |
| `25 fib`, recursive | 18,080,718 | 54,477,337 | 97,114,008 |
| `10 fact` 10,000 times, recursive | 14,560,026 | 49,040,145 | 42,800,280 |

The sources are in [bench/](bench), the same algorithm in each system's
dialect; the sieve is P2XCForth's own, from its archive, in the variant
its author measured fastest. Taken as they are:

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
  the 72 clocks an iteration its documentation gives. Its `recurse` is the
  one its author posted on 2026-04-08. Its archive of 2025-07-11 ran within
  a few percent of these numbers.
- OctoForth's `FILL` is written in OctoGo, a byte at a time: 378,290 of
  its sieve's clocks.

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
| Ertl: sieve, 1000 times | 9,871 | does not run | 34,380 |
| Ertl: bubble sort, 6000 | 12,558 | 83,678 | 78,262 |
| Ertl: matrix multiply, 64 by 64 | 240 | 1,286 | 1,168 |
| Ertl: `34 fib` | 7,743 | 23,382 | 42,075 |
| Stanford Perm, 10 times | 896 | does not load | does not fit |
| Stanford Towers | 1,904 | | |
| Stanford Queens | 1,312 | | |
| Stanford Intmm | 2,976 | | |
| Stanford Puzzle | 6,671 | | |
| Stanford Quick | 1,808 | | |
| Stanford Bubble | 1,920 | | |
| Stanford Trees | 3,167 | | |

The programs run as their authors wrote them but for what the script
prints: the matrices are 64 by 64, not 200 by 200, which needs 480 KB;
Fraeman's word `Swap` is `pswap`, a Forth that ignores case taking it for
the stack's `swap` elsewhere in his file; for P2XCForth the files are in
lower case with spaces for TABs, and a name over its 19 characters cut; and
for TAQOZ they are in upper case, TAQOZ finding a name in another case only
when it was defined in upper case.
Each system loads a prelude first, [bench/third/](bench/third), with the
words the programs need and it lacks: for OctoForth seven words of
Fraeman's SC32 kernel; for P2XCForth its author's own block definitions and
plain colon definitions of the ANS words it lacks, `2@` and `2!` among
them, which costs it in bubble sort; for TAQOZ its ANS words under TAQOZ's
names, and a CREATE whose data is TAQOZ's code space, its own CREATE giving
none, with `2@` and `2!` again colon definitions. Ertl's sieve does not run
on P2XCForth, whose `+LOOP` ends only when the index equals the limit, and
Fraeman's file does not load there, lacking DOES>; on TAQOZ his arrays,
about 69 KB, do not fit the 62 KB of room it has. Every program that ran
gave its expected answer, and each Stanford one passed its own check.

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
