//! The `beta` crate, which builds on [`alpha`].

/// Produces an enthusiastic [`alpha::Greeting`].
pub fn loud_greeting(name: &str) -> alpha::Greeting {
    let greeting = alpha::greeting(name);
    alpha::Greeting {
        text: greeting.text.to_uppercase(),
    }
}
