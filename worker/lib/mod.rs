use protobuf::CodedInputStream;
use protobuf::CodedOutputStream;
use protobuf::Message;
use protobuf::ProtobufResult;
use std::collections::hash_map::DefaultHasher;
use std::hash::Hash;
use std::hash::Hasher;
use std::io;
use std::io::BufRead;
use std::path::PathBuf;

mod worker_protocol;
use worker_protocol::WorkRequest;
use worker_protocol::WorkResponse;

pub struct Worker {
    program_path: PathBuf,
    incremental_dir: std::path::PathBuf,
}

impl Worker {
    pub fn new<C: Into<String>>(
        program_path: PathBuf,
        rustc: PathBuf,
        compilation_mode: C,
    ) -> io::Result<Self> {
        // The incremental cache directory includes the rustc wrapper's hash to discriminate
        // between multiple workspaces having the same name (usually __main__).
        let mut cache_path = std::env::temp_dir();
        let mut hasher = DefaultHasher::new();
        rustc.hash(&mut hasher);

        cache_path.push(format!(
            "rustc-worker-{}-{}",
            hasher.finish(),
            compilation_mode.into()
        ));
        std::fs::create_dir_all(&cache_path)?;
        Ok(Worker {
            program_path,
            incremental_dir: cache_path,
        })
    }

    fn handle_request(&self, request: WorkRequest) -> ProtobufResult<WorkResponse> {
        let mut incremental_arg = std::ffi::OsString::from("incremental=");
        incremental_arg.push(&self.incremental_dir);
        let mut cmd = std::process::Command::new(&self.program_path);
        cmd.args(request.get_arguments());
        cmd.arg("--codegen");
        cmd.arg(incremental_arg);
        let output = cmd.output()?;
        Ok(WorkResponse {
            request_id: request.request_id,
            exit_code: output.status.code().unwrap(),
            output: String::from_utf8(output.stderr).expect("TODO: use the Result"),
            ..Default::default()
        })
    }

    pub fn main_loop<R: io::Read, W: io::Write>(
        &self,
        reader: &mut R,
        writer: &mut W,
    ) -> ProtobufResult<()> {
        let mut stream = CodedInputStream::new(reader);
        loop {
            let msg_len = stream.read_raw_varint32()?;
            let limit = stream.push_limit(msg_len as u64)?;
            let mut message = WorkRequest::default();
            message.merge_from(&mut stream)?;
            stream.pop_limit(limit);

            let response = self.handle_request(message)?;
            let mut output_stream = CodedOutputStream::new(writer);
            output_stream.write_raw_varint32(response.compute_size())?;
            response.write_to_with_cached_sizes(&mut output_stream)?;
            output_stream.flush()?;
            writer.flush()?;
        }
    }

    pub fn once_with_response_file<P: AsRef<std::path::Path>>(
        &self,
        response_file_path: P,
    ) -> io::Result<std::process::ExitStatus> {
        let file = std::io::BufReader::new(std::fs::File::open(response_file_path)?);

        let mut cmd = std::process::Command::new(&self.program_path);
        for line in file.lines() {
            cmd.arg(line?);
        }
        cmd.status()
    }
}

#[cfg(test)]
mod test {
    #[test]
    fn test_eof() {}
}
