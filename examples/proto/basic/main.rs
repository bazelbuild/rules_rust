import::import! {
    "//proto/basic:common_lib";
    "//proto/basic:common_proto_rust";
}

pub fn main() {
    common_lib::do_something(&common_proto_rust::Config::new());
}
