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

use std::io::{self, prelude::*};

/// LineOutput tells process_output what to do when a line is processed.
/// If a Message is returned, it will be written to write_end, if
/// Skip is returned nothing will be printed and execution continues,
/// if Terminate is returned, process_output returns immediately.
/// Terminate is used to stop processing when we see an emit metadata
/// message.
#[derive(Debug)]
pub(crate) enum LineOutput {
    Message(String),
    Skip,
    Terminate,
}

/// process_output reads lines from read_end and invokes process_line on each.
/// Depending on the result of process_line, the modified message may be written
/// to write_end.
pub(crate) fn process_output<F>(
    read_end: &mut dyn Read,
    write_end: &mut dyn Write,
    mut process_line: F,
) -> io::Result<()>
where
    F: FnMut(String) -> LineOutput,
{
    let mut reader = io::BufReader::new(read_end);
    let mut writer = io::LineWriter::new(write_end);
    loop {
        let mut line = String::new();
        let read_bytes = reader.read_line(&mut line)?;
        if read_bytes == 0 {
            break;
        }
        match process_line(line) {
            LineOutput::Message(to_write) => writer.write_all(to_write.as_bytes())?,
            LineOutput::Skip => {}
            LineOutput::Terminate => return Ok(()),
        };
    }
    Ok(())
}
