@ECHO OFF
SETLOCAL enabledelayedexpansion

:: Resolve the `${output_base}` and `${exec_root}` placeholders.
:: The external directory is a junction/symlink to output_base\external.
:: This mirrors the logic in options.rs used by the real process wrapper.
FOR /F "delims=" %%i IN ('cd external\.. ^& cd') DO SET output_base=%%i
FOR %%i IN ("%CD%") DO SET workspace_name=%%~nxi
SET exec_root=!output_base!\execroot\!workspace_name!

:: Replace the placeholders in every environment variable.
::
:: The real process wrapper also replaces placeholders in environment
:: variables. This script needs to do the same. `SET` is a cmd builtin so
:: this works when the action runs with an empty PATH.
FOR /F "tokens=1,* delims==" %%A IN ('SET') DO (
    SET "value=%%B"
    IF DEFINED value (
        SET "value=!value:${pwd}=%CD%!"
        SET "value=!value:${output_base}=%output_base%!"
        SET "value=!value:${exec_root}=%exec_root%!"
        SET "%%A=!value!"
    )
)

SET command=%*

:: Resolve the placeholders in the arguments.
SET command=!command:${pwd}=%CD%!
SET command=!command:${output_base}=%output_base%!
SET command=!command:${exec_root}=%exec_root%!

:: Strip out the leading `--` argument.
SET command=!command:~3!

:: Rewrite every `@file` argument as `@file.expanded`, with the placeholders
:: of each line replaced, as the real process wrapper does with its param
:: files. rustc then reads the rewritten file itself: one argument per line,
:: the format Bazel writes.
for %%A in (%*) do (
    SET "arg=%%~A"
    if "!arg:~0,1!"=="@" (
        CALL :expand_param_file "!arg:~1!"
        SET "command=!command:%%~A=%%~A.expanded!"
    )
)

:: Find the rustc.exe argument and sanitize it's path
for %%A in (%*) do (
    SET arg=%%~A
    if "!arg:~-9!"=="rustc.exe" (
        SET sanitized=!arg:/=\!

        SET command=!sanitized! !command:%%~A=!
        goto :break
    )
)

:break

%command%

:: Capture the exit code of rustc.exe
SET exit_code=!errorlevel!

:: Exit with the same exit code
EXIT /b %exit_code%

:: Write %~1.expanded beside the param file %~1 with the placeholders of
:: every line replaced, recursing into the files that `@` lines name.
::
:: Each line is read with delayed expansion off, so that `!` and `^` in it
:: survive, and expanded with it on, so that `&`, `|` and `<>` in it are
:: never interpreted. `FOR /F` skips empty lines, which a param file of
:: rustc flags does not contain.
:expand_param_file
SETLOCAL DisableDelayedExpansion
SET "param_file=%~1"
TYPE NUL > "%param_file%.expanded"
FOR /F "usebackq delims=" %%L IN ("%param_file%") DO (
    SET "line=%%L"
    SETLOCAL EnableDelayedExpansion
    SET "line=!line:${pwd}=%CD%!"
    SET "line=!line:${output_base}=%output_base%!"
    SET "line=!line:${exec_root}=%exec_root%!"
    IF "!line:~0,1!"=="@" (
        CALL :expand_param_file "!line:~1!"
        SET "line=!line!.expanded"
    )
    >> "%param_file%.expanded" ECHO(!line!
    ENDLOCAL
)
ENDLOCAL
EXIT /b 0
