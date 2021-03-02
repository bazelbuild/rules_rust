extern "C" {
void hello_from_rust();
}

int main(int argc, char** argv){
  hello_from_rust();
}
