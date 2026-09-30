use std::io::{self, Read};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() > 1 && args[1] == "supports" {
        std::process::exit(0);
    }

    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();

    let modified = input.replace("{{secret}}", "42");

    // mdBook preprocessors receive a JSON array containing `[context,
    // book]` on stdin. They are expected to return only the `book`
    // object on stdout.
    //
    // This is a very simple JSON parser that counts brackets to find
    // the comma separating the two elements, mapping `[context,
    // book]` to `book`.
    let mut depth = 0;
    let mut split_index = 0;
    let bytes = modified.as_bytes();
    for (i, &b) in bytes.iter().enumerate() {
        if b == b'[' || b == b'{' {
            depth += 1;
        } else if b == b']' || b == b'}' {
            depth -= 1;
        } else if b == b',' && depth == 1 {
            split_index = i;
            break;
        }
    }

    if split_index == 0 {
        eprintln!("Failed to parse mdbook input.");
        std::process::exit(1);
    }

    let book = &modified[split_index + 1..modified.len() - 1]; // Skip comma and last bracket
    print!("{book}");
}
