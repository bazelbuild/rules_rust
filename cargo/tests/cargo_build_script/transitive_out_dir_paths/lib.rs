//! Compiles only if `TRANSITIVE_PRODUCER_INCLUDE` resolves to the producer's
//! `OUT_DIR/include` inside this action's sandbox.

pub const PRODUCER: &str = include_str!(concat!(
    env!("TRANSITIVE_PRODUCER_INCLUDE"),
    "/producer.txt"
));
