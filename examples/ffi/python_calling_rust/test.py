from ffi.python_calling_rust.hello_py import sum_as_string

assert sum_as_string(1, 1) == "2"
print("Ok!")
