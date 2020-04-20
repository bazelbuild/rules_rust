extern crate common_lib;
extern crate common_proto_rust;

pub fn main() {
    common_lib::do_something(&common_proto_rust::Config::new());
}
