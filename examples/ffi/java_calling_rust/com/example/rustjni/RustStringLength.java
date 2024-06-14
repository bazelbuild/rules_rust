package com.example.rustjni;

import com.google.devtools.build.runfiles.AutoBazelRepository;
import com.google.devtools.build.runfiles.Runfiles;

import com.sun.jna.Library;
import com.sun.jna.Native;

import java.io.IOException;

@AutoBazelRepository
public interface RustStringLength extends Library {
    long calculate_string_length_from_rust(String s);

    static RustStringLength loadNativeLibrary() throws IOException {
        String prefix = "lib";
        String extension = "so";
        if ("Mac OS X".equals(System.getProperty("os.name"))) {
            extension = "dylib";
        } else if (System.getProperty("os.name").contains("Windows")) {
            prefix = "";
            extension = "dll";
        }
        Runfiles.Preloaded runfiles = Runfiles.preload();
        String dylibPath = runfiles.withSourceRepository(AutoBazelRepository_RustStringLength.NAME).rlocation("examples/ffi/java_calling_rust/rust-crate/" + prefix + "rstrlen." + extension);

        return Native.load(dylibPath, RustStringLength.class);
    }
}
