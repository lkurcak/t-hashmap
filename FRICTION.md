# Friction log

What got in the way of writing a hash map library in T, with the code that
hit it. Each entry is labelled:

- **gap**: T should have it;
- **by design**: T leaves it out on purpose, and the entry says what that
  costs here;
- **unsure**: not clear which.

Positive findings, where something worked better than expected, are
labelled **works**. The log is evidence for t-lang's plans, not a design
for them.

Written against `t` 0.40.0; updated for 0.41.0.

## Looking up `String` keys by `&str` — unsure

Rust does this with `Borrow<Q>`, and `get<Q: ?Sized>(&self, k: &Q) where
K: Borrow<Q>`. T has neither: a trait can't have type parameters yet
("a trait can't have type parameters (yet); its methods can"), and a type
parameter can't stand for `str` ("`str` can only be behind a shared
reference"). An associated type `type View = str;` fails for the same
reason.

What works is the other way round: a *probe* type that knows which keys
it's for.

```rust,ignore
export trait Probe: Copy {
    type Key;
    fn hash_with(self, h: &mut Hasher);
    fn is(self, key: &Self::Key) -> bool;
}
impl<'a, K: Hash + Eq> Probe for &'a K { type Key = K; .. }
impl<'a> Probe for &'a str { type Key = String; .. }
```

and `get<P: Probe<Key = K>>(&self, p: P)`. The two impls don't overlap (the
checker accepts them: `str` can't be a `K`), `ages.get("ada")` and
`m.get(&777)` both infer, the literal's type included. It's arguably
clearer than `Borrow` (one trait, says what it's for), but every library
that wants this will invent its own `Probe`.

## `x % n < n` isn't proved for a variable `n` — fixed in 0.41.0

The bucket of a hash is `h % n`, and indexing needs `i < n`:

```rust,ignore
fn slot(h: u64, n: { n: usize | n > 0 }) -> { i: usize | i < n } {
    ((h & 0xffff_ffff) as usize) % n
}
// error: can't prove `i < n` for the result of `slot`
```

`%` by a variable isn't linear, so the solver knows nothing of it. But `0 <=
x % n < n` for `n > 0` (unsigned) is a fact the checker could add whenever
it sees `%`, as it does for `&`: the mask version, `& (n - 1)`, is proved,
and that's what the map uses, with a power of two of buckets.

Since 0.41.0 the checker knows what `%` by any divisor gives (t-lang step
28), so `h % n` proves `i < n`. The map keeps the mask, now with a comment
saying why: one `&` instead of a division, and `n` is always a power of
two (`grow` doubles it). What's still missing is saying so: `n & (n - 1)
== 0` isn't a fact T can state of a field, so the mask's correctness
rests on the comment.

## The map's invariant can't be stated — gap

`len` is the number of entries in all the buckets. T can't say so: a
field refinement can't sum over a list, and facts don't survive `&mut`
borrows anyway (step 21 deferred invariants across `&mut`). So taking a key
out can't prove `len > 0`:

```rust,ignore
// It has this key, so `len` is at least 1; but that's the map's
// invariant, which T can't state yet.
if self.len > 0 {
    self.len = self.len - 1;
}
```

The guard is dead code that hides a bug if the invariant ever breaks.

## Facts are forgotten at every `&mut` call — unsure

`insert` checks `len` can still count one more, then puts the entry in,
then adds one: the call in between forgets the check.

```rust,ignore
if self.len == greatest() { out_of_memory(); }
self.put(Entry { key, value });
self.len = self.len + 1;
// error: `+` may panic ... mutable lending invalidated facts about `(*self)`
```

Moving the check after `put` fixes it. `put` can't change `len`, but its
signature doesn't say so: knowing which fields a `&mut self` method writes
would need effects on places, or `put` taking `&mut self.buckets` instead
(which it can't, being a method). Similar in `remove_entry`: `m ==
bucket.len()` is lost in a loop that lends `bucket`, so the loop compares
with `bucket.len()` each time instead.

## No `if let` — fixed in 0.41.0

Four places want "return early if it's there":

```rust,ignore
match self.get_mut(&key) {
    Option::Some(v) => return Option::Some(replace(v, value)),
    Option::None => {},
}
```

(tcalc's findings noted it too.)

Since 0.41.0 (t-lang step 28) they're `if let`, and the iterators'
"next bucket or stop" is a `let .. else`:

```rust,ignore
if let Option::Some(e) = self.bucket.next() {
    return Option::Some(e);
}
let Option::Some(b) = self.buckets.next() else { return Option::None };
self.bucket = b.iter();
```

Nothing surprising in porting: the borrow of `self.bucket` in the
`if let` ends where the arm does, as it did in the `match`.

## `insert` needs `K: Discard` — by design

When the key is there, the new key is thrown away (the old one stays, as
in Rust), so `insert` is in an `impl<K: Hash + Eq + Discard, V>`. A map of
linear keys can be built and used, but not inserted into. A linear-key
`insert` would have to give the key back: `Result<Option<V>, K>`, or an
`Entry`-returning `replace`. Linear values are fine: `insert` gives the
old value back, and the caller must use it up, which the demo's `Token`s
show.

## One `Hash` impl per integer type — unsure

`impl<T: Int> Hash for T` would overlap with `impl Hash for String` (no
negative reasoning, so `String: Int` can't be ruled out), so it's ten
impls. And a signed integer's bits need a trick, as `as` doesn't
reinterpret and there's no `to_bits`:

```rust,ignore
fn bits(x: i64) -> u64 {
    if x < 0 { (-(x + 1)) as u64 | 0x8000_0000_0000_0000 } else { x as u64 }
}
```

## No tuples — unsure

Iterating gives `&Entry<K, V>` (`e.key`, `e.value`) and `iter_mut` an
`EntryMut { key: &K, value: &mut V }`, where Rust gives `(&K, &V)`. Named
fields read fine; it's two more exported types.

## The hash can't be keyed — by design

A keyed hash (SipHash with a random key, as Rust's `HashMap`) needs
randomness, which is I/O, which needs the `Os` (docs/19). A map could take
a key from its creator (`Map::with_key(k)`), and `std` could give one out
from `Os`. Until then keys from an adversary can be made to collide.

## No `t test` — gap

The tests are a dependent program in `tests/demo` (by path: `hashmap = {
path = "../.." }`), its output compared with `tests/expected.txt` by a
shell script, as tcalc does. Each check is a printed line and a `//`
comment saying what it should be, which nothing checks but the diff.

## What worked — works

- Nested closures capturing `&mut self`, through effect-polymorphic
  `free_with`, to move every entry into the new buckets when growing:
  `old.free_with(|b| b.free_with(|e| self.put(e)))`.
- Linear values in a generic container with no `unsafe`: `free_with` is
  how a map of them is used up, as for `List`.
- Separate checking: `t check lib.t` checks the library alone, with no
  `main`, and what it exports is what's live.
- The library needed no `unsafe` and no `with panic`: overflow of `len` is
  `out_of_memory()`, as in `List::push`.
