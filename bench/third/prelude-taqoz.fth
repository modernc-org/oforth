\ TAQOZ's prelude to the third parties' benchmarks, for TAQOZ Reloaded
\ V2.14.0 in the board's flash: the ANS words Ertl's four need that TAQOZ
\ has under other names or not at all. A "pre" word runs while its line
\ compiles, and [C] compiles the next word into it rather than running it,
\ so CONSTANT and VARIABLE run TAQOZ's own := and long, which take the
\ value from the line compiled so far and the name from the input.
pre CONSTANT [C] := ;
pre VARIABLE [C] long ;
\ .( skips its text, as ( does; ABORT" reports and goes on, as an IF, a ."
\ and a THEN.
pre .( [C] ( ;
pre ABORT" [C] IF [C] ." [C] THEN ;
\ CREATE: TAQOZ's own makes no data field ALLOT extends (its address came
\ out 63), and a redefined ALLOT is not the one TAQOZ then finds. So CREATE
\ makes a constant, by :=, and sets its value to HERE right after it, where
\ TAQOZ's ALLOT then reserves code space: the data is in TAQOZ's room
\ between its code and its names, 62 KB.
pre CREATE [C] GRAB 0 [C] := HERE HERE 4 - ! ;
pub DECIMAL DEC ;
pub CELLS 4* ;
pub CELL+ 4+ ;
pub 2@ DUP 4+ @ SWAP @ ;
pub 2! SWAP OVER ! 4+ ! ;
\ TAQOZ finds a definition by its name inside it, and has no RECURSE: this
\ one compiles a call of the newest word, the one being defined.
pre RECURSE @WORDS CPA W@ W, ;
\ Fraeman's Stanford suite does not fit: its arrays take about 69 KB before
\ Trees allocates, and TAQOZ's room between its code and its names is 62 KB.
