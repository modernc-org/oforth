\ The benchmarks, OctoForth's dialect: each prints a count of clocks.
: empty GET-CT 100000 0 DO LOOP GET-CT SWAP - ;
\ call0 ends in EXIT, which keeps it from being inlined: an empty word
\ with no EXIT is inlined to nothing, and calls would be the empty loop.
: call0 EXIT ;
: calls GET-CT 100000 0 DO call0 LOOP GET-CT SWAP - ;
8192 CONSTANT size
CREATE flags size ALLOT
: do-prime
   flags size 1 FILL
   0
   size 0 DO
      flags I + C@ IF
         I DUP + 3 +
         DUP I +
         BEGIN DUP size <
         WHILE
            0 OVER flags + C!
            OVER +
         REPEAT
         DROP DROP 1+
      THEN
   LOOP
   DROP ;
: sieve GET-CT do-prime GET-CT SWAP - ;
: fib DUP 2 < IF EXIT THEN DUP 1- RECURSE SWAP 2 - RECURSE + ;
: fibs GET-CT 25 fib DROP GET-CT SWAP - ;
: fact DUP IF DUP 1- RECURSE * ELSE DROP 1 THEN ;
: facts GET-CT 10000 0 DO 10 fact DROP LOOP GET-CT SWAP - ;
CR .( empty ) empty .
CR .( call ) calls .
CR .( sieve ) sieve .
CR .( fib ) fibs .
CR .( fact ) facts .
