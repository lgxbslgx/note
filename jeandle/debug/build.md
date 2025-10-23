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
-DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
-DCMAKE_BUILD_TYPE="Release" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/install/llvm-dev" \
-DLLVM_BUILD_LLVM_DYLIB=On \
-DLLVM_DYLIB_COMPONENTS=all ../llvm

# 构建
cmake --build . --target install  -- -j 12
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
make images JOBS=12

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

## 交叉编译

### 交叉编译到Aarch64

```shell
# 安装依赖
sudo apt install g++-aarch64-linux-gnu gcc-aarch64-linux-gnu
sudo apt install debootstrap
sudo apt install qemu-user-static
sudo ln -s /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1  /lib/ld-linux-aarch64.so.1

# 创建debian系统
sudo debootstrap \
--arch=arm64 \
--verbose \
--components=main,universe \
--include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
--resolve-deps jammy \
/home/lgx/source/debian-sysroot/arm64 \
http://ports.ubuntu.com/ubuntu-ports/

# 修改系统根
sudo chroot /home/lgx/source/debian-sysroot/arm64 symlinks -cr .

# 配置LLVM
mkdir build
cd build

cmake -G "Unix Makefiles" \
-DLLVM_TARGETS_TO_BUILD="AArch64" \
-DCMAKE_BUILD_TYPE="Release" \
-DLLVM_DEFAULT_TARGET_TRIPLE="aarch64-unknown-linux-gnu" \
-DCMAKE_SYSROOT="/home/lgx/source/debian-sysroot/arm64" \
-DCMAKE_SYSTEM_NAME=Linux \
-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
-DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc \
-DCMAKE_CXX_COMPILER=/usr/bin/aarch64-linux-gnu-g++ \
-DCMAKE_C_COMPILER_TARGET=/usr/bin/aarch64-linux-gnu \
-DCMAKE_CXX_COMPILER_TARGET=/usr/bin/aarch64-linux-gnu \
-DCMAKE_FIND_ROOT_PATH=/home/lgx/source/debian-sysroot/aarch64 \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
-DCMAKE_EXE_LINKER_FLAGS="-L/home/lgx/source/debian-sysroot/arm64/sysroot/usr/lib/aarch64-linux-gnu -L/home/lgx/source/debian-sysroot/arm64/usr/lib/gcc/aarch64-linux-gnu/11 -latomic" \
-DCMAKE_SHARED_LINKER_FLAGS="-L/home/lgx/source/debian-sysroot/arm64/sysroot/usr/lib/aarch64-linux-gnu -L/home/lgx/source/debian-sysroot/arm64/usr/lib/gcc/aarch64-linux-gnu/11 -latomic" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/source/debian-sysroot/arm64/install/llvm-dev" \
-DLLVM_BUILD_LLVM_DYLIB=On \
-DLLVM_DYLIB_COMPONENTS=all \
../llvm

# 构建LLVM
sudo cmake --build . --target install  -- -j 12

sudo ldconfig -r ~/source/debian-sysroot/arm64/

# 配置JDK
sh configure \
--with-jtreg=/home/lgx/install/jtreg \
--with-boot-jdk=/usr/lib/jvm/java-21-openjdk-amd64/ \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone \
--openjdk-target=aarch64-linux-gnu \
--with-sysroot=/home/lgx/source/debian-sysroot/arm64 \
--with-host-jeandle-llvm=/home/lgx/install/llvm-dev \
--with-jeandle-llvm=/home/lgx/source/debian-sysroot/arm64/install/llvm-dev

# 构建JDK
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/lgx/source/debian-sysroot/arm64/lib:/home/lgx/source/debian-sysroot/arm64/usr/lib:/home/lgx/source/debian-sysroot/arm64/lib/aarch64-linux-gnu:/home/lgx/source/debian-sysroot/arm64/usr/lib/aarch64-linux-gnu:/home/lgx/source/debian-sysroot/arm64/install/llvm-dev/lib
make images JOBS=12

# 运行
qemu-aarch64-static -L /home/lgx/source/debian-sysroot/arm64/ /home/lgx/source/java/jeandle-jdk-aarch64/build/linux-aarch64-server-slowdebug/images/jdk/bin/java --version
```

### 交叉编译到riscv64

```shell
# 安装依赖
sudo apt install g++-riscv64-linux-gnu gcc-riscv64-linux-gnu
sudo apt install debootstrap
sudo apt install qemu-user-static
sudo ln -s /usr/riscv64-linux-gnu/lib/ld-linux-riscv64-lp64d.so.1 /lib/ld-linux-riscv64-lp64d.so.1

# 创建debian系统
sudo debootstrap \
--arch=riscv64 \
--verbose \
--components=main,universe \
--include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
--resolve-deps jammy \
/home/lgx/source/debian-sysroot/riscv64 \
http://ports.ubuntu.com/ubuntu-ports/

# 修改系统根
sudo chroot /home/lgx/source/debian-sysroot/riscv64 symlinks -cr .

# 配置LLVM
mkdir build
cd build

cmake -G "Unix Makefiles" \
-DLLVM_TARGETS_TO_BUILD="RISCV" \
-DCMAKE_BUILD_TYPE="Release" \
-DCMAKE_SYSTEM_NAME=Linux \
-DCMAKE_SYSTEM_PROCESSOR=riscv64 \
-DCMAKE_C_COMPILER=/usr/bin/riscv64-linux-gnu-gcc \
-DCMAKE_CXX_COMPILER=/usr/bin/riscv64-linux-gnu-g++ \
-DCMAKE_C_COMPILER_TARGET=/usr/bin/riscv64-linux-gnu \
-DCMAKE_CXX_COMPILER_TARGET=/usr/bin/riscv64-linux-gnu \
-DCMAKE_FIND_ROOT_PATH=/home/lgx/source/debian-sysroot/riscv64 \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
-DCMAKE_EXE_LINKER_FLAGS="-L/home/lgx/source/debian-sysroot/riscv64/usr/lib/riscv64-linux-gnu -L/home/lgx/source/debian-sysroot/riscv64/usr/lib/gcc/riscv64-linux-gnu/11 -latomic" \
-DCMAKE_SHARED_LINKER_FLAGS="-L/home/lgx/source/debian-sysroot/riscv64/usr/lib/riscv64-linux-gnu -L/home/lgx/source/debian-sysroot/riscv64/usr/lib/gcc/riscv64-linux-gnu/11 -latomic" \
-DLLVM_DEFAULT_TARGET_TRIPLE="riscv64-unknown-linux-gnu" \
-DCMAKE_SYSROOT="/home/lgx/source/debian-sysroot/riscv64" \
-DCMAKE_INSTALL_PREFIX="/home/lgx/source/debian-sysroot/riscv64/install/llvm-dev" \
-DLLVM_BUILD_LLVM_DYLIB=On \
-DLLVM_DYLIB_COMPONENTS=all \
../llvm

# 构建LLVM
sudo cmake --build . --target install  -- -j 12

sudo ldconfig -r ~/source/debian-sysroot/riscv64

# 配置JDK
sh configure \
--with-jtreg=/home/lgx/install/jtreg \
--with-boot-jdk=/usr/lib/jvm/java-21-openjdk-amd64/ \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone \
--openjdk-target=riscv64-linux-gnu \
--with-sysroot=/home/lgx/source/debian-sysroot/riscv64 \
--with-host-jeandle-llvm=/home/lgx/install/llvm-dev \
--with-jeandle-llvm=/home/lgx/source/debian-sysroot/riscv64/install/llvm-dev

# 构建JDK
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/lgx/source/debian-sysroot/riscv64/lib:/home/lgx/source/debian-sysroot/riscv64/usr/lib:/home/lgx/source/debian-sysroot/riscv64/lib/riscv64-linux-gnu:/home/lgx/source/debian-sysroot/riscv64/usr/lib/riscv64-linux-gnu:/home/lgx/source/debian-sysroot/riscv64/install/llvm-dev/lib
make images JOBS=12

# 运行
qemu-riscv64-static -L /home/lgx/source/debian-sysroot/riscv64/ /home/lgx/source/java/jeandle-jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/bin/java --version
```
