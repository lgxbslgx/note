### building

- cd llvm-project
- mkdir build
- 配置

```shell
# debug
cmake -S llvm -B build -G "Ninja" \
-DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;cross-project-tests;libclc;lld;lldb;mlir;polly;pstl;compiler-rt;libc;openmp" \
-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
-DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
-DCMAKE_BUILD_TYPE="Debug" \
-DLLVM_ENABLE_ASSERTIONS="ON" \
-DCMAKE_C_COMPILER="/usr/bin/clang-15" \
-DCMAKE_CXX_COMPILER="/usr/bin/clang++-15" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev-main" \
-DLLVM_USE_LINKER="lld"

# release
cmake -S llvm -B build -G "Ninja" \
-DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;cross-project-tests;libclc;lld;lldb;mlir;polly;pstl;compiler-rt;libc;openmp" \
-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
-DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
-DCMAKE_BUILD_TYPE="Release" \
-DLLVM_ENABLE_ASSERTIONS="ON" \
-DCMAKE_C_COMPILER="/usr/bin/clang-15" \
-DCMAKE_CXX_COMPILER="/usr/bin/clang++-15" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev-main" \
-DLLVM_USE_LINKER="lld"

# ccache
-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \

# ccache example
cmake -S llvm -B build -G "Ninja" \
-DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
-DCMAKE_BUILD_TYPE="Release" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev-main" \
-DLLVM_BUILD_LLVM_DYLIB=On \
-DLLVM_DYLIB_COMPONENTS=all
```

- 构建：`cmake --build build -- -j 4` 或者 `cd build && ninja -j 4 && ninja install`
- 构建某个target：`cd build && ninja clang`
- 执行测试：`cd build && ninja check-clang` 前缀是`check-`
- 执行指定的测试，比如 `./build/bin/llvm-lit -v clang/test/SemaCXX/warn-infinite-recursion.cpp` 或者 `bin/llvm-lit -v ../clang/test/SemaCXX/warn-infinite-recursion.cpp`
- 执行单元测试，比如 `ninja ToolingTests && tools/clang/unittests/Tooling/ToolingTests --gtest_filter=ReplacementTest.CanDeleteAllText`
- 创建编译数据库的符号链接：`ln -s  build/compile_commands.json compile_commands.json`

