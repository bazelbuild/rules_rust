extern "C" int cc_double_value(int value);
extern "C" int rust_double_value(int value);

// `wasm32-unknown-unknown` is very barebones, so we have to define `_start()`
// and we don't have access to `stdio.h` or `iostream`, so we can't output
// anything, but we can still call the functions.
extern "C" void _start() {
    cc_double_value(5);
    rust_double_value(5);
}
