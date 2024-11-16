### building

- cd llvm-project
- mkdir build
- 配置

```shell
cmake -S llvm -B build -G "Ninja" \
-DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;cross-project-tests;libclc;lld;lldb;mlir;polly;pstl;compiler-rt;libc;openmp" \
-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
-DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
-DCMAKE_BUILD_TYPE="Debug" \
-DLLVM_ENABLE_ASSERTIONS="ON" \
-DCMAKE_C_COMPILER="/usr/bin/clang-15" \
-DCMAKE_CXX_COMPILER="/usr/bin/clang++-15" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev" \
-DLLVM_USE_LINKER="lld"
```

- 构建：`cmake --build build -- -j 4` 或者 `cd build && ninja -j 4 && ninja install`
- 构建某个target：`cd build && ninja clang`
- 执行测试：`cd build && ninja check-clang` 前缀是`check-`
- 执行指定的测试，比如 `./build/bin/llvm-lit -v clang/test/SemaCXX/warn-infinite-recursion.cpp` 或者 `bin/llvm-lit -v ../clang/test/SemaCXX/warn-infinite-recursion.cpp`
- 执行单元测试，比如 `ninja ToolingTests && tools/clang/unittests/Tooling/ToolingTests --gtest_filter=ReplacementTest.CanDeleteAllText`


