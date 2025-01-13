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

extern crate libc;

mod ffi;

use std::ops;
use std::ptr;

/// Wrapper around pointer to FFI Matrix struct.
pub struct Matrix {
    matrix: *mut ffi::Matrix,
}

/// Wrapper around low-level FFI Matrix API.
impl Matrix {
    /// Constructs a new Matrix from the given data. Matrix returned contains a copy of the data
    /// provided.
    ///
    /// # Panics
    ///
    /// If rows * cols does not equal data.len() or if matrix could not be allocated.
    pub fn new(rows: usize, cols: usize, data: &[u64]) -> Matrix {
        if data.len() != rows * cols {
            panic!(
                "rows * cols ({}) do not equal data.len() ({})",
                rows * cols,
                data.len()
            );
        }

        let mut data_copy: Vec<u64> = vec![0; data.len()];
        data_copy.clone_from_slice(data);
        unsafe {
            let matrix: *mut ffi::Matrix = ffi::matrix_new(rows, cols, data_copy.as_ptr());
            if matrix.is_null() {
                panic!("Failed to allocate Matrix.");
            }
            Matrix { matrix }
        }
    }

    /// Fetches the value at the specified row and column.
    pub fn at(&self, row: usize, col: usize) -> Option<u64> {
        let mut n: u64 = 0;
        unsafe {
            if ffi::matrix_at(self.matrix, row, col, &mut n) == 0 {
                return None;
            }
        }
        Some(n)
    }

    /// Sets the value at the specified row and column.
    ///
    /// # Panics
    ///
    /// If row, col is out of bounds.
    pub fn set(&mut self, row: usize, col: usize, n: u64) {
        unsafe {
            if ffi::matrix_set(self.matrix, row, col, n) == 0 {
                panic!("Row {}, col {} is out of bounds.", row, col);
            }
        }
    }

    /// Returns the number of rows of the matrix.
    pub fn rows(&self) -> usize {
        unsafe { (*self.matrix).rows }
    }

    /// Returns the number of cols of the matrix.
    pub fn cols(&self) -> usize {
        unsafe { (*self.matrix).cols }
    }

    /// Performs an in-place transposition of the matrix.
    pub fn transpose(&mut self) {
        unsafe {
            ffi::matrix_transpose(self.matrix);
        }
    }

    /// Checks whether the matrix is equal to the provided Matrix.
    pub fn equal(&self, other: &Matrix) -> bool {
        unsafe { ffi::matrix_equal(self.matrix, other.matrix) != 0 }
    }
}

impl ops::Drop for Matrix {
    fn drop(&mut self) {
        unsafe {
            ffi::matrix_free(self.matrix);
        }
        self.matrix = ptr::null_mut();
    }
}

#[cfg(test)]
mod test {
    use super::Matrix;

    #[test]
    fn test_size() {
        let matrix = Matrix::new(2, 4, &[11, 12, 13, 14, 21, 22, 23, 24]);
        assert_eq!(2, matrix.rows());
        assert_eq!(4, matrix.cols());
    }

    #[test]
    fn test_equal() {
        let matrix_a = Matrix::new(2, 4, &[11, 12, 13, 14, 21, 22, 23, 24]);
        let matrix_b = Matrix::new(2, 4, &[11, 12, 13, 14, 21, 22, 23, 24]);
        assert!(matrix_a.equal(&matrix_b));

        let matrix_c = Matrix::new(2, 4, &[12, 13, 14, 15, 23, 24, 25, 26]);
        assert!(!matrix_a.equal(&matrix_c));
    }

    #[test]
    fn test_transpose() {
        let mut matrix = Matrix::new(2, 4, &[11, 12, 13, 14, 21, 22, 23, 24]);
        matrix.transpose();
        let expected = Matrix::new(4, 2, &[11, 21, 12, 22, 13, 23, 14, 24]);
        assert!(matrix.equal(&expected));
    }
}
