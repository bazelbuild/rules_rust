use tower::util::Either;

#[test]
fn uses_tower_util() {
    let value: Either<String, ()> = Either::A("Hello".to_owned());
    assert!(matches!(value, Either::<String, ()>::A(x) if x == "Hello"));
}
