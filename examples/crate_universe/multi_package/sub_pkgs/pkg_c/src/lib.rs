use md5::{Digest, Md5};

pub fn hash(bytes: impl AsRef<[u8]>) -> Vec<u8> {
    // create a Md5 hasher instance
    let mut hasher = Md5::new();

    // process input message
    hasher.update(bytes);

    // acquire hash digest in the form of GenericArray,
    // which in this case is equivalent to [u8; 16]
    let result = hasher.finalize();
    result[..].into()
}

#[cfg(test)]
mod test {
    use super::*;

    use hex_literal::hex;

    #[test]
    fn test_hash() {
        assert_eq!(
            hash(b"hello world")[..],
            hex!("5eb63bbbe01eeed093cb22bb8f5acdc3")
        )
    }
}
