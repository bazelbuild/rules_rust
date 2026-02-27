use lttng_ust::import_tracepoints;

import_tracepoints!(concat!(env!("OUT_DIR"), "/tracepoints.rs"), tracepoints);

fn main() {
    tracepoints::my_first_rust_provider::my_first_tracepoint(42, "the meaning of life");
}
