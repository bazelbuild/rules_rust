use std::alloc::{GlobalAlloc, System, Layout};
use std::sync::atomic::{AtomicUsize, Ordering::SeqCst};

static ALLOCATED: AtomicUsize = AtomicUsize::new(0);

struct MyAllocator;

unsafe impl GlobalAlloc for MyAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ret = System.alloc(layout);
        if !ret.is_null() {
            ALLOCATED.fetch_add(layout.size(), SeqCst);
        }
        ret
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        System.dealloc(ptr, layout);
        ALLOCATED.fetch_sub(layout.size(), SeqCst);
    }
}

#[global_allocator]
static GLOBAL: MyAllocator = MyAllocator;

fn main() {
    println!("allocated bytes before main: {}", ALLOCATED.load(SeqCst));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_global_alloc_was_used() {
        let bytes_start = ALLOCATED.load(SeqCst);

        let _ = Box::new(5);    // 4 bytes
        let _ = Box::new(true); // 1 byte

        let bytes_end = ALLOCATED.load(SeqCst);

        assert_eq!(bytes_end - bytes_start, 5);
    }
}
