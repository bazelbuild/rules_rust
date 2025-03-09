fn main() {
    println!("\"random\" number: {}", rand::random::<f32>());
}

#[cfg(test)]
mod tests {
    #[test]
    fn not_actually_random() {
        assert_eq!(rand::random::<u32>(), 34253218);
    }
}
