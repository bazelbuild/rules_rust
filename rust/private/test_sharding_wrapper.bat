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
@REM --list flag, partitions them by shard index, and runs only the relevant subset.

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

IF !FOUND_BINARY! EQU 0 (
    ECHO ERROR: Could not find test binary at any expected location
    EXIT /B 1
)

@REM If sharding is not enabled, run test binary directly
IF "%TEST_TOTAL_SHARDS%"=="" (
    !TEST_BINARY_PATH! %*
    EXIT /B !ERRORLEVEL!
)

@REM Touch status file to advertise sharding support to Bazel
IF NOT "%TEST_SHARD_STATUS_FILE%"=="" (
    TYPE NUL > "%TEST_SHARD_STATUS_FILE%"
)

@REM Create a temporary file for test list
SET TEMP_LIST=%TEMP%\rust_test_list_%RANDOM%.txt

@REM Enumerate all tests using libtest's --list flag
!TEST_BINARY_PATH! --list --format terse 2>NUL > "!TEMP_LIST!"

@REM Count tests and filter for this shard
SET INDEX=0
SET SHARD_TESTS=

FOR /F "tokens=1 delims=:" %%T IN ('TYPE "!TEMP_LIST!" ^| FINDSTR /E ": test"') DO (
    SET /A MOD=!INDEX! %% %TEST_TOTAL_SHARDS%
    IF !MOD! EQU %TEST_SHARD_INDEX% (
        IF "!SHARD_TESTS!"=="" (
            SET SHARD_TESTS=%%T
        ) ELSE (
            SET SHARD_TESTS=!SHARD_TESTS! %%T
        )
    )
    SET /A INDEX=!INDEX! + 1
)

DEL "!TEMP_LIST!" 2>NUL

@REM If no tests for this shard, exit successfully
IF "!SHARD_TESTS!"=="" (
    EXIT /B 0
)

@REM Run the filtered tests with --exact to match exact test names
!TEST_BINARY_PATH! !SHARD_TESTS! --exact %*
EXIT /B !ERRORLEVEL!
