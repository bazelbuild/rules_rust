use a_prost::prostgen::test::A;
use b_prost::prostgen::test::B;
use x_prost::prostgen::test::X;
use y_prost::prostgen::test::Y;

#[cfg(test)]
#[test]
fn structs_are_usable() {
    let x = X {
        a: Some(A { value: 1 }),
        b: Some(B { value: 2 }),
    };
    let y = Y {
        a: Some(A { value: 1 }),
        b: Some(B { value: 2 }),
    };

    assert_eq!(x.a, y.a);
    assert_eq!(x.b, y.b);
}
