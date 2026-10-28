: recurse here@ begin dup @ context @ = 0= while 1- repeat 32 + $26 c, , ; immediate
: empty cnt@ 100000 0 do loop cnt@ swap - ;
: call0 ;
: calls cnt@ 100000 0 do call0 loop cnt@ swap - ;
: size s" 8192" evaluate ; immediate
variable flags1 size allot
3 constant litcode
: flags s" [ litcode c, flags1 , ]" evaluate ; immediate
: do-prime
   flags size 1 fill
   0
   size 0 do
      flags r@ + c@ if
         r@ dup + 3 +
         dup r@ +
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
