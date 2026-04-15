@REM Copyright 2024 The Bazel Authors. All rights reserved.
@REM
@REM Licensed under the Apache License, Version 2.0 (the "License");
@REM you may not use this file except in compliance with the License.
@REM You may obtain a copy of the License at
@REM
@REM    http://www.apache.org/licenses/LICENSE-2.0
@REM
@REM Unless required by applicable law or agreed to in writing, software
@REM distributed under the License is distributed on an "AS IS" BASIS,
@REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@REM See the License for the specific language governing permissions and
@REM limitations under the License.

@REM Wrapper script for rust_test that enables Bazel test sharding support.
@REM This script intercepts test execution, enumerates tests using libtest's
@REM --list flag, partitions them by stable test-name hash, and runs only the
@REM relevant subset.

@ECHO OFF
SETLOCAL EnableDelayedExpansion

SET TEST_BINARY_RAW={{TEST_BINARY}}
SET TEST_BINARY_PATH=!TEST_BINARY_RAW:/=\!

@REM Try to find the binary using RUNFILES_DIR if set
IF DEFINED RUNFILES_DIR (
    SET TEST_BINARY_IN_RUNFILES=!RUNFILES_DIR!\!TEST_BINARY_PATH!
    IF EXIST "!TEST_BINARY_IN_RUNFILES!" (
        SET TEST_BINARY_PATH=!TEST_BINARY_IN_RUNFILES!
    )
)

@REM The short_path is like: test/unit/test_sharding/test-2586318641/sharded_test_enabled.exe
@REM But on Windows, the binary is at grandparent/test-XXX/name.exe (sibling of runfiles dir)
@REM Extract just the last two components (test-XXX/name.exe)
FOR %%F IN ("!TEST_BINARY_PATH!") DO SET BINARY_NAME=%%~nxF
FOR %%F IN ("!TEST_BINARY_PATH!\..") DO SET BINARY_DIR=%%~nxF

@REM Try various path resolutions
SET FOUND_BINARY=0

@REM Try 1: Direct path (might work in some configurations)
IF EXIST "!TEST_BINARY_PATH!" (
    SET FOUND_BINARY=1
)

@REM Try 2: Grandparent + last two path components
IF !FOUND_BINARY! EQU 0 (
    FOR %%F IN ("!TEST_BINARY_PATH!") DO (
        SET TEMP_PATH=%%~dpF
        SET TEMP_PATH=!TEMP_PATH:~0,-1!
        FOR %%D IN ("!TEMP_PATH!") DO SET PARENT_DIR=%%~nxD
    )
    SET TEST_BINARY_GP=..\..\!PARENT_DIR!\!BINARY_NAME!
    IF EXIST "!TEST_BINARY_GP!" (
        SET TEST_BINARY_PATH=!TEST_BINARY_GP!
        SET FOUND_BINARY=1
    )
)

@REM Try 3: RUNFILES_DIR based path
IF !FOUND_BINARY! EQU 0 IF DEFINED RUNFILES_DIR (
    SET TEST_BINARY_RF=!RUNFILES_DIR!\_main\!TEST_BINARY_PATH!
    SET TEST_BINARY_RF=!TEST_BINARY_RF:/=\!
    IF EXIST "!TEST_BINARY_RF!" (
        SET TEST_BINARY_PATH=!TEST_BINARY_RF!
        SET FOUND_BINARY=1
    )
)

@REM Try 4: manifest-based runfile lookup. This covers nested launchers that
@REM execute the sharding wrapper from another test's runfiles tree.
IF !FOUND_BINARY! EQU 0 (
    SET "MANIFEST=!RUNFILES_MANIFEST_FILE!"
    IF NOT DEFINED MANIFEST IF EXIST "%~f0.runfiles_manifest" SET "MANIFEST=%~f0.runfiles_manifest"
    IF NOT DEFINED MANIFEST IF EXIST "%~dpn0.runfiles_manifest" SET "MANIFEST=%~dpn0.runfiles_manifest"
    IF NOT DEFINED MANIFEST IF EXIST "%~f0.exe.runfiles_manifest" SET "MANIFEST=%~f0.exe.runfiles_manifest"

    IF DEFINED MANIFEST IF EXIST "!MANIFEST!" (
        SET "TEST_BINARY_MANIFEST_PATH=!TEST_BINARY_RAW!"
        SET "TEST_BINARY_MANIFEST_PATH=!TEST_BINARY_MANIFEST_PATH:\=/!"
        IF DEFINED TEST_WORKSPACE SET "TEST_BINARY_MANIFEST_WORKSPACE_PATH=!TEST_WORKSPACE!/!TEST_BINARY_MANIFEST_PATH!"
        FOR /F "usebackq tokens=1,* delims= " %%A IN ("!MANIFEST!") DO (
            IF "%%A"=="!TEST_BINARY_MANIFEST_PATH!" (
                SET "TEST_BINARY_PATH=%%B"
                SET FOUND_BINARY=1
                GOTO :FOUND_TEST_BINARY
            )
            IF DEFINED TEST_BINARY_MANIFEST_WORKSPACE_PATH IF "%%A"=="!TEST_BINARY_MANIFEST_WORKSPACE_PATH!" (
                SET "TEST_BINARY_PATH=%%B"
                SET FOUND_BINARY=1
                GOTO :FOUND_TEST_BINARY
            )
        )
    )
)

:FOUND_TEST_BINARY

IF !FOUND_BINARY! EQU 0 (
    ECHO ERROR: Could not find test binary at any expected location
    EXIT /B 1
)

@REM Native Bazel test sharding sets TEST_TOTAL_SHARDS/TEST_SHARD_INDEX.
@REM Explicit shard test targets can set RULES_RUST_TEST_TOTAL_SHARDS/
@REM RULES_RUST_TEST_SHARD_INDEX instead because Bazel may reserve TEST_*
@REM variables for its own test runner env.
SET TOTAL_SHARDS=%RULES_RUST_TEST_TOTAL_SHARDS%
IF "%TOTAL_SHARDS%"=="" SET TOTAL_SHARDS=%TEST_TOTAL_SHARDS%
SET SHARD_INDEX=%RULES_RUST_TEST_SHARD_INDEX%
IF "%SHARD_INDEX%"=="" SET SHARD_INDEX=%TEST_SHARD_INDEX%

@REM If sharding is not enabled, run test binary directly
IF "%TOTAL_SHARDS%"=="" (
    !TEST_BINARY_PATH! %*
    EXIT /B !ERRORLEVEL!
)
IF "%TOTAL_SHARDS%"=="0" (
    !TEST_BINARY_PATH! %*
    EXIT /B !ERRORLEVEL!
)

IF "%SHARD_INDEX%"=="" (
    ECHO ERROR: TEST_SHARD_INDEX or RULES_RUST_TEST_SHARD_INDEX must be set when sharding is enabled
    EXIT /B 1
)

@REM Touch status file to advertise sharding support to Bazel
IF NOT "%TEST_SHARD_STATUS_FILE%"=="" IF NOT "%TEST_TOTAL_SHARDS%"=="" IF NOT "%TEST_TOTAL_SHARDS%"=="0" (
    TYPE NUL > "%TEST_SHARD_STATUS_FILE%"
)

@REM Create per-wrapper temporary files. Prefer Bazel's per-test temp directory;
@REM when falling back to the shared temp directory, avoid %RANDOM%-only file
@REM names that can collide across concurrently running Windows test shards.
SET "TEMP_ROOT=%TEST_TMPDIR%"
IF NOT DEFINED TEMP_ROOT SET "TEMP_ROOT=%TEMP%"
IF NOT DEFINED TEMP_ROOT SET "TEMP_ROOT=."
:CREATE_TEMP_DIR
SET "TEMP_DIR=!TEMP_ROOT!\rust_test_sharding_!RANDOM!_!RANDOM!_!RANDOM!"
MKDIR "!TEMP_DIR!" 2>NUL
IF ERRORLEVEL 1 GOTO :CREATE_TEMP_DIR
SET "TEMP_LIST=!TEMP_DIR!\list.txt"
SET "TEMP_SHARD_LIST=!TEMP_DIR!\shard.txt"

@REM Enumerate all tests using libtest's --list flag
!TEST_BINARY_PATH! --list --format terse 2>NUL > "!TEMP_LIST!"
IF ERRORLEVEL 1 (
    RMDIR /S /Q "!TEMP_DIR!" 2>NUL
    EXIT /B 1
)

@REM Sort tests by ordinal name and filter this shard by stable FNV-1a hash so
@REM adding or removing one test does not move unrelated tests between shards.
@REM In the PowerShell fragment below, 2166136261 is the 32-bit FNV offset basis,
@REM 16777619 is the FNV prime, and 4294967295 is the UInt32 mask. Use decimal
@REM constants because Windows PowerShell can interpret 0xffffffff as -1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$tests = @(Get-Content -LiteralPath $env:TEMP_LIST | Where-Object { $_.EndsWith(': test') } | ForEach-Object { $_.Substring(0, $_.Length - 6) });" ^
    "[Array]::Sort($tests, [StringComparer]::Ordinal);" ^
    "$totalShards = [uint32]$env:TOTAL_SHARDS; $shardIndex = [uint32]$env:SHARD_INDEX;" ^
    "$fnvPrime = [uint64]16777619; $u32Mask = [uint64]4294967295;" ^
    "foreach ($test in $tests) { $hash = [uint32]2166136261; foreach ($byte in [Text.Encoding]::UTF8.GetBytes($test)) { $hash = [uint32](([uint64]($hash -bxor $byte) * $fnvPrime) -band $u32Mask) }; if (($hash %% $totalShards) -eq $shardIndex) { $test } }" ^
    > "!TEMP_SHARD_LIST!"
IF ERRORLEVEL 1 (
    RMDIR /S /Q "!TEMP_DIR!" 2>NUL
    EXIT /B 1
)

SET SHARD_TESTS=

FOR /F "usebackq delims=" %%T IN ("!TEMP_SHARD_LIST!") DO (
    IF "!SHARD_TESTS!"=="" (
        SET SHARD_TESTS=%%T
    ) ELSE (
        SET SHARD_TESTS=!SHARD_TESTS! %%T
    )
)

RMDIR /S /Q "!TEMP_DIR!" 2>NUL

@REM If no tests for this shard, exit successfully
IF "!SHARD_TESTS!"=="" (
    EXIT /B 0
)

@REM Run the filtered tests with --exact to match exact test names
!TEST_BINARY_PATH! !SHARD_TESTS! --exact %*
EXIT /B !ERRORLEVEL!
