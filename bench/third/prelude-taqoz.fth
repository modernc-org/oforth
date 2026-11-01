\ TAQOZ's prelude to the third parties' benchmarks, for TAQOZ Reloaded
\ V2.14.0, the image scripts/taqoz.sh fetches: the ANS words Ertl's four
\ need that TAQOZ has under other names or not at all.
\ TAQOZ keeps its data in a data space of its own, apart from its code,
\ which org puts anywhere in the hub RAM: here just above the image's
\ 128 KB, where up to TAQOZ's buffers at $7E000 (BUFFERS) there are 385,024
\ bytes, of which its video player, not run here, takes a buffer from
\ $20000 (BMVBUF). The variables go there, and CREATE's and ALLOT's data.
$20000 org
\ A "pre" word runs while its line compiles, and [C] compiles the next word
\ into it rather than running it, so CONSTANT and VARIABLE run TAQOZ's own
\ := and long, which take the value from the line compiled so far and the
\ name from the input.
pre CONSTANT [C] := ;
pre VARIABLE [C] long ;
\ .( skips its text, as ( does; ABORT" reports and goes on, as an IF, a ."
\ and a THEN.
pre .( [C] ( ;
pre ABORT" [C] IF [C] ." [C] THEN ;
\ ALLOT: TAQOZ's own reserves code space, and TAQOZ finds its kernel's
\ words before any defined later, so the kernel's is renamed first, as its
\ author does with ; in EXTEND.FTH, to a name of the same length, which
\ REWORD needs. This one moves the data space's pointer, by org.
REWORD ALLOT CALOT
pub ALLOT org@ + org ;
\ CREATE: TAQOZ's own is for DOES>, whose code takes the data's address by
\ R>, and leaves nothing on the stack without it. This one makes a constant,
\ by :=, of the data space's pointer, aligned first, as ANS's CREATE
\ aligns it.
pre CREATE [C] GRAB org@ 3 + -4 AND DUP org [C] := ;
pub DECIMAL DEC ;
pub CELLS 4* ;
pub CELL+ 4+ ;
pub 2@ DUP 4+ @ SWAP @ ;
pub 2! SWAP OVER ! 4+ ! ;
\ TAQOZ finds a definition by its name inside it, and has no RECURSE: this
\ one compiles a call of the newest word, the one being defined.
pre RECURSE @WORDS CPA W@ W, ;
\ Fraeman's Stanford suite does not load. Its defining words, STRUCTURE,
\ STRUCT: and MAKESTRUCT, are colon definitions that run CREATE or VARIABLE
\ when they run, and TAQOZ runs a pre word when it compiles the definition
\ (CREATE took HERE for its name inside STRUCTURE); nor could a colon
\ definition read the name after it, TAQOZ compiling a whole line before it
\ runs any of it, a name it does not know being an error then.
