// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::error;
use std::fmt;
use std::io::{self, prelude::*};

/// Output action for one processed line.
#[derive(Debug)]
pub(crate) enum LineOutput {
    Message(String),
    Skip,
}

#[derive(Debug)]
pub(crate) enum ProcessError {
    IO(io::Error),
    Process(String),
}

impl fmt::Display for ProcessError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::IO(e) => write!(f, "{}", e),
            Self::Process(p) => write!(f, "{}", p),
        }
    }
}

impl error::Error for ProcessError {}

impl From<io::Error> for ProcessError {
    fn from(err: io::Error) -> Self {
        Self::IO(err)
    }
}

impl From<String> for ProcessError {
    fn from(s: String) -> Self {
        Self::Process(s)
    }
}

pub(crate) type ProcessResult = Result<(), ProcessError>;

/// Per-line processing result.
pub(crate) type LineResult = Result<LineOutput, String>;

/// Reads lines from `read_end` and forwards processed output to `output_write_end`.
pub(crate) fn process_output<F>(
    read_end: &mut dyn Read,
    output_write_end: &mut dyn Write,
    opt_file_write_end: Option<&mut std::fs::File>,
    mut process_line: F,
) -> ProcessResult
where
    F: FnMut(String) -> LineResult,
{
    let mut reader = io::BufReader::new(read_end);
    let mut output_writer = io::LineWriter::new(output_write_end);
    let mut file_writer = opt_file_write_end.map(io::LineWriter::new);
    // Preserve the first failing line and its error.
    let mut failed_on: Option<(String, String)> = None;
    loop {
        let mut line = String::new();
        let read_bytes = reader.read_line(&mut line)?;
        if read_bytes == 0 {
            break;
        }
        if let Some(ref mut file) = file_writer {
            file.write_all(line.as_bytes())?
        }
        match process_line(line.clone()) {
            Ok(LineOutput::Message(to_write)) => output_writer.write_all(to_write.as_bytes())?,
            Ok(LineOutput::Skip) => {}
            Err(msg) => {
                failed_on = Some((line, msg));
                break;
            }
        };
    }

    // Flush the rest of the stream unchanged after the first processing error.
    if let Some((line, msg)) = failed_on {
        output_writer.write_all(line.as_bytes())?;
        io::copy(&mut reader, &mut output_writer)?;
        return Err(ProcessError::Process(msg));
    }
    Ok(())
}

#[cfg(test)]
#[path = "test/output.rs"]
mod test;
