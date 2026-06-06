#[cfg(not(expected_use_libtool_on_macos))]
compile_error!("use_libtool_on_macos was not restored before compiling the build script dependency");
