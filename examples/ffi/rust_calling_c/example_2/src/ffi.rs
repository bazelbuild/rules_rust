// Copyright 2017 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use libc::{c_int, size_t};

#[repr(C)]
#[derive(Clone, Copy)]
pub struct Matrix {
    pub rows: size_t,
    pub cols: size_t,
    pub data: *mut u64,
}

// #[link(name = "native_matrix")] // Don't need this, BUILD file manages linking already.
extern "C" {
    pub fn matrix_new(rows: size_t, cols: size_t, data: *const u64) -> *mut Matrix;
    pub fn matrix_at(matrix: *const Matrix, row: size_t, col: size_t, n: *mut u64) -> c_int;
    pub fn matrix_set(matrix: *const Matrix, row: size_t, col: size_t, n: u64) -> c_int;
    pub fn matrix_transpose(matrix: *mut Matrix);
    pub fn matrix_equal(a: *const Matrix, b: *const Matrix) -> c_int;
    pub fn matrix_free(matrix: *mut Matrix);
}
