fn main() {
    let mut bytes = [0; 1];
    getrandom::getrandom(&mut bytes).unwrap();
    println!("\"random\" number: {}", rand::random::<f32>());
}

#[cfg(test)]
mod tests {
    #[test]
    fn not_actually_random() {
        assert_eq!(rand::random::<u32>(), 34253218);
    }
}
