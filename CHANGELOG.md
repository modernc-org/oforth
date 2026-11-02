# Changelog

Notable changes per release of OctoForth: the Forth, the binaries a release
carries, and the `forth` package an OctoGo program embeds. OctoForth is an
early preview and its version numbers say so: a release may refuse a program
the last one took, or change a function of the package, and such changes are
called out under **Behaviour changes**.

A released section is frozen: it says what that release did, and a later fix
to the same area is a new entry under **Unreleased**, not an edit to the old
one. `git show vX.Y.Z:CHANGELOG.md` is the check.

## Unreleased

### Fixed

- **A file a write of which failed fails from then on**: what its buffer
  held was lost, as before, but a later `FLUSH-FILE` answered 0 and a
  later write went on past the lost bytes, leaving a gap of zeros in the
  file. Now every word but `CLOSE-FILE` fails on it until it is opened
  again, as a Go `bufio.Writer` does after an error, and `CLOSE-FILE`
  closes it and fails.

## v0.2.0

A second preview, built and tested with OctoGo v1.0.0-rc.3, as v0.1.0 was.

### Added

- **`OPTIMIZE-SIZE` and `OPTIMIZE-SPEED`**, as `-Os` and `-O2` are to a C
  compiler: code compiled under `OPTIMIZE-SIZE` inlines no colon word
  longer than the call it would take the place of, and runs no loop from
  cog RAM; `OPTIMIZE-SPEED`, the default, goes back. Stanford's eight take
  19,632 bytes of code against 22,468, and 20,175 ms against 15,951.
  `scripts/bench.sh`, `size.sh` and `third.sh` measure it with `-size`.
- **What the benchmarks take of each system's memory**, and the room they
  leave, in the README beside their clocks, measured by `scripts/size.sh`.

### Changed

- **The benchmark of calls calls**: the empty word of `bench/oforth.fth`
  ends in EXIT, which keeps OctoForth from inlining it. Inlined, it was the
  empty loop again, 200,132 clocks; called, it takes 6,400,021, against
  P2XCForth's 13,600,129 and TAQOZ's 9,600,288.

### Fixed

- **Source pasted faster than the REPL takes it is no longer garbled**: the
  REPL echoes every byte and says ok after every line at the serial line's
  speed, so a paste with no pause between its lines fell behind by about
  five bytes a line, and past some 800 lines, or more short ones, it ran
  over the console's ring of 4 KB, which then gave lines twice or out of
  order, saying nothing (3,000 lines of `1+` gave 2,992, a stray `+` and
  the last line twice). Now the lines before the gap are interpreted, the
  rest of the paste is dropped, and the line the gap cut is an error,
  `input lost: it came too fast`, THROW code -57.
- **A directory whose chain of clusters loops**, on a damaged card, ends a
  walk at FAT's limit of 65,536 entries a directory with "the card's FAT
  is damaged", where it was walked for ever; a directory is not grown past
  the limit ("the directory is full").
- **A word OctoGo executes is cheaper to call from compiled code**, `HERE`,
  `,` and `ALLOT` among them, which a program that builds data at run time
  calls by the thousand. A word goes straight to the switch that holds it,
  where it was handed on from one switch to the next, and `ALLOT` and `,`
  reach the data space without a call. In a loop, at 160 MHz: `HERE` 1,248
  clocks, against v0.1.0's 1,840; `ALLOT` 1,440 against 2,504; `,` 1,670
  against 2,824; `KEY?` 1,816 against 5,600. Stanford Trees, which allocates
  its nodes so, takes 2,960 ms against 3,376, at 200 MHz.
- **TAQOZ's arrays are in its data space** in the benchmarks: the prelude of
  the third parties' programs and `bench/taqoz.fth` put TAQOZ Reloaded's
  arrays and variables in the data space it keeps apart from its code,
  which `org` puts above its image, with 385,024 bytes up to its buffers.
  They were in its code space, by the prelude's CREATE, or at a fixed
  address there, and the README said that Fraeman's Stanford suite did not
  fit TAQOZ's 62 KB of room; it does not load there, for its defining
  words. The README's table of what the programs take has TAQOZ's code and
  data apart. Its clocks are what they were, to the clock in `bench/` and
  within 2% in Ertl's four, with where its code lands.

### Toolchain

- **OctoForth is built `--no-inline`**: the scripts, the release and the
  README's commands. OctoGo inlines small functions unless told not to,
  which OctoForth has no hub RAM for, and then builds it with every switch a
  chain of compares, saying nothing; `--no-inline` keeps them tables of
  jumps, and builds in a third of the time (OCTOGO.md, 1).

## v0.1.0

The first release, a preview, built and tested with OctoGo v1.0.0-rc.3: its
binaries are rc.3's output, and the README's numbers were measured with it.
OctoGo's v1.0.0 is not out yet; a later release will be built with it and
measured again.

### Added

- **A Forth that compiles to P2 machine code**: every colon definition is
  compiled as it is defined, its primitives copied in from PASM templates as
  P2 instructions, literals folded into their immediates, small words
  inlined, and a call in tail position made a jump. The top of the data stack
  is in a register, both stacks are in the cog's LUT RAM, and a call keeps
  its return address in a register. `SEE` shows a word's machine code as the
  words it was compiled from.
- **The loop cache**: a loop with no call in it runs from cog RAM, copied
  there when it is entered and kept while its tag matches, and a DO loop
  there with no branch in its body is repeated by REP: an empty one takes 2
  clocks an iteration.
- **The word sets** of Forth-2012: CORE, CORE EXT but the obsolescent
  `[COMPILE]`, DOUBLE, EXCEPTION, FILE, STRING, and TOOLS and TOOLS EXT but
  the wordlists' and the assembler's words, with `KEY?` and `MS`. The
  Forth-2012 test suite's tests of them pass on the board with 0 errors
  (`scripts/f2012.sh`). The system's errors are THROWn with the standard's
  codes, so that `CATCH` catches them.
- **The P2 words**: the functions of OctoGo's `p2` package for the pins,
  smart pins, clocks, locks and LUT, as words named after them
  (`PIN-TOGGLE`, `WAIT-MS`, `GET-CT`, ...), a literal pin folded into the
  instruction; and `RUN`, which runs a word on a cog of its own.
- **Files**: the FILE words on the host's files, by 9P over the serial line,
  which `ogo run -9 DIR` and `loadp2 -9 DIR` serve; on the SD card in the
  board's slot, a name after `sd:`, a FAT32 volume with long names; and in
  the board's flash, a name after `flash:`, a file there written as it is
  made and read after.
- **Booting with no host**: `boot.binary`, written into the board's flash by
  `scripts/flash.sh` or `loadp2 -FLASH`, boots at every reset that no loader
  answers; as an SD card's `_BOOT_P2.BIX`, it boots from the card with the
  P2-EDGE's FLASH switch off. It first interprets `sd:boot.fth`, or
  `flash:boot.fth` if the card has none, unless a key comes within half a
  second.
- **The embedding**: `forth/` is the whole Forth, one directory an OctoGo
  program copies, with `Init`, `Define`, `Push`, `Pop`, `Evaluate`,
  `Serial`, `Quit`, `Exit` and `Boot`; `example/` is such a program.
- **The benchmarks**: `scripts/bench.sh` and `scripts/third.sh` run five
  programs of this repository's and the third parties' of Anton Ertl and
  Martin Fraeman on OctoForth, TAQOZ Reloaded and P2XCForth, on one board.
