#[cfg(feature = "force_stamp")]
use force_stamp::build_timestamp;

#[cfg(feature = "skip_stamp")]
use skip_stamp::build_timestamp;

#[cfg(feature = "with_stamp_build_flag")]
use with_stamp_build_flag_lib::build_timestamp;

#[cfg(feature = "without_stamp_build_flag")]
use without_stamp_build_flag_lib::build_timestamp;

fn main() {
    println!("bin stamp: {}", env!("BUILD_TIMESTAMP"));
    println!("lib stamp: {}", build_timestamp());
}
