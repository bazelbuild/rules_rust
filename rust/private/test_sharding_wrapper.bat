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

SET "TEST_BINARY={{TEST_BINARY}}"

@REM If sharding is not enabled, run test binary directly
IF "%TEST_TOTAL_SHARDS%"=="" (
    "%TEST_BINARY%" %*
    EXIT /B %ERRORLEVEL%
)

@REM Touch status file to advertise sharding support to Bazel
IF NOT "%TEST_SHARD_STATUS_FILE%"=="" (
    ECHO.>"%TEST_SHARD_STATUS_FILE%"
)

@REM Create a temporary file for test list
SET "TEMP_LIST=%TEMP%\rust_test_list_%RANDOM%.txt"

@REM Enumerate all tests using libtest's --list flag
"%TEST_BINARY%" --list --format terse 2>NUL | FINDSTR /R ": test$" > "%TEMP_LIST%"

@REM Check if any tests were found
FOR %%A IN ("%TEMP_LIST%") DO IF %%~zA==0 (
    DEL "%TEMP_LIST%" 2>NUL
    EXIT /B 0
)

@REM Filter tests for this shard and build argument list
SET "INDEX=0"
SET "SHARD_TESTS="

FOR /F "usebackq delims=" %%T IN ("%TEMP_LIST%") DO (
    SET "TEST_LINE=%%T"
    @REM Strip ": test" suffix
    SET "TEST_NAME=!TEST_LINE:: test=!"
    
    @REM Calculate index % TEST_TOTAL_SHARDS
    SET /A "MOD=INDEX %% TEST_TOTAL_SHARDS"
    
    IF !MOD! EQU %TEST_SHARD_INDEX% (
        SET "SHARD_TESTS=!SHARD_TESTS! "!TEST_NAME!""
    )
    
    SET /A "INDEX+=1"
)

DEL "%TEMP_LIST%" 2>NUL

@REM If no tests for this shard, exit successfully
IF "%SHARD_TESTS%"=="" EXIT /B 0

@REM Run the filtered tests with --exact to match exact test names
"%TEST_BINARY%" %SHARD_TESTS% --exact %*
EXIT /B %ERRORLEVEL%
