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

### Added

- **What the benchmarks take of each system's memory**, and the room they
  leave, in the README beside their clocks, measured by `scripts/size.sh`.

### Changed

- **The benchmark of calls calls**: the empty word of `examples/bench.fth`
  ends in EXIT, which keeps OctoForth from inlining it. Inlined, it was the
  empty loop again, 200,132 clocks; called, it takes 6,400,021, against
  P2XCForth's 13,600,129 and TAQOZ's 9,600,288.

### Fixed

- **A word OctoGo executes is cheaper to call from compiled code**, `HERE`,
  `,` and `ALLOT` among them, which a program that builds data at run time
  calls by the thousand. A word goes straight to the switch that holds it,
  where it was handed on from one switch to the next, and `ALLOT` and `,`
  reach the data space without a call. In a loop, at 160 MHz: `HERE` 1,248
  clocks, against v0.1.0's 1,840; `ALLOT` 1,440 against 2,504; `,` 1,670
  against 2,824; `KEY?` 1,816 against 5,600. Stanford Trees, which allocates
  its nodes so, takes 2,960 ms against 3,376, at 200 MHz.

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
