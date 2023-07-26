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

#include "ffi/rust_calling_c/c/matrix.h"

#include <stdio.h>
#include <string.h>

Matrix* matrix_new(size_t rows, size_t cols, const uint64_t* data) {
    if (data == NULL) {
        return NULL;
    }
    Matrix* matrix = (Matrix*)malloc(sizeof(*matrix));
    if (matrix == NULL) {
        return NULL;
    }
    matrix->rows = rows;
    matrix->cols = cols;
    matrix->data = (uint64_t*)malloc(rows * cols * sizeof(*(matrix->data)));
    memcpy(matrix->data, data, rows * cols * sizeof(*data));
    return matrix;
}

int matrix_at(const Matrix* matrix, size_t row, size_t col, uint64_t* n) {
    if (matrix == NULL || matrix->data == NULL || n == NULL) {
        return 0;
    }
    if (row >= matrix->rows || col >= matrix->cols) {
        return 0;
    }
    *n = matrix->data[row * matrix->cols + col];
    return 1;
}

int matrix_set(const Matrix* matrix, size_t row, size_t col, uint64_t n) {
    if (matrix == NULL || matrix->data == NULL) {
        return 0;
    }
    if (row >= matrix->rows || col >= matrix->cols) {
        return 0;
    }
    matrix->data[row * matrix->cols + col] = n;
    return 1;
}

void matrix_transpose(Matrix* matrix) {
    if (matrix == NULL || matrix->data == NULL) {
        return;
    }

    size_t len = matrix->rows * matrix->cols;
    int* visited = (int*)malloc(len * sizeof(*visited));
    if (visited == NULL) {
        return;
    }
    memset(visited, 0, len * sizeof(*visited));

    // Follow-the-cycles implementation of matrix transposition. Note that we
    // skip the last element since it always has a cycle of length 1 and thus
    // does not need to be moved.
    size_t q = matrix->rows * matrix->cols - 1;
    for (size_t i = 0; i < q; ++i) {
        if (visited[i] == 1) {
            continue;
        }
        size_t current_idx = i;
        size_t next_idx = i;
        do {
            visited[current_idx] = 1;
            next_idx = (current_idx * matrix->cols) % q;
            if (next_idx == i) {
                break;
            }

            uint64_t current_val = matrix->data[current_idx];
            matrix->data[current_idx] = matrix->data[next_idx];
            matrix->data[next_idx] = current_val;
            current_idx = next_idx;
        } while (1);
    }

    free(visited);
    size_t cols = matrix->rows;
    matrix->rows = matrix->cols;
    matrix->cols = cols;
}

int matrix_equal(const Matrix* a, const Matrix* b) {
    if (a == NULL || b == NULL || a->data == NULL || b->data == NULL) {
        return 0;
    }
    if (a->rows != b->rows || a->cols != b->cols) {
        return 0;
    }
    size_t len = a->rows * a->cols;
    for (size_t i = 0; i < len; ++i) {
        if (a->data[i] != b->data[i]) {
            return 0;
        }
    }
    return 1;
}

void matrix_free(Matrix* matrix) {
    if (matrix == NULL) {
        return;
    }
    if (matrix->data != NULL) {
        free(matrix->data);
    }
    free(matrix);
}
