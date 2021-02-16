#[macro_use]
extern crate log;
extern crate env_logger;
extern crate rand;

use rand::Rng;

pub fn main() {
  env_logger::init();

  let random_val = rand::thread_rng().gen::<i64>();

  info!("Got a value: {}", random_val);
}
