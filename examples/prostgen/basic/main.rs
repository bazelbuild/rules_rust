extern crate common_lib;
extern crate common_proto_rust;

pub fn main() {
    let config = common_proto_rust::common::Config {
        verbose: false
    };
    common_lib::do_something(&config);
}
