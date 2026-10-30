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

The first release, built and tested with OctoGo v1.0.0-rc.3.

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
  answers, and first interprets `flash:boot.fth`, unless a key comes within
  half a second.
- **The embedding**: `forth/` is the whole Forth, one directory an OctoGo
  program copies, with `Init`, `Define`, `Push`, `Pop`, `Evaluate`,
  `Serial`, `Quit`, `Exit` and `Boot`; `example/` is such a program.
- **The benchmarks**: `scripts/bench.sh` and `scripts/third.sh` run five
  programs of this repository's and the third parties' of Anton Ertl and
  Martin Fraeman on OctoForth, TAQOZ Reloaded and P2XCForth, on one board.
