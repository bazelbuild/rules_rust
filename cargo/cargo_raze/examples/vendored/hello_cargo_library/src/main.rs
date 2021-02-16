#[macro_use]
extern crate log;
extern crate fern;

pub fn main() {
  let logger_config = fern::DispatchConfig {
    format: Box::new(|msg: &str, level: &log::LogLevel, _location: &log::LogLocation| {
      format!("[{}]{}", level, msg)
    }),
    output: vec![fern::OutputConfig::stdout(), fern::OutputConfig::file("output.log")],
    level: log::LogLevelFilter::Trace,
  };
  if let Err(e) = fern::init_global_logger(logger_config, log::LogLevelFilter::Trace) {
    panic!("Failed to initialize global logger: {}", e);
  }

  trace!("Hello world");
  warn!("Hello world!");
}
