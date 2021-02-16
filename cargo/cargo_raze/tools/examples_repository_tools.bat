@ECHO OFF
setlocal ENABLEDELAYEDEXPANSION
:: Windows only supports vendoring

for /D %%i in (%EXAMPLES_DIR%\vendored\*) do (
    echo Vendoring Sources for %%i

    :: Make a temporary directory to save existing BUILD files into
    echo Making temp dir
    rmdir /Q /S %%i\.temp
    mkdir %%i\.temp

    :: Save BUILD files
    echo Saving BUILD files
    pushd %%i\cargo\vendor
    for /D %%s in (*) do (
        echo Saving %%s\BUILD.bazel to %%i\.temp\%%s\BUILD.bazel
        mkdir "%%i\.temp\%%s"
        copy /v /y /b "%%s\BUILD.bazel" "%%i\.temp\%%s\BUILD.bazel"
    )
    popd

    :: Do vendoring
    echo Vendoring
    START /b /d %%i /wait %CARGO% vendor -q --versioned-dirs cargo\vendor

    :: Restore BUILD files
    echo Restoring BUILD files
    pushd %%i\.temp
    for /D %%r in (*) do (
        echo Restoring %%r\BUILD.bazel to %%i\cargo\vendor\%%r\BUILD.bazel
        copy /v /y /b "%%r\BUILD.bazel" "%%i\cargo\vendor\%%r\BUILD.bazel"
    )
    popd

    :: Cleanup
    rmdir /Q /S %%i\.temp
    echo Done
)
