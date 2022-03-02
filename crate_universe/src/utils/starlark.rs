//! A module for representations of starlark constructs

mod glob;
mod label;
mod select;

pub use glob::*;
pub use label::*;
pub use select::*;

pub type SelectStringList = SelectList<String>;
pub type SelectStringDict = SelectDict<String>;
