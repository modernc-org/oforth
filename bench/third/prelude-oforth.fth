\ OctoForth's prelude to the third parties' benchmarks: the words of the
\ SC32 kernel Martin Fraeman's Stanford suite was written for, which its
\ first lines name, in ANS Forth. Ertl's four need nothing.
1 CELLS CONSTANT cell
: not 0= ;
: 2pick 2 PICK ;
: 3pick 3 PICK ;
: cell- 1 CELLS - ;
: rdrop POSTPONE R> POSTPONE DROP ; IMMEDIATE
: undo POSTPONE UNLOOP ; IMMEDIATE
: u.lz ( u n -- ) >R 0 <# R> 0 ?DO # LOOP #> TYPE ;
