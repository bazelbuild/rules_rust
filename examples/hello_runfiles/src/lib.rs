use std::io;
use std::path::PathBuf;

/// Returns the .runfiles directory for the currently executing binary.
pub fn get_runfiles_dir() -> io::Result<PathBuf> {
    let mut path = std::env::current_exe()?;

    if cfg!(target_os = "macos") {
      path.pop();
    } else {
      let mut name = path.file_name().unwrap().to_owned();
      name.push(".runfiles");
      path.pop();
      path.push(name);
    }

    Ok(path)
}


#[cfg(test)]
mod test {
    use super::*;

    use std::io;
    use std::io::prelude::*;
    use std::fs::File;

    #[test]
    fn test_can_read_data_from_runfiles() {
        let runfiles = get_runfiles_dir().unwrap();

        let mut f = if cfg!(target_os = "macos") {
          File::open(runfiles.join("data/sample.txt")).unwrap()
        } else {
          File::open(runfiles.join("examples/hello_runfiles/data/sample.txt")).unwrap()
        };
        let mut buffer = String::new();

        f.read_to_string(&mut buffer).unwrap();

        assert_eq!("Example Text!", buffer);
    }
}
