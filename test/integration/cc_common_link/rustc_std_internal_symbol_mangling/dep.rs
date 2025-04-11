#[no_mangle]
pub extern "C" fn rdep() -> i32 {
    // Just some logic complicated enough to require heap
    // allocations.
    use std::convert::TryInto;
    let mut v = vec![1, 2, 3];
    while v.len() < 1000 {
        let n = v.len();
        v.push(v[n-1] + v[n-2]);
        v.push(v[n-3]);
    }
    return v.len().try_into().unwrap();  // returns 1001
}
