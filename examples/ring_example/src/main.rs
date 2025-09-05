use ring::{digest, rand};
use ring::rand::SecureRandom;

fn main() {
    println!("Testing ring crate functionality...");
    
    // Test SHA-256 hashing
    let data = b"Hello, Bazel with ring!";
    let actual_hash = digest::digest(&digest::SHA256, data);
    let hash_hex = actual_hash.as_ref()
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect::<String>();
    
    println!("SHA-256 hash of '{:?}': {}", 
        std::str::from_utf8(data).unwrap(), 
        hash_hex
    );
    
    // Test random number generation
    let rng = rand::SystemRandom::new();
    let mut random_bytes = [0u8; 32];
    rng.fill(&mut random_bytes).unwrap();
    
    let random_hex = random_bytes
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect::<String>();
    
    println!("32 random bytes: {}", random_hex);
    
    println!("Ring crate is working correctly!");
} 
