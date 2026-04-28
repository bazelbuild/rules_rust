use rand::{thread_rng, Rng};

/// Generate a random number
pub fn random_number() -> i32 {
    let mut rng = thread_rng();
    rng.gen()
}
