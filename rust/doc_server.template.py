import argparse
import errno
import mimetypes
import os
import sys
from wsgiref import simple_server
import zipfile


ZIP_FILE = "{ZIP_FILE}"
TARGET_PATH = "{TARGET_PATH}"
CRATE_NAME = "{CRATE_NAME}"

DEFAULT_PORT = 8000


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--host",
        type=str,
        default="",
        help="start web server on this host (default: %(default)r)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="start web server on this port; pass 0 to automatically "
        "select a free port (default: %(default)s)",
    )
    args = parser.parse_args()
    port = args.port

    webfiles = os.path.join(os.path.dirname(__file__), ZIP_FILE)
    data = {}
    with open(webfiles, "rb") as fp:
        with zipfile.ZipFile(fp) as zp:
            for path in zp.namelist():
                data[path] = zp.read(path)
    sys.stderr.write("Read %d files from %s\n" % (len(data), ZIP_FILE))

    default_path = "/%s/%s/index.html" % (TARGET_PATH, CRATE_NAME)

    def app(environ, start_response):
        p = environ.get("PATH_INFO", "/").lstrip("/")
        if not p:
            start_response("302 Found", [("Location", default_path)])
            yield b"302 Found\n"
            return
        if p.endswith("/"):
            p += "index.html"
        blob = data.get(p)
        if not blob:
            start_response("404 Not Found", [])
            yield b"404 Not Found\n"
            return
        (mime_type, encoding) = mimetypes.guess_type(p)
        headers = []
        if mime_type is not None:
            headers.append(("Content-Type", mime_type))
        if encoding is not None:
            headers.append(("Content-Encoding", encoding))
        start_response("200 OK", headers)
        yield blob

    try:
        server = simple_server.make_server("", port, app)
    except OSError as e:
        if e.errno != getattr(errno, "EADDRINUSE", 0):
            raise
        sys.stderr.write("%s\n" % e)
        sys.stderr.write(
            "fatal: failed to bind to port %d; try setting a --port argument\n"
            % port
        )
        sys.exit(1)
    # Find which port was actually bound, in case user requested port 0.
    real_port = server.socket.getsockname()[1]
    msg = "Serving %s docs on port %d\n" % (CRATE_NAME, real_port)
    sys.stderr.write(msg)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()


if __name__ == "__main__":
    main()
