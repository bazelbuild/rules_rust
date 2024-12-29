use std::ffi::CStr;
use std::os::raw::c_char;

/// Calculates the length of a string.
///
/// # Safety
///
/// The argument must null-terminated.
#[no_mangle]
pub unsafe extern "C" fn calculate_string_length_from_rust(s: *const c_char) -> i64 {
    let slice = unsafe { CStr::from_ptr(s).to_bytes() };
    std::str::from_utf8(slice).map_or(-1, |s| {
        let l = s.len();
        l.try_into().unwrap_or(-1)
    })
}
