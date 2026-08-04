use std::{fmt, num::NonZeroU32};

#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub struct Error(NonZeroU32);
impl std::error::Error for Error {}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Error({})", self.0.get())
    }
}

pub fn getrandom(dest: &mut [u8]) -> Result<(), Error> {
    if dest.is_empty() {
        return Ok(());
    }
    let num = env!("RANDOM_NUMBER").parse().unwrap();
    for n in dest {
        *n = num; // chosen by fair dice roll.
                  // guaranteed to be random.
    }
    Ok(())
}
