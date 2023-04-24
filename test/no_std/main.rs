#![no_std]
#![no_main]
#![feature(lang_items)]

use core::arch::asm;
use core::arch::global_asm;
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    exit(1);
}

global_asm! {
    ".global _start",
    "_start:",
    "mov rdi, rsp",
    "call start_main"
}

fn exit(status: i32) -> ! {
    unsafe {
        asm!(
            "syscall",
            in("rax") 60,
            in("rdi") status,
            options(noreturn)
        );
    }
}

fn write(fd: i32, buf: &[u8]) -> isize {
    let r0;
    unsafe {
        asm!(
            "syscall",
            inlateout("rax") 1isize => r0,
            in("rdi") fd,
            in("rsi") buf.as_ptr(),
            in("rdx") buf.len(),
            lateout("rcx") _,
            lateout("r11") _,
            options(nostack, preserves_flags)
        );
    }
    r0
}

#[no_mangle]
unsafe fn start_main(_stack_top: *const u8) -> ! {
    write(1, "Hello, world\n".as_bytes());
    exit(0);
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}
