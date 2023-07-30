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

#include <assert.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void matrix_print(const Matrix* m) {
    for (size_t i = 0; i < m->rows; ++i) {
        for (size_t j = 0; j < m->cols; ++j) {
            uint64_t val = 0;
            matrix_at(m, i, j, &val);
            printf("%" PRIu64 " ", val);
        }
        printf("\n");
    }
}

int check_equal(const Matrix* a, const Matrix* b) {
    int equal = matrix_equal(a, b);
    if (!equal) {
        printf("Matrices not equal:\n");
        printf("a:\n");
        matrix_print(a);
        printf("\nb:\n");
        matrix_print(b);
    }
    return equal;
}

void test_equal() {
    // clang-format off
  static uint64_t a_data[] = {11, 12, 13, 14,
                              21, 22, 23, 24};
    // clang-format on
    Matrix* a = matrix_new(2, 4, a_data);
    assert(a != NULL);
    assert(check_equal(a, a));

    // clang-format off
  static uint64_t b_data[] = {13, 14, 15, 16,
                              22, 23, 24, 25};
    // clang-format on
    Matrix* b = matrix_new(2, 4, b_data);
    assert(b != NULL);
    assert(!matrix_equal(a, b));
}

void test_transpose() {
    // clang-format off
  static uint64_t matrix_data[] = {11, 12, 13, 14,
                                   21, 22, 23, 24};
    // clang-format on
    Matrix* matrix = matrix_new(2, 4, matrix_data);
    assert(matrix != NULL);
    matrix_transpose(matrix);

    // clang-format off
  static uint64_t expected_transpose_data[] = {11, 21,
                                               12, 22,
                                               13, 23,
                                               14, 24};
  // clang-format off
  Matrix* expected_transpose = matrix_new(4, 2, expected_transpose_data);

  assert(check_equal(expected_transpose, matrix));
}

int main(int argc, char** argv) {
  test_equal();
  test_transpose();
  return EXIT_SUCCESS;
}
