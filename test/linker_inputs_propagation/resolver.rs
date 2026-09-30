use std::ffi::c_void;

extern "C" {
    fn ns_initparse(message: *const u8, message_length: i32, handle: *mut c_void) -> i32;
}

#[no_mangle]
pub extern "C" fn resolver_symbol() -> *const c_void {
    ns_initparse as *const c_void
}
