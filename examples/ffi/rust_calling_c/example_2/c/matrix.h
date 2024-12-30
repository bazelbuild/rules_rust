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

#ifndef MATRIX_SRC_MATRIX_H_
#define MATRIX_SRC_MATRIX_H_

#include <stdint.h>
#include <stdlib.h>

typedef struct {
    size_t rows;
    size_t cols;
    uint64_t* data;
} Matrix;

// Constructs a new Matrix from the given data.
// Matrix returned contains a copy of the data provided.
Matrix* matrix_new(size_t rows, size_t cols, const uint64_t* data);

// Fetches the value at the specified row and column.
// Returns 1 if successful, 0 otherwise.
int matrix_at(const Matrix* matrix, size_t row, size_t col, uint64_t* n);

// Sets the value at the specified row and column.
// Returns 1 if successful, 0 otherwise.
int matrix_set(const Matrix* matrix, size_t row, size_t col, uint64_t n);

// Performs an in-place transposition of the matrix.
void matrix_transpose(Matrix* matrix);

// Returns 1 if the two matrices are equal, 0 otherwise;
int matrix_equal(const Matrix* a, const Matrix* b);

// Frees the matrix.
void matrix_free(Matrix* matrix);

#endif  // MATRIX_SRC_MATRIX_H_
