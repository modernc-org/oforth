![OctoForth](logo.png)

*May the Forth be with you.*

*Mascot based on the [Go gopher](https://go.dev/blog/gopher) by Ren&eacute;e
French, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
by way of [OctoGo](https://gitlab.com/cznic/ogo)'s.*

# OctoForth

OctoForth is a Forth for the
[Parallax Propeller 2](https://www.parallax.com/propeller-2/), written in
[OctoGo](https://pkg.go.dev/modernc.org/ogo), that compiles every colon
definition to P2 machine code the moment it is defined: the primitives
copied in as P2 instructions, literals folded into them, small words
inlined, a call in tail position made a jump, and loops without calls run
from cog RAM. On the benchmarks below it runs about three to ten times as
fast as the P2's other Forths, TAQOZ and P2XCForth, on the same board, an
empty loop 16 to 36 times as fast, and a call of an empty word 1.5 to 2.1
times. Its code is the largest of the three and the system itself takes
206 KB of the hub RAM; it leaves a program about as much room as P2XCForth
does, and less than TAQOZ (below, "What the programs take"). Its short
name, the repository's, is `oforth`, as OctoGo's is `ogo` and OctoBeam's
is `obeam`. It is the
third program of size in OctoGo, after
[p2-11](https://gitlab.com/cznic/p2-11), a PDP-11/40 that runs Unix V6, and
[OctoBeam](https://gitlab.com/cznic/obeam), a BEAM for Erlang and Elixir.

It has the Forth-2012 standard's CORE, CORE EXT, DOUBLE, EXCEPTION, FILE,
STRING and TOOLS word sets, whose tests in the Forth-2012 test suite pass
on the board with 0 errors; the P2's pins, smart pins, clocks, locks and
LUT as words; `RUN`, which runs a word on a cog of its own; files on the
host, read and written over the serial line, on the SD card and in the
board's flash; and a startup file, so that the board boots a Forth program
with no computer attached. An OctoGo program embeds it by copying a
directory.

The repository you are currently viewing might be a mirror. Please review the
guidelines below based on where you are viewing this:

| Platform | Role | Contributing Guidelines |
| :--- | :--- | :--- |
| **GitLab** | **Primary Source** | This is the canonical repository ([`cznic/oforth`](https://gitlab.com/cznic/oforth)). Development happens here. |
| **GitHub** | **Mirror** | This is a mirror ([`modernc-org/oforth`](https://github.com/modernc-org/oforth)), where the release binaries are published. We **do accept** Issues and Pull Requests here for your convenience! <br> *Note: PRs submitted here will be manually merged into the GitLab source, so please allow extra time for processing.* |

## Installation

OctoForth runs on a Propeller 2 board with a 20 MHz crystal and a serial
port to a computer. It is tested on a P2-EDGE (P2-EC), whose SD card slot
and flash, on pins P58 to P61, are the ones its files use. Its console is
at 230400 baud. Either:

- **A release's binaries**, no OctoGo needed: from the
  [releases page](https://github.com/modernc-org/oforth/releases),
  `oforth.binary`, the REPL, which a P2 loader loads into the board's RAM,
  and `boot.binary`, the same REPL for the board's flash or an SD card,
  which runs a startup file. FlexProp's `loadp2` loads them:

  ```sh
  loadp2 -t -b 230400 oforth.binary
  ```

- **From source**, with OctoGo v1.0.0-rc.3 or newer, which carries the
  compiler and the loader (`go install modernc.org/ogo@v1.0.0-rc.3`, with
  Go 1.26 or newer, `@latest` being an older release until OctoGo's v1.0.0;
  see [its README](https://gitlab.com/cznic/ogo)):

  ```sh
  git clone https://gitlab.com/cznic/oforth
  cd oforth
  ogo run --no-inline
  ```

  `ogo run` builds `oforth.binary`, loads it into the board's RAM and opens
  a terminal. `--no-inline` is how OctoForth is built: OctoGo inlines small
  functions unless told not to, which OctoForth has no hub RAM for, and
  then builds it with every switch a chain of compares, where with
  `--no-inline` they stay tables of jumps, and in a third of the time.

The loader finds the board by itself; with several, name the port: `-p
/dev/ttyUSB0` (`-p COM3` on Windows). On Linux the serial port belongs to
a group, usually `dialout` (`ls -l /dev/ttyUSB0` shows it): join it once,
`sudo usermod -aG dialout $USER`, and log in again. On Windows, run the
loader from `cmd.exe` or PowerShell, not from git-bash, MSYS2 or Cygwin.
Ctrl-] leaves the terminal, and `BYE` ends `ogo run`. A program loaded
into RAM is gone at the next reset; the flash keeps one (below).

## Getting started

### The REPL

Loaded, it says who it is and takes a line at a time:

```
OctoForth, a native-code Forth for the P2
: sq DUP * ;  ok
7 sq . 49  ok
SEE sq sq is a colon definition
3250C  ENTER                    F187CC01 FC33EFE6
32514  DUP                      FC37C1E1
32518  *                        FAA7C3DF FD03C3E0 FD63C018
32524  EXIT                     FAA3EFE6 F107CC01 FD63EE2C
 ok
```

`SEE` shows a word's machine code as the words it was compiled from.
Names are found regardless of case, and a cell is 32 bits. Pasted source
works: a cog of its own reads the serial line.

### The host's files

To INCLUDE files, run it with the loader's file server, which serves a
directory of the host by 9P over the same serial line:

```sh
ogo run --no-inline -9 .
```

or, with a release's binary, `loadp2 -t -9 . -b 230400 oforth.binary`.
Then

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
loader with no `-9`, such as a plain `ogo run`, INCLUDE gives up after three
seconds, saying so, the bytes of its request showing on the terminal.

### The SD card

A name after `sd:` is a file on the SD card in the board's slot, a FAT32
volume, the card's first partition or the whole card, and every FILE
word works there as on the host, long names too, found regardless of
case:

```
INCLUDE sd:app.fth
```

With the loader's `-9` the host's files and the card's are open at once,
so a file goes onto the card without the card coming out:

```
CREATE CB 512 ALLOT  0 VALUE IN  0 VALUE OUT
: COPY ( a1 u1 a2 u2 -- ) W/O CREATE-FILE THROW TO OUT  R/O OPEN-FILE THROW TO IN
  BEGIN CB 512 IN READ-FILE THROW ?DUP WHILE CB SWAP OUT WRITE-FILE THROW REPEAT
  IN CLOSE-FILE THROW  OUT CLOSE-FILE THROW ;
S" bench/oforth.fth" S" sd:bench.fth" COPY
```

The card is driven pin by pin, as p2-11 drives it, a block read in
1.43 ms at 160 MHz. A file written past its end has zeros up to where
it was written; one open is neither deleted, renamed nor opened for
writing again; `RENAME-FILE` renames within a directory, as on the
host, and no directory is made, the FILE word set having no word for
it. The board has no clock, so what OctoForth writes is dated
1980-01-01.

### Booting with no host, from the flash or the card

To run OctoForth with no host, write it into the board's flash, the
P2-EDGE's FLASH switch on:

```sh
scripts/flash.sh
```

or, with a release's binary, `loadp2 -FLASH -t -b 230400 boot.binary`,
leaving the terminal by Ctrl-] once the banner has come: closing the port
earlier resets the board in the middle of the write. It takes `loadp2`
0.078 or newer, FlexProp 7.6.11's, which `ogo loadp2` is too: what 0.077
wrote did not boot. From then on the board boots OctoForth at every reset or
power-up that no loader answers, its banner coming half a second after a
reset: the REPL is any terminal's at 230400 baud, and the card's files are
there, the host's not. A loader still loads any other program as before,
and the next reset with no loader boots OctoForth again.

A name after `flash:` is a file in the flash, in the 15 MB past the
program, which writing the program leaves as they are. The flash is
written by clearing bits, which only an erase of a block of 64 KB sets
again, so a file there is written as it is made, from its start to its
close, and only read after: `OPEN-FILE` opens it for reading,
`CREATE-FILE` makes it anew, `DELETE-FILE` deletes it, and `RENAME-FILE`
and `RESIZE-FILE` refuse it. A file takes 64 KB at least, so the flash
holds 240 of them; one the board was reset while writing is not there.
The board boots an SD card instead with the FLASH switch off: the same
`boot.binary` as `_BOOT_P2.BIX` in the root of the card's FAT32 volume,
which the P2's ROM loads by itself. The ROM wants the file in one piece,
as it is on a card with no other `_BOOT_P2.BIX` and its free space in one
run, as a new card's is; COPY above writes it so from the host's directory
too, in about 40 seconds:

```
S" boot.binary" S" sd:_BOOT_P2.BIX" COPY
```

The banner then comes 7.7 seconds after a reset, the ROM reading the card
at about 65 KB/s. With the switch on, the flash is booted, whatever the
card holds. While the switch is off and the card holds the file, no loader
finds the board: switch it on, or take the card out, to load a program
again. And with the switch off the flash is not there at all, to the ROM
nor to OctoForth, so the card's OctoForth has the card's files only.

The OctoForth the board boots, from the flash or the card, first
interprets `sd:boot.fth`, if the card in the slot has one, and
`flash:boot.fth` if not, unless a key comes within half a second, which
it says:

```
OctoForth, a native-code Forth for the P2
flash:boot.fth: a key within half a second skips it
```

So a program starts by itself at power-up, a card's startup file is
taken before the flash's, and a startup file that goes wrong is skipped
by a key pressed at the reset. COPY above writes one from the host's
directory or the card:

```
S" app.fth" S" flash:boot.fth" COPY
```

The REPL loaded into RAM runs no startup file: the program the board
boots is `boot/`, which calls `Boot`, an embedding function, before the
REPL.

## What it has and has not

- **The word sets** of Forth-2012: CORE, CORE EXT but the obsolescent
  `[COMPILE]`, DOUBLE, EXCEPTION, FILE, STRING, and TOOLS and TOOLS EXT
  but the wordlists' and the assembler's words: `?`, `DUMP`, `[IF]`,
  `[ELSE]`, `[THEN]`, `[DEFINED]`, `[UNDEFINED]`, `AHEAD`, `CS-PICK`,
  `CS-ROLL`, `N>R`, `NR>`, `SYNONYM` and `BYE`; and of FACILITY and its
  extensions, `KEY?` and `MS`. The test suite's tests of them pass on
  the board with 0 errors: `scripts/f2012.sh` INCLUDEs them, and
  `scripts/f2012.sh -sd` runs the FILE tests on the card.
- **Double numbers** are written with a point, `1.`.
- **Errors**: the system's are THROWn with the standard's codes, so that
  `CATCH` catches an undefined word or a stack underflow as it catches a
  `THROW`. An error not caught empties the stacks and takes back a
  definition in progress.
- **The P2**: its pins, smart pins, clocks, locks and LUT as words, and
  `RUN`, which runs a word on a cog of its own (below).
- **Room**: 128 KB of code space and 160 KB of data space. The
  dictionary is 127 primitives, copied into words as P2 instructions, and
  165 words written in OctoGo, which compiled code calls back into.
- **Not there**: FLOATING, LOCALS, MEMORY (`ALLOCATE`), SEARCH-ORDER,
  BLOCK, the rest of FACILITY (`PAGE`, `AT-XY`, `TIME&DATE`, the
  structures), XCHAR; multitasking within a cog, `RUN` giving a word a cog
  instead. Nothing protects a word that jumps into garbage: it takes the
  REPL down with it.

## The P2 words

The P2's pins, smart pins, clocks, locks and LUT are words named after
the functions of OctoGo's `p2` package, with a hyphen before every
capital but the first: `PIN-HIGH`, `PIN-LOW`, `PIN-TOGGLE`, `PIN-FLOAT`,
`PIN-IN`, `PIN-WRITE`, `PIN-START`, `WRITE-PIN-MODE`, `WRITE-PIN-X`,
`WRITE-PIN-Y`, `READ-PIN`, `ACK-PIN`, `WAIT-MS`, `WAIT-US`,
`WAIT-CYCLES`, `WAIT-UNTIL`, `GET-CT`, `GET-MS`, `GET-US`, `GET-SEC`,
`CLOCK-FREQ`, `RND`, `REV`, `REBOOT`, `READ-LUT`, `WRITE-LUT`,
`NEW-LOCK`, `TRY-LOCK`, `UNLOCK` and `FREE-LOCK`, with `COG-ID` and
`COG-STOP` beside them. A word takes its function's arguments in the
function's order, the first the deepest, so `56 1 PIN-WRITE` is
`p2.PinWrite(56, 1)`. A bool is a flag, and `NEW-LOCK` gives -1 when no
lock is left, which `p2.NewLock` cannot say. A pin is a pin field, as the
instructions take it: `56 1 6 LSHIFT OR` is P56 and P57. The console's
functions are not among them: `KEY`, `EMIT` and `TYPE` are the Forth's.

They are P2 instructions, like the other primitives, so they run on any
cog, and a literal pin is folded into the instruction:

```
: blink 10 0 DO 56 PIN-TOGGLE 50 WAIT-MS LOOP ;
```

blinks the EDGE's LED from cog RAM, `56 PIN-TOGGLE` being the one long
`DRVNOT #56`. In a DO loop with nothing else in its body, REP repeats it:
1,000 toggles take 4,133 clocks, 4 a toggle, a 20 MHz square wave at
160 MHz, and 9,140 with the pin taken from the stack, `DUP PIN-TOGGLE`
(OctoGo v1.0.0-rc.3, 2026-10-31). Code that fast meets the pin's own delay: the
input follows the output a few clocks late, so `56 PIN-LOW 56 PIN-IN`,
compiled, reads the pin as it was before.

`RUN ( x1 .. xn n xt -- cog )` runs a word on a free cog, the n cells its
stack, and answers the cog, or -1 when none is free; `COG-STOP` stops it.
The cog has registers, stacks and a loop cache of its own, and stops when
the word returns. It cannot call into OctoGo, which runs on the REPL's
cog, so `RUN` refuses a word that does, such as one that prints, and the
two cogs talk through hub RAM. So

```
: blinker ( pin ms -- ) BEGIN OVER PIN-TOGGLE DUP WAIT-MS AGAIN ;
56 100 2 ' blinker RUN .  57 150 2 ' blinker RUN .
```

blinks the two LEDs from two cogs while the REPL goes on. With the REPL
on cog 0 and the console's reader on cog 1, six cogs are free; a `RUN`
takes 5,282 clocks until the cog has its cells.

## In a program of its own

[forth/](forth) is the whole Forth, importing nothing but `p2` and
`unsafe`, so an OctoGo program has it by copying the directory into its
module, OctoGo taking no external dependencies. The program gives it code
and data spaces and a console, and makes functions of its own words, which
take their arguments by `forth.Pop` and give their results by
`forth.Push`:

```go
var code, data [8192]uint32

func blink() { // BLINK ( n ms -- )
	ms := int(forth.Pop())
	n := int(forth.Pop())
	for i := 0; i < n; i++ {
		p2.PinToggle(56)
		p2.WaitMs(ms)
	}
}

func main() {
	forth.Serial()
	forth.Init(code[:], data[:])
	forth.Define("BLINK", 2, blink)
	forth.Evaluate(": TWICE ( ms -- ) 2 SWAP BLINK ;")
	forth.Quit() // until BYE
	forth.Exit(0)
}
```

`Define` is given how many cells the function takes, which the Forth
checks before it calls it, as it does for its own words. Such a word runs
on the REPL's cog, so `RUN` refuses a word that uses one. `forth.Serial`
is the console the REPL has, a cog reading the serial line into a ring;
`Quit` returns after `BYE`, and `forth.Exit` writes the loader's exit
sequence, which ends `ogo run` with the status given. `forth.Boot`
interprets a file, as `boot/` does the startup file, and says whether it
was there.
[example/](example) is such a program, with words for the EDGE's LEDs and
pins: `ogo run --no-inline ./example`.

## Three Forths on one board

`scripts/bench.sh` runs the same five programs on OctoForth, on TAQOZ
Reloaded and on P2XCForth, one after the other on a P2-EDGE, each
timed by the system's own counter, in clocks, which do not depend on the
clock frequency. Fewer is faster. OctoForth is built by OctoGo
v1.0.0-rc.3, `--no-inline` (measured 2026-10-31).

| | OctoForth | P2XCForth | TAQOZ |
| --- | --- | --- | --- |
| an empty `DO LOOP`, 100,000 times | 200,132 | 7,200,129 | 3,200,288 |
| an empty colon word called 100,000 times | 6,400,021 | 13,600,129 | 9,600,288 |
| the Byte sieve, 8192 flags, one pass | 1,400,057 | 6,390,449 | 13,546,112 |
| `25 fib`, recursive | 18,080,718 | 53,969,641 | 97,114,008 |
| `10 fact` 10,000 times, recursive | 15,360,026 | 48,960,129 | 42,800,280 |

The sources are in [bench/](bench), the same algorithm in each system's
dialect; the sieve is BYTE's of 1981 as P2XCForth's archive has it, with
8192 flags, in the variant its author measured fastest, whose macros
`scripts/p2xc.sh` takes from his archive with his other block words, none
of them being in this repository. Taken as they are:

- TAQOZ is TAQOZ Reloaded V2.14.0, its author's image of 2024-02-19, at
  200 MHz, which `scripts/taqoz.sh` fetches and the scripts load into hub
  RAM; booted from the board's flash, where it was until OctoForth went
  there, it took the same clocks. Its empty loop takes the 32 clocks an
  iteration its documentation gives. Its sieve array is in its data space,
  which `org` puts just above its image, and is named `fl`, TAQOZ having a
  FLAGS of its own.
- P2XCForth is P2XCForthD, its author's newest, of 2026-04-07, attached to
  his forum post (the project has no repository), built for the P2-EDGE by
  `scripts/p2xc.sh` with four changes, which the script prints: the EDGE's
  20 MHz crystal, no SD card mounted, so no block loaded from it at start,
  and its Spin2 object's `#define`s applied by hand. Its empty loop takes
  the 72 clocks an iteration its documentation gives. Its `recurse` works
  as the one its author posted on 2026-04-08. Its timings move by up to a
  tenth with where its words land in memory (its calls took 15,200,129 in
  one build), and its archive of 2025-07-11 ran within that.
- OctoForth's empty loop runs from cog RAM by REP, 2 clocks an iteration,
  the increment of its index. Its empty word ends in EXIT, which keeps it
  from being inlined: with no EXIT it is inlined to nothing, and the row
  is the empty loop's 200,132 again. Called, it takes 64 clocks an
  iteration: 34 the call and return, 8 the return address kept on the
  return stack, and the rest the loop, which a call keeps in hub RAM.
  `fib` and `fact`, recursive, measure its calls too. Its timings, too,
  move by a few percent with where code lands, a taken branch in hub RAM
  costing 13 to 20 clocks with its target's place: `fact` took 14,560,026
  in another build.

## Third parties' benchmarks

`scripts/third.sh` runs two collections others wrote and other Forths have
been compared with, fetched at pinned hashes and never committed: Anton
Ertl's four (the sieve, bubble sort, matrix multiplication and fib, from
his [Performance of Forth
systems](https://www.complang.tuwien.ac.at/forth/performance.html), which
Gforth's manual compares with too), and the Stanford integer benchmarks
John Hennessy gathered, in Martin Fraeman's Forth of 1989. Every system
runs at 200 MHz, timed by the host between two marks the system writes
around the work, in milliseconds; fewer is faster. OctoForth is built by
OctoGo v1.0.0-rc.3, `--no-inline` (measured 2026-10-31; TAQOZ's column
again on 2026-11-01, its arrays in its data space).

| | OctoForth | P2XCForth | TAQOZ |
| --- | --- | --- | --- |
| Ertl: sieve, 1000 times | 5,503 | does not run | 34,348 |
| Ertl: bubble sort, 6000 | 10,175 | 82,959 | 78,263 |
| Ertl: matrix multiply, 64 by 64 | 208 | 1,288 | 1,152 |
| Ertl: `34 fib` | 7,743 | 23,477 | 42,811 |
| Stanford Perm, 10 times | 768 | does not load | does not load |
| Stanford Towers | 1,393 | | |
| Stanford Queens | 704 | | |
| Stanford Intmm | 1,664 | | |
| Stanford Puzzle | 6,607 | | |
| Stanford Quick | 864 | | |
| Stanford Bubble | 992 | | |
| Stanford Trees | 2,960 | | |

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
names, its data space moved above its image, with a CREATE and an ALLOT of
that space, TAQOZ's own being of its code space, and `2@` and `2!` again
colon definitions. Ertl's sieve does not run
on P2XCForth, whose `+LOOP` ends only when the index equals the limit, and
Fraeman's file does not load there, lacking DOES>, nor on TAQOZ: his
defining words are colon definitions that run CREATE when they run, and
TAQOZ, which compiles a whole line before it runs any of it, runs CREATE
when it compiles them. Every program that ran
gave its expected answer, and each Stanford one passed its own check.
The host's clock ticks every 16 ms, so a Stanford time moves by a tick or
two from run to run, and by up to 5% with where the code lands: TAQOZ's
`34 fib`, which has no array, took 42,075 before its prelude grew.

## What the programs take

`scripts/size.sh` loads the same programs again, as the two scripts above
give them, runs nothing, and asks each system by its own words what it
holds before a program and after it, in bytes. The asking takes up to 140
bytes, which come off the counts but not off the room at start. A prelude
is not counted, nor what a program allots while it runs, as Stanford Trees
does. The three keep their memory differently, so the columns count
different things:

- OctoForth's binary is 505,452 bytes of the hub's 524,288. Of that, 288 KB
  are the two spaces it compiles into, 128 KB for code and 160 KB for data;
  the system itself is the other 210,540. Its headers are in tables of
  their own, room for 1024 headers and 12 KB of names, and are not
  counted here.
- P2XCForth's binary is 386,796 bytes, 300,000 of them its one memory for
  code, headers and data, the last 32 KB of which are its block buffer. Its
  room at start is after its author's words, which the scripts load first.
- TAQOZ's image is 131,072 bytes. Inside it its code grows up and its
  names down, with 62 KB between them; its code column counts both. Its
  data, the variables and the arrays, is in a data space of its own, which
  `org` puts anywhere in the hub RAM: the prelude and bench/ put it just
  above the image, where there are 385,024 bytes up to its buffers at
  $7E000.

| | OctoForth code | OctoForth data | P2XCForth | TAQOZ code | TAQOZ data |
| --- | --- | --- | --- | --- | --- |
| the room at start | 126,176 | 163,824 | 283,168 | 62,278 | 385,020 |
| bench/'s five | 1,268 | 8,192 | 669 | 321 | 8,192 |
| Ertl: sieve | 732 | 8,196 | does not run | 170 | 8,194 |
| Ertl: bubble sort | 1,896 | 24,038 | 25,008 | 497 | 24,004 |
| Ertl: matrix multiply | 1,304 | 49,156 | 49,985 | 402 | 49,156 |
| Ertl: fib | 144 | 0 | 121 | 51 | 0 |
| Stanford, all eight | 22,468 | 68,787 | does not load | does not load | |

OctoForth's code is the largest of the three. A call is a long, and a
primitive copied in is one to three longs, `DUP` one and `*` three, where
a call in TAQOZ is a 16-bit wordcode and in P2XCForth a bytecode and the
word's address, five bytes. Ertl's fib, which allots nothing, is 144
bytes on OctoForth, 121 on P2XCForth, its header counted, and 51 on
TAQOZ, its name counted; his sieve's code is 732 bytes on OctoForth and
170 on TAQOZ. TAQOZ leaves a program the most room of the three, 62 KB for
code and names and 385 KB for data. OctoForth's two spaces hold about as
much as P2XCForth's one memory, enough for Stanford's 68,787 bytes of
data.

## How it works

The P2 has good Forths: Peter Jakacki's TAQOZ, in its ROM, and Christof
Eberspaecher's P2XCForth, whose XBYTE core is up to twice as fast. Every
Forth for the Propeller 1 or 2 that could be found interprets something --
wordcodes, tokens, threads or bytecodes. OctoForth writes machine code
instead, as Mecrisp-Stellaris does on ARM and as the author's own Forth for
the Intel 8080 did in the 1980s, on paper, on a Tesla JPR-1:

- the primitives are copied into a word as P2 instructions, literals
  become their immediates, small colon words are inlined, a call in tail
  position becomes a jump, and a word runs at the address it was written
  to;
- the top of the data stack is in a register and both stacks are in the
  cog's LUT RAM, two to three clocks an access; a call keeps its return
  address in a register, 34 clocks a call and return;
- a loop with no call in it runs from cog RAM, where a taken branch costs
  4 clocks against 13 to 20 in hub RAM, and a DO loop there with no branch
  in its body is repeated by REP (the loop cache, below);
- the outer interpreter, the dictionary and the compiler are OctoGo, so a
  word calls into the OctoGo program it runs in, as `.` and `TYPE` do, and
  an OctoGo program makes words of its functions; `RUN` sends a word to
  run on a cog of its own, as `go` sends a function.

[ASSESSMENT.md](ASSESSMENT.md) is the research it began with: the prior
art, the clocks per operation of TAQOZ, P2XCForth and the design side by
side, the facts checked on the hardware and in the compiler, the
milestones and the risks.

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

Timed by the board's clock when the cache was made (2026-10-28, OctoGo
v0.58.1), one run of each Stanford program, as the mean of eight builds
that move the code by one to eight longs:

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
whose inner loop is such a loop, 208 ms against 224 (2026-10-29).
Fraeman's inner loops branch or call, or are `BEGIN` loops over the
return stack, so only his set-up loops are repeated, and his times move
by no more than where the longer loops move the code to.

## The repository

Developing OctoForth takes OctoGo and a board, its tests running there.

- [forth/](forth): the Forth, its engine and its tests: the interpreter
  and the compiler in OctoGo, and `eng.spin2`, the primitives' templates
  and the code that enters compiled words, the one Spin2 object.
- `main.ogo`: the REPL; [boot/](boot) the REPL the board boots from the
  flash or the card, which runs the startup file; [example/](example) a
  program that embeds the Forth.
- [bench/](bench): the benchmarks in the three systems' dialects, and
  [bench/third/](bench/third) the preludes for the third parties'.
- [scripts/](scripts): what runs the suite, the benchmarks, the card's
  check and the flash's write, each saying in its header what it does.
- [probe/m0](probe/m0): the probe of the research, whose numbers are
  ASSESSMENT.md's.
- [OCTOGO.md](OCTOGO.md): what OctoForth has found out about OctoGo, with
  the programs that show it and the numbers.

```sh
ogo build --no-inline           # oforth.binary, and oforth.p2asm, the assembly it was made of
ogo build --no-inline --report  # where the hub RAM goes
ogo test ./forth                # the tests, on the board, writing on its card and in its flash
scripts/f2012.sh                # the Forth-2012 suite's tests, INCLUDEd by 9P; -sd for the FILE tests on the card
scripts/cardcheck.sh            # fsck.fat -n of the card's volume, from an image of its blocks in use
scripts/flash.sh                # boot/ into the board's flash, then a reset and a check that it answers
scripts/bench.sh                # the benchmarks on OctoForth, TAQOZ and P2XCForth
scripts/third.sh                # the third parties' benchmarks
scripts/size.sh                 # what they take of each system's memory
```

A release: a section in `CHANGELOG.md`, commit, `git tag -a vX.Y.Z`, then
`scripts/release.sh`, which builds the binaries from the tag's sources,
the banner saying the version, into `build/release/vX.Y.Z/`: the zip and
`SHA256SUMS`, for the GitHub release.

The scripts fetch the third parties' code they run, the test suite, TAQOZ
and the benchmarks, at pinned hashes into `build/`, which is never
committed, and need `curl`, `sha256sum` and Python 3; `cardcheck.sh`
needs `fsck.fat` and `mdir`. P2XCForth has no repository: its archive is
downloaded by hand from its author's forum thread, and `scripts/p2xc.sh`
builds it with the flexcc of OctoGo's source tree, which it expects
beside this one, in `../ogo`. The tests make files of their own on the
card in the slot, in its root, and in the flash, and delete them; with no
card in the slot the card's test passes with a note.

## License

BSD-3-Clause, see [LICENSE](LICENSE). The logo is drawn by
[scripts/logo.py](scripts/logo.py) from OctoGo's.
