use super::*;

#[test]
fn test_json_parsing_error() {
    let mut input = io::Cursor::new(b"ok text\nsome more\nerror text");
    let mut output: Vec<u8> = vec![];
    let result = process_output(&mut input, &mut output, None, move |line| {
        if line == "ok text\n" {
            Ok(LineOutput::Skip)
        } else {
            Err("error parsing output".to_owned())
        }
    });
    assert!(result.is_err());
    assert_eq!(&output, b"some more\nerror text");
}
