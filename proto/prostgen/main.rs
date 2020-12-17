use structopt::StructOpt;

fn main() -> anyhow::Result<()> {
    let prostgen = prostgen_lib::ProstGen::from_args();

    prostgen.run()
}
