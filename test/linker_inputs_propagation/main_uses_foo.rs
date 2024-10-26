extern "C" {
    fn double_foo() -> i32;
}

fn main() {
  println!("{}", unsafe { double_foo() });
}
