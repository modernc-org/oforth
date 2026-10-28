\ P2XCForth's prelude to the third parties' benchmarks, for P2XCForthD of
\ 2026-04-07. First, its author's own definitions, from the block 2 his
\ start-up loads from the SD card, which the build for the shared board does
\ not mount, and from his Blocks2-10.fth:
: eval$ s" evaluate " evaluate ; immediate
: i s" r@" eval$ ; immediate
: 2drop s" drop drop " eval$ ; immediate
: ?dup dup if dup then ;
: <> = 0= ;
: cells s" 2 << " eval$ ; immediate
: spaces ffor 32 emit fnext ;
\ his recurse, posted on 2026-04-08, with this version's words for <> and
\ 8 cells:
: recurse here@ begin dup @ context @ = 0= while 1- repeat 32 + $26 c, , ; immediate
\ Then what the programs need that it does not have, written here. .( skips
\ its text, as ( does; abort" reports and goes on, there being no ABORT to
\ compile; LEAVE compiles nothing (bubble-sort.fs has it in a word main does
\ not run); P2XCForth counts in decimal only.
' ( constant paren
: .( paren execute ; immediate
: decimal ;
4 constant cell
: cell+ 4 + ;
: cell- 4 - ;
: align ;
: 2@ dup 4 + @ swap @ ;
: 2! swap over ! 4 + ! ;
' if constant tif
' then constant tthen
' ." constant tdotq
: abort" tif execute tdotq execute tthen execute ; immediate
: leave ;
3 constant litcode
: ['] ' litcode c, , ; immediate
: true -1 ;
: false 0 ;
: 2* 1 << ;
: 2/ 1 asr ;
: 0> 0 > ;
: -rot rot rot ;
: /mod 2dup mod -rot / ;
: type begin dup while swap dup c@ emit 1+ swap 1- repeat 2drop ;
\ The SC32 kernel's words Fraeman's suite uses. DO keeps the limit and the
\ index on the return stack here, so undo drops two cells under the return.
: 2pick >r over r> swap ;
: 3pick >r >r over r> swap r> swap ;
: rdrop r> r> drop >r ;
: undo r> r> drop r> drop >r ;
: recursive here@ begin dup @ context @ = 0= while 1- repeat context ! ; immediate
\ Only timetype, which is not run, uses these:
variable base
: <# ; : #s ; : #> ;
: u.lz 2drop ;
\ What cannot be given here: DOES>, which Fraeman's structures, and so his
\ Towers and Trees, are made with; and an ANS +LOOP: P2XCForth's ends when
\ the index equals the limit, and the sieve's steps past it.
