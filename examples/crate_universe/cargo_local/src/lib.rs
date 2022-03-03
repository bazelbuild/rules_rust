use std::path::Path;

use tokio::fs::File;
use tokio::io::{AsyncBufReadExt, BufReader};

pub async fn fill_buf_file(path: &Path) -> Vec<u8> {
    let file = File::open(path).await.unwrap();
    let mut file = BufReader::new(file);

    let mut contents = Vec::new();

    loop {
        let consumed = {
            let buffer = file.fill_buf().await.unwrap();
            if buffer.is_empty() {
                break;
            }
            contents.extend_from_slice(buffer);
            buffer.len()
        };

        file.consume(consumed);
    }

    contents
}

#[cfg(test)]
mod test {
    use super::*;

    use tempfile::NamedTempFile;
    use tokio_test::assert_ok;

    #[tokio::test]
    async fn test_fill_buf_file() {
        let file = NamedTempFile::new().unwrap();
        assert_ok!(std::fs::write(file.path(), b"hello"));

        let contents = fill_buf_file(file.path()).await;

        assert_eq!(contents, b"hello");
    }
}
