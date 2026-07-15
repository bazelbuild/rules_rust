//! The root binary of the test diamond dependency graph.

fn main() {
    println!("{}", wd_mid_alpha::double() + wd_mid_beta::triple());
}
