### 使用自己编译的libc++库

- 使用不同版本的c++标准 `clang++ -std=c++17`
- 使用实验性的规范 `clang++ -lc++experimental`
- 使用libc++，gcc默认是stdc++ `clang++ -stdlib=libc++`
- 使用自己构建的libc++:

使用clang编译
~/source/cpp/llvm-project/build/bin/\
clang++ -nostdinc++ -nostdlib++  \
-isystem/home/lgx/source/cpp/llvm-project/build/include/c++/v1 \
-L /home/lgx/source/cpp/llvm-project/build/lib \
-Wl,-rpath,/home/lgx/source/cpp/llvm-project/build/lib/x86_64-unknown-linux-gnu \
-lc++ \
hello.cpp -o hello

下面使用gcc的例子不行，没找到原因。
g++ -nostdinc++ -nodefaultlibs           \
-isystem /home/lgx/source/cpp/llvm-project/build/include/c++/v1 \
-L /home/lgx/source/cpp/llvm-project/build/lib \
-Wl,-rpath,/home/lgx/source/cpp/llvm-project/build/lib/x86_64-unknown-linux-gnu\
-lc++ -lc++abi -lm -lc -lgcc_s -lgcc \
hello.cpp -o hello


