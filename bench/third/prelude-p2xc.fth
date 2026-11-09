\ P2XCForth's prelude to the third parties' benchmarks, for P2XCForthF of
\ 2026-11-07. It follows build/p2xc/author.fth, which scripts/p2xc.sh takes
\ from the archive: its author's words his start-up loads from the SD card,
\ which the build for the shared board does not mount (i, <>, cells and
\ the like). RECURSE by the method he posted on 2026-04-08: the newest
\ header's link field is the cell below HERE that holds CONTEXT, its code
\ field 32 bytes on, and a call the wcall byte $26 and that address.
: newest ( -- lfa ) here@ begin dup @ context @ = 0= while 1- repeat ;
: recurse newest 32 + $26 c, , ; immediate
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
\ The SC32 kernel's words Fraeman's suite uses. DO keeps the index of the
\ loop around it and its own limit on the return stack here, the limit on
\ top, and its own index in a register, which seti sets, so undo drops the
\ limit and puts the outer index back, under the return.
: 2pick >r over r> swap ;
: 3pick >r >r over r> swap r> swap ;
: rdrop r> r> drop >r ;
: undo r> r> drop r> seti >r ;
: recursive newest context ! ; immediate
\ Only timetype, which is not run, uses these:
variable base
: <# ; : #s ; : #> ;
: u.lz 2drop ;
\ +LOOP is P2XCForthF's own, a bytecode that ends the loop when the index
\ reaches or passes the limit, as its LOOP does. P2XCForthD's ended only
\ when the index equalled the limit, which the sieve's steps pass, and was
\ a trap into its C, and this prelude had a +LOOP of its own for it.
\ What cannot be given here: DOES>, which Fraeman's structures, and so his
\ Towers and Trees, are made with.
