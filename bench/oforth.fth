\ The benchmarks, OctoForth's dialect: each prints a count of clocks.
: empty GETCT 100000 0 DO LOOP GETCT SWAP - ;
: call0 ;
: calls GETCT 100000 0 DO call0 LOOP GETCT SWAP - ;
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
: sieve GETCT do-prime GETCT SWAP - ;
: fib DUP 2 < IF EXIT THEN DUP 1- RECURSE SWAP 2 - RECURSE + ;
: fibs GETCT 25 fib DROP GETCT SWAP - ;
: fact DUP IF DUP 1- RECURSE * ELSE DROP 1 THEN ;
: facts GETCT 10000 0 DO 10 fact DROP LOOP GETCT SWAP - ;
CR .( empty ) empty .
CR .( call ) calls .
CR .( sieve ) sieve .
CR .( fib ) fibs .
CR .( fact ) facts .
