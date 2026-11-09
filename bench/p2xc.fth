\ The benchmarks, P2XCForth's dialect, after build/p2xc/author.fth, which
\ gives its author's block words and his sieve's size and flags macros, and
\ i, the loop's index: r@ in P2XCForthD, a register in P2XCForthF.
\ RECURSE, by the method he posted on 2026-04-08: the newest header's link
\ field is the cell below HERE that holds CONTEXT, its code field 32 bytes
\ on, and a call the wcall byte $26 and that address.
: newest ( -- lfa ) here@ begin dup @ context @ = 0= while 1- repeat ;
: recurse newest 32 + $26 c, , ; immediate
: empty cnt@ 100000 0 do loop cnt@ swap - ;
: call0 ;
: calls cnt@ 100000 0 do call0 loop cnt@ swap - ;
: do-prime
   flags size 1 fill
   0
   size 0 do
      flags i + c@ if
         i dup + 3 +
         dup i +
         begin dup size <
         while
            0 over flags + c!
            over +
         repeat
         drop drop 1+
      then
   loop
   drop ;
: sieve cnt@ do-prime cnt@ swap - ;
: fib dup 2 < if exit then dup 1- recurse swap 2 - recurse + ;
: fibs cnt@ 25 fib drop cnt@ swap - ;
: fact dup if dup 1- recurse * else drop 1 then ;
: facts cnt@ 10000 0 do 10 fact drop loop cnt@ swap - ;
empty .
calls .
sieve .
fibs .
facts .
