@ECHO OFF
SETLOCAL enabledelayedexpansion

SET command=%*

:: Resolve the `${pwd}` placeholders
SET command=!command:${pwd}=%CD%!

:: Resolve the `${output_base}` and `${exec_root}` placeholders.
:: The external directory is a junction/symlink to output_base\external.
:: This mirrors the logic in options.rs used by the real process wrapper.
FOR /F "delims=" %%i IN ('cd external\.. ^& cd') DO SET output_base=%%i
FOR %%i IN ("%CD%") DO SET workspace_name=%%~nxi
SET exec_root=!output_base!\execroot\!workspace_name!
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
