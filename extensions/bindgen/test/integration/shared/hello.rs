mod greeting_bindgen;

pub fn hello() {
    let greeting = greeting_bindgen::GREETING.to_str().unwrap();
    println!("{greeting} from Rust!");
}
