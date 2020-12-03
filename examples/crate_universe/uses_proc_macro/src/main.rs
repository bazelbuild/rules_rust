use structopt::StructOpt;

#[derive(StructOpt)]
struct Opt {
    #[structopt(long)]
    name: String
}

fn main() {
    let opt = Opt::from_args();
    println!("Greetings, {}", opt.name);
}
