# Prost-Build

The prost-build library is generally geared towards using build.rs files as a
means for generating both itself, and then the generated protobuf files.  This
makes it very cargo-centric.  For example, with the lib.rs file, it expects a
[path to the protoc compiler to be provided by PROTOC](https://github.com/danburkert/prost/blob/master/prost-build/src/lib.rs#L684)
which hard-codes the path of protoc into the library.  This makes it so we
currently cannot build prost-build without patching the code.  This now patches
the code in a simlar manner to
[danburket/prost#307](https://github.com/danburkert/prost/pull/307) which will
be in an eventual next release of prost.
