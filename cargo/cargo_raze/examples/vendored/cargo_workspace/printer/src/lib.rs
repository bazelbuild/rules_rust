use ferris_says;

use std::io::{stdout, BufWriter};

use rng;

/// Have ferris say a number
pub fn print_number(num: i32) {
  let number = format!("{}", num);
  let stdout = stdout();
  let mut writer = BufWriter::new(stdout.lock());
  ferris_says::say(number.as_bytes(), number.len(), &mut writer).unwrap();
}

/// Have ferris say a random number
pub fn print_random_number() {
  print_number(rng::random_number());
}
