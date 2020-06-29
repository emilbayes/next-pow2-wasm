(module
  (func $align_i16 (export "align_i16") (param $n i32) (result i32) (call $i32.align_i16 (local.get $n)))
  (func $align_i32 (export "align_i32") (param $n i32) (result i32) (call $i32.align_i32 (local.get $n)))
  (func $align_i64 (export "align_i64") (param $n i32) (result i32) (call $i32.align_i64 (local.get $n)))
  (func $next_pow2 (export "next_pow2") (param $n i32) (param $base i32) (result i32) (call $i32.next_pow2 (local.get $n) (local.get $base)))

  ;; Align to next i16
  (func $i32.align_i16
    (param $ptr i32) (result i32)

    (i32.and (i32.add (local.get $ptr) (i32.const 1))
             (i32.const -2)))

  ;; Align to next i32
  (func $i32.align_i32
    (param $ptr i32) (result i32)

    (i32.and (i32.add (local.get $ptr) (i32.const 3))
             (i32.const -4)))

  (func $i32.align_i64
    (param $ptr i32) (result i32)

    (i32.and (i32.add (local.get $ptr) (i32.const 7))
             (i32.const -8)))

  (func $i32.next_pow2
    (param $base i32)
    (param $power i32)
    (result i32)

    ;; This block makes sure $base \in [n, n + 1)
    (i32.add
      (local.get $base)
      (i32.sub (local.get $power) (i32.const 1))) ;; N - 1

    ;; This block negates $power, ie. -N
    (i32.sub (i32.const 0) (local.get $power))

    ;; Clear lowest bits, ie. round down to $power
    (i32.and))

  (func $i64.next_pow2
    (param $base i64)
    (param $power i64)
    (result i64)

    ;; This block makes sure $base \in [n, n + 1)
    (i64.add
      (local.get $base)
      (i64.sub (local.get $power) (i64.const 1))) ;; N - 1

    ;; This block negates $power, ie. -N
    (i64.sub (i64.const 0) (local.get $power))

    ;; Clear lowest bits, ie. round down to $power
    (i64.and)))
