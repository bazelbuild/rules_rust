FROM ubuntu
RUN apt-get update && apt-get install -y ca-certificates curl git python3 binutils zstd file clang lld
RUN apt-get install -y build-essential
RUN curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.18.0/bazelisk-linux-amd64 -o /usr/bin/bazel && chmod +x /usr/bin/bazel
RUN adduser fakeuser
USER fakeuser

WORKDIR /rules_rust
RUN echo "8.4.2" > .bazelversion
RUN touch WORKSPACE && bazel help
RUN echo "bazel test //..." > ~/.bash_history
