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
