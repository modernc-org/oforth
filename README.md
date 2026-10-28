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

**Status, 2026-10-28: no Forth runs here yet.** The research is done and is
in [ASSESSMENT.md](ASSESSMENT.md), and so is its probe on the board,
[probe/m0](probe/m0): code written into hub RAM at run time from PASM
templates runs beside an OctoGo program, calls back into it, and runs on a
cog of its own. On that, the Forth is to be built; the first milestone is
the kernel and a REPL on the serial line.

## Why another Forth for the P2

The P2 has good Forths: Peter Jakacki's TAQOZ, in its ROM, and Christof
Eberspaecher's P2XCForth, whose XBYTE core is up to twice as fast. Every
Forth for the Propeller 1 or 2 that could be found interprets something --
wordcodes, tokens, threads or bytecodes. OctoForth is to write machine code
instead, as Mecrisp-Stellaris does on ARM and as the author's own Forth for
the Intel 8080 did in the 1980s, on paper, on a Tesla JPR-1:

- the primitives are copied into a word as P2 instructions, literals become
  immediates, small words are inlined, and a word runs at the address it was
  written to;
- the data and return stacks live in a cog's LUT RAM, two to three clocks an
  access, and the top of the stack in a register;
- the outer interpreter, the dictionary and the compiler are OctoGo, so a
  word can call into the OctoGo program it runs in, and a word can be sent to
  run on a cog of its own, as `go` sends a function.

ASSESSMENT.md has the prior art, the clocks per operation of TAQOZ, P2XCForth
and the design side by side, the facts checked on the hardware and in the
compiler, the milestones and the risks. The bar is P2XCForth's, and the
comparison is to be made on one board at one clock, the loops shown.

## License

BSD-3-Clause, see [LICENSE](LICENSE). The logo is drawn by
[scripts/logo.py](scripts/logo.py) from OctoGo's.
