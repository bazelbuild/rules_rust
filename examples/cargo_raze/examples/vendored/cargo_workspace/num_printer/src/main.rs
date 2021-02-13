use clap::{App, Arg};

use printer;

fn main() {
  let matches = App::new("Number Printer")
    .about("Print some numbers")
    .arg(Arg::with_name("rng").help("Print a random number"))
    .arg(
      Arg::with_name("num")
        .help("Print this number")
        .takes_value(true),
    )
    .get_matches();

  let num = match matches.value_of("num") {
    Some(value) => value.parse::<i32>().unwrap(),
    None => 1337,
  };

  if matches.is_present("rng") {
    printer::print_random_number();
  } else {
    printer::print_number(num);
  }
}
