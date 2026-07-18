//! A tool to generate `.dep-v0` object files for cargo-auditable compatible
//! dependency tracking in Bazel-built Rust binaries.
//!
//! This tool reads a JSON dependency manifest, zlib-compresses it, and wraps
//! it in a platform-appropriate object file with a `.dep-v0` section and an
//! `AUDITABLE_VERSION_INFO` symbol.

use miniz_oxide::deflate::compress_to_vec_zlib;
use object::write::{self, StandardSegment, Symbol, SymbolSection};
use object::{
    elf, Architecture, BinaryFormat, Endianness, FileFlags, SectionFlags, SectionKind, SymbolFlags,
    SymbolKind, SymbolScope,
};
use std::fs;
use std::process;

const SYMBOL_NAME: &str = "AUDITABLE_VERSION_INFO";

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("Usage: {} <target-triple> <input.json> <output.o>", args[0]);
        process::exit(1);
    }

    let target_triple = &args[1];
    let input_path = &args[2];
    let output_path = &args[3];

    let json = fs::read(input_path).unwrap_or_else(|e| {
        eprintln!("Failed to read input file '{}': {}", input_path, e);
        process::exit(1);
    });

    let compressed = compress_to_vec_zlib(&json, 7);

    let obj_bytes = if is_wasm(target_triple) {
        create_wasm_file(&compressed)
    } else {
        match create_object_file(target_triple, &compressed) {
            Some(bytes) => bytes,
            None => {
                eprintln!("Unsupported target triple: {}", target_triple);
                process::exit(1);
            }
        }
    };

    fs::write(output_path, obj_bytes).unwrap_or_else(|e| {
        eprintln!("Failed to write output file '{}': {}", output_path, e);
        process::exit(1);
    });
}

fn is_wasm(target_triple: &str) -> bool {
    target_triple.starts_with("wasm32") || target_triple.starts_with("wasm64")
}

fn is_apple(target_triple: &str) -> bool {
    target_triple.contains("apple") || target_triple.contains("darwin")
}

fn is_windows(target_triple: &str) -> bool {
    target_triple.contains("windows")
}

fn is_32bit(target_triple: &str) -> bool {
    let arch = target_triple.split('-').next().unwrap_or("");
    matches!(
        arch,
        "i686" | "i586" | "armv7" | "arm" | "riscv32" | "wasm32" | "x86_64_x32"
    ) || (arch == "aarch64" && target_triple.contains("ilp32"))
}

fn create_wasm_file(contents: &[u8]) -> Vec<u8> {
    let mut result: Vec<u8> = vec![0, b'a', b's', b'm', 1, 0, 0, 0];
    write_wasm_custom_section(&mut result, "linking", &[2]);
    write_wasm_custom_section(&mut result, ".dep-v0", contents);
    result
}

fn write_wasm_custom_section(out: &mut Vec<u8>, name: &str, payload: &[u8]) {
    let section_len = leb128_len(name.len()) + name.len() + payload.len();
    out.push(0); // custom section id
    write_leb128(out, section_len);
    write_leb128(out, name.len());
    out.extend_from_slice(name.as_bytes());
    out.extend_from_slice(payload);
}

fn write_leb128(out: &mut Vec<u8>, mut value: usize) {
    loop {
        let mut byte = (value & 0x7f) as u8;
        value >>= 7;
        if value != 0 {
            byte |= 0x80;
        }
        out.push(byte);
        if value == 0 {
            break;
        }
    }
}

fn leb128_len(mut value: usize) -> usize {
    let mut len = 0;
    loop {
        value >>= 7;
        len += 1;
        if value == 0 {
            break;
        }
    }
    len
}

/// Adapted from cargo-auditable's object_file.rs, which is itself adapted from
/// the rustc codebase.
fn create_object_file(target_triple: &str, contents: &[u8]) -> Option<Vec<u8>> {
    let parts: Vec<&str> = target_triple.split('-').collect();
    let arch_str = parts.first().copied().unwrap_or("");

    let endianness = if (arch_str.contains("mips") && !arch_str.ends_with("el"))
        || arch_str == "s390x"
        || arch_str == "powerpc"
        || arch_str == "powerpc64"
    {
        Endianness::Big
    } else {
        Endianness::Little
    };

    let architecture = match arch_str {
        "arm" | "armv7" | "armv7s" | "thumbv7neon" => Architecture::Arm,
        "aarch64" => {
            if is_32bit(target_triple) {
                Architecture::Aarch64_Ilp32
            } else {
                Architecture::Aarch64
            }
        }
        "i686" | "i586" => Architecture::I386,
        "s390x" => Architecture::S390x,
        "mips" | "mipsel" => Architecture::Mips,
        "mips64" | "mips64el" => Architecture::Mips64,
        "x86_64" => {
            if is_32bit(target_triple) {
                Architecture::X86_64_X32
            } else {
                Architecture::X86_64
            }
        }
        "powerpc" => Architecture::PowerPc,
        "powerpc64" | "powerpc64le" => Architecture::PowerPc64,
        "riscv32" => Architecture::Riscv32,
        "riscv64" | "riscv64gc" => Architecture::Riscv64,
        "sparc64" => Architecture::Sparc64,
        "loongarch64" => Architecture::LoongArch64,
        _ => return None,
    };

    let binary_format = if is_apple(target_triple) {
        BinaryFormat::MachO
    } else if is_windows(target_triple) {
        BinaryFormat::Coff
    } else {
        BinaryFormat::Elf
    };

    let mut file = write::Object::new(binary_format, architecture, endianness);

    let mut e_flags: u32 = 0;
    match architecture {
        Architecture::Mips => {
            let arch = if target_triple.contains("r6") {
                elf::EF_MIPS_ARCH_32R6
            } else {
                elf::EF_MIPS_ARCH_32R2
            };
            e_flags = elf::EF_MIPS_CPIC | elf::EF_MIPS_ABI_O32 | arch;
            if target_triple.contains("r6") {
                e_flags |= elf::EF_MIPS_NAN2008;
            }
        }
        Architecture::Mips64 => {
            e_flags = elf::EF_MIPS_CPIC
                | elf::EF_MIPS_PIC
                | if target_triple.contains("r6") {
                    elf::EF_MIPS_ARCH_64R6 | elf::EF_MIPS_NAN2008
                } else {
                    elf::EF_MIPS_ARCH_64R2
                };
        }
        Architecture::Riscv32 | Architecture::Riscv64 => {
            let features = riscv_features_from_triple(target_triple);
            if features.contains('c') {
                e_flags |= elf::EF_RISCV_RVC;
            }
            if features.contains('d') {
                e_flags |= elf::EF_RISCV_FLOAT_ABI_DOUBLE;
            } else if features.contains('f') {
                e_flags |= elf::EF_RISCV_FLOAT_ABI_SINGLE;
            } else {
                e_flags |= elf::EF_RISCV_FLOAT_ABI_SOFT;
            }
        }
        Architecture::LoongArch64 => {
            e_flags = elf::EF_LARCH_OBJABI_V1;
            if target_triple.contains("softfloat") {
                e_flags |= elf::EF_LARCH_ABI_SOFT_FLOAT;
            } else {
                e_flags |= elf::EF_LARCH_ABI_DOUBLE_FLOAT;
            }
        }
        _ => {}
    }

    let os_abi = if target_triple.contains("freebsd") {
        elf::ELFOSABI_FREEBSD
    } else if target_triple.contains("solaris") {
        elf::ELFOSABI_SOLARIS
    } else if target_triple.contains("hermit") {
        elf::ELFOSABI_STANDALONE
    } else {
        elf::ELFOSABI_NONE
    };

    file.flags = FileFlags::Elf {
        os_abi,
        abi_version: 0,
        e_flags,
    };

    if binary_format == BinaryFormat::Coff {
        let original_mangling = file.mangling();
        file.set_mangling(write::Mangling::None);
        let mut feature: u64 = 0;
        if architecture == Architecture::I386 {
            feature |= 1; // IMAGE_FILE_SAFE_EXCEPTION_HANDLER
        }
        file.add_symbol(Symbol {
            name: b"@feat.00".to_vec(),
            value: feature,
            size: 0,
            kind: SymbolKind::Data,
            scope: SymbolScope::Compilation,
            weak: false,
            section: SymbolSection::Absolute,
            flags: SymbolFlags::None,
        });
        file.set_mangling(original_mangling);
    }

    let section = file.add_section(
        file.segment_name(StandardSegment::Data).to_vec(),
        b".dep-v0".to_vec(),
        SectionKind::ReadOnlyData,
    );
    if let BinaryFormat::Elf = file.format() {
        file.section_mut(section).flags = SectionFlags::Elf { sh_flags: 0 };
    }
    let offset = file.append_section_data(section, contents, 1);

    file.add_symbol(Symbol {
        name: SYMBOL_NAME.as_bytes().to_vec(),
        value: offset,
        size: contents.len() as u64,
        kind: SymbolKind::Data,
        scope: SymbolScope::Dynamic,
        weak: false,
        section: SymbolSection::Section(section),
        flags: SymbolFlags::None,
    });

    Some(file.write().unwrap())
}

fn riscv_features_from_triple(target_triple: &str) -> String {
    let arch = target_triple.split('-').next().unwrap_or("");
    let prefix_len = if arch.starts_with("riscv32") || arch.starts_with("riscv64") {
        7
    } else {
        return String::new();
    };
    let mut extensions = arch[prefix_len..].to_owned();
    if extensions.contains('g') {
        extensions.push_str("imadf");
    }
    if target_triple.contains("linux") || target_triple.contains("android") {
        extensions.push_str("imadfc");
    }
    extensions
}

#[cfg(test)]
mod tests {
    use super::*;
    use miniz_oxide::inflate::decompress_to_vec_zlib;
    use object::read::Object;
    use object::{ObjectSection, ObjectSymbol};

    /// Round-trip: compress JSON, generate ELF object, then read it back and
    /// verify the `.dep-v0` section contains the original JSON.
    fn roundtrip_elf(target_triple: &str) {
        let json = br#"{"packages":[{"name":"foo","version":"1.0.0"}],"format":0}"#;
        let compressed = compress_to_vec_zlib(json, 7);
        let obj_bytes = create_object_file(target_triple, &compressed)
            .unwrap_or_else(|| panic!("unsupported triple: {}", target_triple));

        let file = object::File::parse(&*obj_bytes)
            .unwrap_or_else(|e| panic!("failed to parse object for {}: {}", target_triple, e));

        let section = file
            .section_by_name(".dep-v0")
            .unwrap_or_else(|| panic!(".dep-v0 section not found for {}", target_triple));
        let data = section.data().expect("could not read section data");
        assert!(!data.is_empty(), "section is empty for {}", target_triple);

        let decompressed = decompress_to_vec_zlib(data)
            .unwrap_or_else(|e| panic!("decompression failed for {}: {:?}", target_triple, e));
        assert_eq!(
            decompressed, json,
            "round-trip mismatch for {}",
            target_triple
        );

        // Verify the symbol exists
        let sym = file
            .symbols()
            .find(|s| s.name() == Ok(SYMBOL_NAME))
            .unwrap_or_else(|| panic!("{} symbol not found for {}", SYMBOL_NAME, target_triple));
        assert_eq!(sym.size() as usize, compressed.len());
    }

    #[test]
    fn test_elf_x86_64_linux() {
        roundtrip_elf("x86_64-unknown-linux-gnu");
    }

    #[test]
    fn test_elf_aarch64_linux() {
        roundtrip_elf("aarch64-unknown-linux-gnu");
    }

    #[test]
    fn test_elf_i686_linux() {
        roundtrip_elf("i686-unknown-linux-gnu");
    }

    #[test]
    fn test_elf_arm_linux() {
        roundtrip_elf("armv7-unknown-linux-gnueabi");
    }

    #[test]
    fn test_elf_riscv64_linux() {
        roundtrip_elf("riscv64gc-unknown-linux-gnu");
    }

    #[test]
    fn test_elf_s390x_linux() {
        roundtrip_elf("s390x-unknown-linux-gnu");
    }

    /// Round-trip for formats where the symbol table may differ (Mach-O, COFF).
    /// Verifies the section and its decompressed contents, but not symbol details.
    fn roundtrip_section_only(target_triple: &str) {
        let json = br#"{"packages":[{"name":"foo","version":"1.0.0"}],"format":0}"#;
        let compressed = compress_to_vec_zlib(json, 7);
        let obj_bytes = create_object_file(target_triple, &compressed)
            .unwrap_or_else(|| panic!("unsupported triple: {}", target_triple));

        let file = object::File::parse(&*obj_bytes)
            .unwrap_or_else(|e| panic!("failed to parse object for {}: {}", target_triple, e));

        let section = file
            .section_by_name(".dep-v0")
            .unwrap_or_else(|| panic!(".dep-v0 section not found for {}", target_triple));
        let data = section.data().expect("could not read section data");
        assert!(!data.is_empty(), "section is empty for {}", target_triple);

        let decompressed = decompress_to_vec_zlib(data)
            .unwrap_or_else(|e| panic!("decompression failed for {}: {:?}", target_triple, e));
        assert_eq!(
            decompressed, json,
            "round-trip mismatch for {}",
            target_triple
        );
    }

    #[test]
    fn test_macho_aarch64() {
        roundtrip_section_only("aarch64-apple-darwin");
    }

    #[test]
    fn test_coff_x86_64_windows() {
        roundtrip_section_only("x86_64-pc-windows-msvc");
    }

    #[test]
    fn test_unsupported_triple_returns_none() {
        let compressed = compress_to_vec_zlib(b"test", 7);
        assert!(create_object_file("unknown-unknown-unknown", &compressed).is_none());
    }

    #[test]
    fn test_wasm_roundtrip() {
        let json = br#"{"packages":[],"format":0}"#;
        let compressed = compress_to_vec_zlib(json, 7);
        let wasm = create_wasm_file(&compressed);

        // WASM magic: \0asm\1\0\0\0
        assert_eq!(&wasm[..8], &[0, b'a', b's', b'm', 1, 0, 0, 0]);
        // Find .dep-v0 custom section by scanning for the name
        let pos = wasm
            .windows(7)
            .position(|w| w == b".dep-v0")
            .expect(".dep-v0 not found in WASM output");
        let payload_start = pos + 7;
        let payload = &wasm[payload_start..payload_start + compressed.len()];
        let decompressed = decompress_to_vec_zlib(payload).expect("decompression failed for WASM");
        assert_eq!(decompressed, json);
    }

    #[test]
    fn test_is_wasm() {
        assert!(is_wasm("wasm32-unknown-unknown"));
        assert!(is_wasm("wasm64-unknown-unknown"));
        assert!(!is_wasm("x86_64-unknown-linux-gnu"));
    }

    #[test]
    fn test_is_apple() {
        assert!(is_apple("aarch64-apple-darwin"));
        assert!(is_apple("x86_64-apple-darwin"));
        assert!(!is_apple("x86_64-unknown-linux-gnu"));
    }

    #[test]
    fn test_is_windows() {
        assert!(is_windows("x86_64-pc-windows-msvc"));
        assert!(!is_windows("x86_64-unknown-linux-gnu"));
    }

    #[test]
    fn test_is_32bit() {
        assert!(is_32bit("i686-unknown-linux-gnu"));
        assert!(is_32bit("armv7-unknown-linux-gnueabi"));
        assert!(is_32bit("riscv32-unknown-none-elf"));
        assert!(!is_32bit("x86_64-unknown-linux-gnu"));
        assert!(!is_32bit("aarch64-unknown-linux-gnu"));
    }

    #[test]
    fn test_riscv_features() {
        assert!(riscv_features_from_triple("riscv64gc-unknown-linux-gnu").contains('c'));
        assert!(riscv_features_from_triple("riscv64gc-unknown-linux-gnu").contains('d'));
        assert_eq!(riscv_features_from_triple("x86_64-unknown-linux-gnu"), "");
    }

    #[test]
    fn test_leb128_roundtrip() {
        for &val in &[0, 1, 127, 128, 255, 16384, 65535] {
            let mut buf = Vec::new();
            write_leb128(&mut buf, val);
            assert_eq!(
                leb128_len(val),
                buf.len(),
                "leb128_len mismatch for {}",
                val
            );
        }
    }
}
