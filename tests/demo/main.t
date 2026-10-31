//! Uses the map as a dependent would, and prints what it finds: the test
//! compares that with `tests/expected.txt`.

use alloc::string::String;
use core::fmt::Display;
use hashmap::{Entry, Map};
use std::io::Stdout;

fn main(os: std::Os) -> Result<(), std::io::Error> {
    let mut out = os.stdout;
    strings(&mut out)?;
    integers(&mut out)?;
    many(&mut out)?;
    linear(&mut out)?;
    Result::Ok(())
}

/// `String` keys, asked about by `&str` and by `&String`.
fn strings(out: &mut Stdout) -> Result<(), std::io::Error> {
    let mut ages: Map<String, u8> = Map::new();
    out.line(&ages.is_empty())?;                                // true
    out.line(&ages.insert(String::from("ada"), 36).is_none())?; // true
    ages.insert(String::from("alan"), 41);
    out.line(&ages.len())?;                      // 2
    show(out, ages.get("ada"))?;                 // 36
    show(out, ages.get(&String::from("alan")))?; // 41
    show(out, ages.get("grace"))?;               // none
    // A new value for a key that's there: the old one comes back.
    show(out, ages.insert(String::from("ada"), 37).as_ref())?; // 36
    out.line(&ages.len())?;                                    // 2
    match ages.get_mut("alan") {
        Option::Some(v) => *v = *v + 1,
        Option::None => {},
    }
    show(out, ages.get("alan"))?;            // 42
    out.line(&ages.contains_key("ada"))?;    // true
    show(out, ages.remove("ada").as_ref())?; // 37
    out.line(&ages.contains_key("ada"))?;    // false
    show(out, ages.remove("ada").as_ref())?; // none
    out.line(&ages.len())?;                  // 1
    Result::Ok(())
}

/// Keys of each integer type, `bool` and `char`, negative ones too.
fn integers(out: &mut Stdout) -> Result<(), std::io::Error> {
    let mut m: Map<i64, i64> = Map::new();
    let keys: [i64; 5] = [-1, 0, 1, -9223372036854775807 - 1, 9223372036854775807];
    for k in keys.iter() {
        m.insert(*k, *k / 2);
    }
    out.line(&m.len())?; // 5
    for k in keys.iter() {
        show(out, m.get(k))?;
    }
    let mut c: Map<char, bool> = Map::new();
    c.insert('a', true);
    c.insert('é', false);
    out.line(&c.get(&'é').is_some())?; // true
    let mut b: Map<bool, u64> = Map::new();
    b.insert(true, 1);
    b.insert(false, 0);
    b.insert(true, 2);
    out.line(&b.len())?; // 2
    Result::Ok(())
}

/// Enough keys to grow many times, then all of them taken out again.
fn many(out: &mut Stdout) -> Result<(), std::io::Error> {
    let mut m: Map<u32, u32> = Map::new();
    let mut i: u32 = 0;
    while i < 1000 {
        m.insert(i, i * 2);
        i = i + 1;
    }
    out.line(&m.len())?; // 1000
    let mut sum: u64 = 0;
    for e in m.iter() {
        sum = sum + e.value as u64;
    }
    out.line(&sum)?; // 999000
    for e in m.iter_mut() {
        *e.value = *e.key;
    }
    show(out, m.get(&777))?; // 777
    let mut j: u32 = 0;
    while j < 1000 {
        if j % 2 == 0 {
            m.remove(&j);
        }
        j = j + 1;
    }
    out.line(&m.len())?;              // 500
    out.line(&m.contains_key(&777))?; // true
    out.line(&m.contains_key(&778))?; // false
    Result::Ok(())
}

/// A value that can't be thrown away: the map is used up by `free_with`.
struct Token { n: u32 }

fn linear(out: &mut Stdout) -> Result<(), std::io::Error> {
    let mut m: Map<u32, Token> = Map::new();
    let mut total: u32 = 0;
    // What `insert` gives back has to be used up as well.
    total = total + put(&mut m, 1, 10);
    total = total + put(&mut m, 2, 20);
    total = total + put(&mut m, 1, 5);
    m.free_with(|e: Entry<u32, Token>| {
        let Token { n } = e.value;
        total = total + n;
    });
    out.line(&total)?; // 35
    Result::Ok(())
}

/// Gives `k` a token of `n`, and returns what the token it had held.
fn put(m: &mut Map<u32, Token>, k: u32, n: u32) -> u32 with alloc {
    match m.insert(k, Token { n }) {
        Option::Some(Token { n }) => n,
        Option::None => 0,
    }
}

fn show<D: Display>(out: &mut Stdout, v: Option<&D>) -> Result<(), std::io::Error> {
    match v {
        Option::Some(v) => out.line(v),
        Option::None => out.line(&"none"),
    }
}
