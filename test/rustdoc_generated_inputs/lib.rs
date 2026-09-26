//! The wrapper must find generated environment files after moving into runfiles.
//!
//! Unlike the runtime libraries covered by #4220, this file has no crate or
//! C++ dependency provider from which the legacy launcher could infer its root.
//!
//! ```
//! assert_eq!(env!("GENERATED_VALUE"), "from the execution configuration");
//! ```

#![warn(rust_2018_idioms)]
