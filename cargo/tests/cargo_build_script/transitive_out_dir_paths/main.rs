//! Links only if the `rustc-link-search` forwarded from the producer's
//! `OUT_DIR/lib` resolves inside this action's sandbox.

fn main() {
    assert_eq!(transitive_out_dir_paths_lib::PRODUCER, "producer");
}
