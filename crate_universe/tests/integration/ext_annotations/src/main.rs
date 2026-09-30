#[cxx::bridge(namespace = "org::blobstore")]
mod ffi {
    // Shared structs with fields visible to both languages.
    struct BlobMetadata {
        size: usize,
        tags: Vec<String>,
    }

    // Rust types and signatures exposed to C++.
    extern "Rust" {
        type MultiBuf;

        fn next_chunk(buf: &mut MultiBuf) -> &[u8];
    }

    // C++ types and signatures exposed to Rust.
    unsafe extern "C++" {
        include!("include/blobstore.h");

        type BlobstoreClient;

        fn new_blobstore_client() -> UniquePtr<BlobstoreClient>;
        fn put(&self, parts: &mut MultiBuf) -> u64;
        fn tag(&self, blobid: u64, tag: &str);
        fn metadata(&self, blobid: u64) -> BlobMetadata;
    }
}

// An iterator over contiguous chunks of a discontiguous file object.
//
// Toy implementation uses a Vec<Vec<u8>> but in reality this might be iterating
// over some more complex Rust data structure like a rope, or maybe loading
// chunks lazily from somewhere.
pub struct MultiBuf {
    chunks: Vec<Vec<u8>>,
    pos: usize,
}
pub fn next_chunk(buf: &mut MultiBuf) -> &[u8] {
    let next = buf.chunks.get(buf.pos);
    buf.pos += 1;
    next.map_or(&[], Vec::as_slice)
}

fn main() {
    let client = ffi::new_blobstore_client();

    // Upload a blob.
    let chunks = vec![b"fearless".to_vec(), b"concurrency".to_vec()];
    let mut buf = MultiBuf { chunks, pos: 0 };
    let blobid = client.put(&mut buf);
    println!("blobid = {}", blobid);

    // Add a tag.
    client.tag(blobid, "rust");

    // Read back the tags.
    let metadata = client.metadata(blobid);
    println!("tags = {:?}", metadata.tags);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_next_chunk_iterates_and_terminates() {
        let mut buf = MultiBuf {
            chunks: vec![b"hello".to_vec(), b"world".to_vec()],
            pos: 0,
        };
        assert_eq!(next_chunk(&mut buf), b"hello");
        assert_eq!(next_chunk(&mut buf), b"world");
        assert_eq!(next_chunk(&mut buf), b"" as &[u8]);
    }

    #[test]
    fn test_blobstore_put_and_metadata() {
        let client = ffi::new_blobstore_client();
        let mut buf = MultiBuf {
            chunks: vec![b"some".to_vec(), b"data".to_vec()],
            pos: 0,
        };
        let blobid = client.put(&mut buf);

        let metadata = client.metadata(blobid);
        assert_eq!(metadata.size, 8); // "some" + "data"
        assert!(metadata.tags.is_empty());
    }

    #[test]
    fn test_blobstore_tag() {
        let client = ffi::new_blobstore_client();
        let mut buf = MultiBuf {
            chunks: vec![b"tagged".to_vec()],
            pos: 0,
        };
        let blobid = client.put(&mut buf);

        client.tag(blobid, "alpha");
        client.tag(blobid, "beta");

        let metadata = client.metadata(blobid);
        assert_eq!(metadata.tags.len(), 2);
        assert!(metadata.tags.iter().any(|t| t == "alpha"));
        assert!(metadata.tags.iter().any(|t| t == "beta"));
    }
}
