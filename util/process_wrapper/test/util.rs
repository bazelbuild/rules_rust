use super::*;

#[test]
fn test_read_to_array() {
    let input = r"some escaped \\\
string
with other lines"
        .to_owned();
    let expected = vec![
        r"some escaped \
string",
        "with other lines",
    ];
    let got = read_to_array(input.as_bytes()).unwrap();
    assert_eq!(expected, got);
}

#[test]
fn test_stamp_status_to_array() {
    let lines = "aaa bbb\\\nvvv\nccc ddd\neee fff";
    let got = stamp_status_to_array(lines.as_bytes()).unwrap();
    let expected = vec![
        ("aaa".to_owned(), "bbb\nvvv".to_owned()),
        ("ccc".to_owned(), "ddd".to_owned()),
        ("eee".to_owned(), "fff".to_owned()),
    ];
    assert_eq!(expected, got);
}
