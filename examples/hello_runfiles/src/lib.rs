use std::io;
use std::path::PathBuf;

/// Returns the .runfiles directory for the currently executing binary.
pub fn get_runfiles_dir() -> io::Result<PathBuf> {
    let mut path = std::env::current_exe()?;
    println!("--current_exe: {:?}", path);

    let mut parent_path = path.clone();
    for idx in 0..2 {
      parent_path.pop();
      for entry in std::fs::read_dir(&parent_path).unwrap() {
        println!("--entry in exe parent {} {:?}", idx, entry);
      }
    }

    path.pop();
    if cfg!(target_os = "macos") {
      path.push("data");
    } else {
      let mut name = path.file_name().unwrap().to_owned();
      name.push(".runfiles");
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
        println!("--supposed runfiles dir: {:?}", runfiles);

        for entry in std::fs::read_dir(&runfiles).unwrap() {
          println!("--entry in 'runfiles' {:?}", entry);
        }

        let mut f = File::open(runfiles.join("examples/hello_runfiles/data/sample.txt")).unwrap();
        let mut buffer = String::new();

        f.read_to_string(&mut buffer).unwrap();

        assert_eq!("Example Text!", buffer);
    }
}
