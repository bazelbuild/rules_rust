"""Rules rust test dependencies transitive dependencies."""

load("@com_google_googleapis//:repository_rules.bzl", "switched_rules_by_language")

def rules_rust_test_deps_transitive():
    switched_rules_by_language(
        name = "com_google_googleapis_imports",
        cc = False,
        csharp = False,
        gapic = False,
        go = False,
        grpc = False,
        java = False,
        nodejs = False,
        php = False,
        python = False,
        ruby = False,
    )
