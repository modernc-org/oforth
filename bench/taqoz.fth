: empty CNT@ 100000 0 DO LOOP CNT@ SWAP - ;
: call0 ;
: calls CNT@ 100000 0 DO call0 LOOP CNT@ SWAP - ;
8192 := sz
\ The sieve's flags are in TAQOZ Reloaded's data space, which org puts just
\ above its image, as bench/third/prelude-taqoz.fth does, and bytes makes
\ the array there. TAQOZ has a FLAGS of its own, which a := of the same name
\ breaks, so the array is fl here, and its size sz.
$20000 org
sz bytes fl
: do-prime
   fl sz 1 FILL
   0
   sz 0 DO
      fl I + C@ IF
         I DUP + 3 +
         DUP I +
         BEGIN DUP sz <
         WHILE
            0 OVER fl + C!
            OVER +
         REPEAT
         DROP DROP 1+
      THEN
   LOOP
   DROP ;
: sieve CNT@ do-prime CNT@ SWAP - ;
: fib DUP 2 < IF EXIT THEN DUP 1- fib SWAP 2 - fib + ;
: fibs CNT@ 25 fib DROP CNT@ SWAP - ;
: fact DUP IF DUP 1- fact * ELSE DROP 1 THEN ;
: facts CNT@ 10000 0 DO 10 fact DROP LOOP CNT@ SWAP - ;
empty .
calls .
sieve .
fibs .
facts .
