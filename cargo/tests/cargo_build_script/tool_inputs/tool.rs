use runfiles::{rlocation, Runfiles};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runfiles = Runfiles::create()?;
    let path = rlocation!(
        runfiles,
        "rules_rust/cargo/tests/cargo_build_script/tool_inputs/fixture_tool.runtime"
    )
    .ok_or("the fixture runtime is declared in data")?;
    print!("{}", std::fs::read_to_string(path)?);
    Ok(())
}
