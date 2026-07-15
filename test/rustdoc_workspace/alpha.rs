//! The `alpha` crate, the bottom of the test dependency graph.

/// A greeting produced by [`greeting`].
pub struct Greeting {
    /// The rendered greeting text.
    pub text: String,
}

/// Returns a [`Greeting`] for the given name.
pub fn greeting(name: &str) -> Greeting {
    Greeting {
        text: format!("Hello {}!", name),
    }
}
