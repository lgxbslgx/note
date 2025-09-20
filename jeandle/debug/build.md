# 构建

## 构建LLVM

```shell
# 下载源码
git clone https://github.com/jeandle/jeandle-llvm.git
cd jeandle-llvm

# 新建目录
mkdir build
cd build

# 配置
cmake -G "Unix Makefiles" \
-DLLVM_TARGETS_TO_BUILD=X86 \
-DCMAKE_BUILD_TYPE="Release" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev" \
-DLLVM_BUILD_LLVM_DYLIB=On \
-DLLVM_DYLIB_COMPONENTS=all ../llvm

# 构建
cmake --build . --target install  -- -j 16
```

## 构建JDK

```shell
# 下载源码
git clone https://github.com/jeandle/jeandle-jdk
cd jeandle-jdk

# 配置
sh configure \
--with-jtreg=/home/lgx/install/jtreg \
--with-boot-jdk=/usr/lib/jvm/java-21-openjdk-amd64/ \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone \
--with-jeandle-llvm=/home/lgx/install/llvm-dev

# 构建
make images JOBS=16

# 测试
./build/linux-x86_64-server-slowdebug/images/jdk/bin/java --version

# 编译Demo
./build/linux-x86_64-server-slowdebug/images/jdk/bin/javac \
/home/lgx/source/java/test_jdk_demo/FibonacciTest.java

# 运行Demo
./build/linux-x86_64-server-slowdebug/images/jdk/bin/java \
-XX:-TieredCompilation -Xcomp \
-XX:CompileCommand=compileonly,FibonacciTest::fibonacci \
-XX:+UseJeandleCompiler FibonacciTest
```
