use clap::{App, Arg};

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
        println!("{}", printer::say_random_number());
    } else {
        println!("{}", printer::say_number(num));
    }
}
