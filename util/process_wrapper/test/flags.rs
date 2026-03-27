use super::*;

fn args(args: &[&str]) -> Vec<String> {
    ["foo"].iter().chain(args).map(|&s| s.to_owned()).collect()
}

#[test]
fn test_flag_help() {
    let mut bar = None;
    let mut parser = Flags::new();
    parser.define_flag("--bar", "bar help", &mut bar);
    let result = parser.parse(args(&["--help"])).unwrap();
    if let ParseOutcome::Help(h) = result {
        assert!(h.contains("Help for foo"));
        assert!(h.contains("--bar\tbar help"));
    } else {
        panic!("expected that --help would invoke help, instead parsed arguments")
    }
}

#[test]
fn test_flag_single_repeated() {
    let mut bar = None;
    let mut parser = Flags::new();
    parser.define_flag("--bar", "bar help", &mut bar);
    let result = parser.parse(args(&["--bar", "aa", "bb"]));
    if let Err(FlagParseError::ProvidedMultipleTimes(f)) = result {
        assert_eq!(f, "--bar");
    } else {
        panic!("expected error, got {:?}", result)
    }
    let mut parser = Flags::new();
    parser.define_flag("--bar", "bar help", &mut bar);
    let result = parser.parse(args(&["--bar", "aa", "--bar", "bb"]));
    if let Err(FlagParseError::ProvidedMultipleTimes(f)) = result {
        assert_eq!(f, "--bar");
    } else {
        panic!("expected error, got {:?}", result)
    }
}

#[test]
fn test_repeated_flags() {
    // Test case 1) --bar something something_else should work as a repeated flag.
    let mut bar = None;
    let mut parser = Flags::new();
    parser.define_repeated_flag("--bar", "bar help", &mut bar);
    let result = parser.parse(args(&["--bar", "aa", "bb"])).unwrap();
    assert!(matches!(result, ParseOutcome::Parsed(_)));
    assert_eq!(bar, Some(vec!["aa".to_owned(), "bb".to_owned()]));
    // Test case 2) --bar something --bar something_else should also work as a repeated flag.
    bar = None;
    let mut parser = Flags::new();
    parser.define_repeated_flag("--bar", "bar help", &mut bar);
    let result = parser.parse(args(&["--bar", "aa", "--bar", "bb"])).unwrap();
    assert!(matches!(result, ParseOutcome::Parsed(_)));
    assert_eq!(bar, Some(vec!["aa".to_owned(), "bb".to_owned()]));
}

#[test]
fn test_extra_args() {
    let parser = Flags::new();
    let result = parser.parse(args(&["--", "bb"])).unwrap();
    if let ParseOutcome::Parsed(got) = result {
        assert_eq!(got, vec!["bb".to_owned()])
    } else {
        panic!("expected correct parsing, got {:?}", result)
    }
}
