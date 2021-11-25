#[cfg(feature = "force_stamp")]
use force_stamp::build_timestamp;

#[cfg(feature = "skip_stamp")]
use skip_stamp::build_timestamp;

fn main() {
    println!("bin stamp: {}", env!("BUILD_TIMESTAMP"));
    println!("lib stamp: {}", build_timestamp());
}
