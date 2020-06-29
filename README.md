# `next-pow2-wasm`

> Next power of 2 functions in WASM, eg. for aligning pointers

# Usage

This module includes WebAssembly functions for rounding a number to the next
`N = 2 ** n`, which is often used for aligning words to their
natural boundaries.

The formula in C is `(ptr + (N - 1)) & (-N)`, where `ptr` is the number to align
from and `N` is a power of 2.

In WebAssembly, to align to the next `i32` (4 bytes), the routine would look as
follows:

```wat
(func $i32.align_i32
  (param $ptr i32) (result i32)

  (i32.and (i32.add (local.get $ptr) (i32.const 3))
           (i32.const -4)))
```

A more generalised form is a bit more complicated:

```wat
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
```

WebAssembly does not have a `i32.neg` operation, so instead we must do `0 - N`.

## Fixing memory alignment

### Why

Unaligned memory access can have serious performance implications on some
processor architectures, and even though WASM abstracts away the details of the
actual processor, it cannot patch unaligned access for you.

Further, if you try to wrap a data structure as a multi-byte TypedArray from
Javascript, as is common for returning complex objects from WASM, the addressing
needs to be a multiple of the byte-width of that type, eg. `Float64Array`s need
to start at a multiple of 8, or an Error will be thrown.
Take the example of creating a view to the WASM linear memory eg.
`new Float64Array(wasm.memory.buffer, 12, 5)`, which says "create a view to the
`double`s/`Number`s in the ArrayBuffer `wasm.memory.buffer` starting from
byte-offset 12 and for the next 5 doubles (40 bytes)". This will fail
as an offset of `12` bytes is not a multiple of `8`. Therefore you you need to
round to the next multiple of `8` in your WASM code before you write your data.

The Linux Kernel documentation on [UNALIGNED MEMORY ACCESSES](https://www.kernel.org/doc/Documentation/unaligned-memory-access.txt)
has further details on the implications of unaligned access:

```md
Why unaligned access is bad
===========================

The effects of performing an unaligned memory access vary from architecture
to architecture. It would be easy to write a whole document on the differences
here; a summary of the common scenarios is presented below:

 - Some architectures are able to perform unaligned memory accesses
   transparently, but there is usually a significant performance cost.
 - Some architectures raise processor exceptions when unaligned accesses
   happen. The exception handler is able to correct the unaligned access,
   at significant cost to performance.
 - Some architectures raise processor exceptions when unaligned accesses
   happen, but the exceptions do not contain enough information for the
   unaligned access to be corrected.
 - Some architectures are not capable of unaligned memory access, but will
   silently perform a different memory access to the one that was requested,
   resulting in a subtle code bug that is hard to detect!

It should be obvious from the above that if your code causes unaligned
memory accesses to happen, your code will not work correctly on certain
platforms and will cause performance problems on others.
```

## Specialised for memory access

### `i8`

Single bytes are always naturally aligned, as that is the smallest atom in WASM
linear memory.

### `i16`

Round to the next multiple of 2 (eg. `i32.load16_*`):

```wat
(local i32 $unaligned)
(local i32 $aligned)

(set_local $unaligned (i32.const 3))

(set_local $aligned (i32.and (i32.const -2)
                             (i32.add (i32.const 1)
                                      (get_local $unaligned)))))
```

### `i32`/`f32`

Round to the next multiple of 4 (eg. `i32`, `f32`):

```wat
(local i32 $unaligned)
(local i32 $aligned)

(set_local $unaligned (i32.const 3))

(set_local $aligned (i32.and (i32.const -4)
                             (i32.add (i32.const 3)
                                      (get_local $unaligned)))))
```

### `i64`/`f64`

Round to the next multiple of 8 (eg. `i64`, `f64`):

```wat
(local i32 $unaligned)
(local i32 $aligned)

(set_local $unaligned (i32.const 13))

(set_local $aligned (i32.and (i32.const -8)
                             (i32.add (i32.const 7)
                                      (get_local $unaligned)))))
```

### How it works

The general formula is: `(x + (N - 1)) & (-N)`, where `N` must be a power of 2,
eg. 2, 4, 8, 16, 32, …

The trick is that adding `N - 1` will push the unaligned number into the
interval between two multiples of `[kN, (k + 1)N)` (end exclusive), eg.
`[0, 8)`, `[8, 16)`, `[16, 24)`, `[24, 32)` etc. All we need now is to round
down to the closest multiple of `N`. Since `N` is a power of 2 (`8 = 2^3`), we
can exploit the fact that negative numbers are represented as two's compliment,
meaning that while `+8` has leading zeros, `-8` will have leading ones,
ie. `+8 = 00001000` and `-8 = 11111000`. This means we can use `-8` as a mask
to only keep bits that will keep the number a multiple of `8` (`N = 8` in this
example). Clearing lower three bits here yield a number that's a multiple of `8`.
Check for yourself here:

```
00010110                = 22
│││││││└───── b8 * 1    = 0
││││││└────── b7 * 2    = 2
│││││└─────── b6 * 4    = 4
││││└──────── b5 * 8    = 0
│││└───────── b4 * 16   = 16
││└────────── b3 * 32   = 0
│└─────────── b2 * 64   = 0
└──────────── b1 * 128  = 0
```

See the worked example below rounding the value `15` to the next multiple of `8`:

```
  00001111 = 15
+ 00000111 = +7             add N - 1 to propagate low order bits
---------------
  00010110 = 22 = 15 + 7    note that 22 is between [16, 24)

- 00001000 = +8             negate the factor to create a bit mask
---------------
  11111000 = -8 = -(+8)     two's complement, note the leading 1's

  11111000 = -8
& 00010110 = 22             mask only the high order bits
---------------
  00010000 = 16             recall that `1 & 0 = 0` and `1 & 1 = 1`
```

## License

[ISC](LICENSE)
