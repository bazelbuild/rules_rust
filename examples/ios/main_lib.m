#include <stdio.h>

// Instead of doing this manually https://github.com/dtolnay/cxx could be used for complex examples
extern int32_t get_a_value_from_rust(void);
extern void print_something_from_rust(void);

int main() {
  print_something_from_rust();
  printf("Some value from rust: %d\n", get_a_value_from_rust());
  return 0;
}
