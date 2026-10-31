# What this project found out about OctoGo

OctoForth is the third program of size written in OctoGo, after p2-11 and
OctoBeam, and what it finds out about the language and its compiler is
written down here, as p2-11's OCTOGO.md does: what was met, the program
that shows it, what was measured, and what OctoForth does about it
meanwhile. An entry is removed when `ogo` no longer shows it and OctoForth
no longer works around it.

Everything here was measured on a P2-EDGE (P2-EC) at 160 MHz with `ogo`
v1.0.0-rc.3, on 2026-10-31. A number of clocks is good to within sixteen or
so: what a branch in hub memory costs depends on where the build put its
target.

## 1. The fallback of `ogo build` never tries the program without inlining and with its C switches

`ogo build` makes a program in three ways and keeps the first that fits,
saying nothing (`internal/build/build.go`, `plainer`, and `ogo help
build`): its small functions marked inline and every switch of constant
cases a C switch, which the backend dispatches through a table of jumps;
the same with the switches chains of compares; and no function marked,
with chains. OctoForth fits none but the third. Built the first way, its
`octo2`, a switch of fifty cases each calling `push`, `pop` and their kind,
took 222 local registers, past the cog's ("fit 480 failed: pc is 575"),
and the second way the backend said "exceeded local register limit"; with
`octo2` split in three, the first way fits the cog, but the program is
560,428 bytes, 36 KB past the hub. So OctoForth has been built the third
way since it was large, with no switch a table, and nothing told it so.

The fourth way, no function marked and the C switches kept, fits, and is
what `--no-inline` builds; the fallback never tries it. OctoForth's v0.1.0
shows it:

    git clone https://gitlab.com/cznic/oforth && cd oforth && git checkout v0.1.0
    ogo build -o third.binary .               # chains: no jmprel in _forth_octo
    ogo build --no-inline -o fourth.binary .  # jmprel in _forth_octo and _forth_needs

A trap into OctoGo, a word of OctoForth's that OctoGo executes, goes
through `needs`, a switch of a hundred constant cases over scattered
numbers, and `octo`, a switch over 1 to 59 that handed every other number
on to the next switch, eight of them. In a loop of 10,000, clocks an
iteration, v0.1.0's code:

| The word | the third way | `--no-inline` |
| --- | --- | --- |
| `HERE DROP`, `octo`'s 19th case | 1,840 | 1,280 |
| `0 ALLOT`, the 22nd | 2,504 | 2,112 |
| `0 ,`, the 20th | 2,824 | 2,508 |
| `UNUSED DROP`, in the second switch | 3,776 | 1,792 |
| `KEY? DROP`, in the eighth | 5,600 | 2,928 |

The binary is 116 bytes smaller. OctoForth's build of the same day takes
18.6 s the fourth way, where the default takes 65, the first two ways
compiling and failing once each in every pass of the stack sizing.

A smaller program did not show it: a switch of a hundred cases each
calling a small function of two locals fit the first way, the backend
sharing the inlined bodies' registers. What fills OctoForth's switches is
their own temporaries, `_ogo_t0` on, numbered through the function, beside
what the inlined helpers bring to every case.

What would help: the fallback trying the fourth way before the chains, at
least when the first way outgrew the cog or the hub for its inlining; and
a line saying which way a build took when it was not the first, which
would have shown this at once. The ogo session confirmed the gap the same
day and holds both for after v1.0.0, `master` being frozen to fixes while
a candidate is tested: either would change what is built for every
program at the limit, obeam's among them, whose binaries would have to be
validated on the board again. A program that fits none of the three ways
while `--no-inline` fits would be a false refusal, which is fixed now:
that is to be sent to it at once.

What OctoForth does meanwhile: every script, the release and the README's
commands build with `--no-inline` (`ogo test` has no such flag, and its
tests run the third way); `octo` sends a word after its own switch's
straight to the switch that holds it, by the run of numbers it is in; and
`allot` and `comma` keep the data space's address and its DP cell in
variables, a small function being a call either way. On the third way's
build that makes `KEY?` 2,072 clocks and `ALLOT` 1,808; on the fourth's
1,816 and 1,440, and `HERE` 1,248.
