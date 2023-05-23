## build jdk
### configure
- If want to use jmh: `sh make/devkit/createJMHBundle.sh`
- Usage: 

```
sh configure \
--with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg \
--with-boot-jdk=/home/lgx/source/java/jdk20u/build/linux-x86_64-server-release/images/jdk \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone \

# 使用llvm来构建hsdis
--with-hsdis=llvm --with-llvm=/usr/lib/llvm-10

# 使用binutils来构建hsdis
--with-hsdis=binutils --with-binutils-src=
```

- riscv Cross-compiling: 

```
export PATH=/opt/riscv/bin:$PATH
export sysroot=/opt/riscv/sysroot
export prefix=$sysroot/usr
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/riscv/sysroot/lib:/opt/riscv/sysroot/usr/lib


sh configure \
--with-boot-jdk=/home/lgx/source/java/jdk20u/build/linux-x86_64-server-release/images/jdk \
--disable-warnings-as-errors \
--openjdk-target=riscv64-linux-gnu \
--with-sysroot=/opt/riscv/sysroot \
--with-toolchain-path=/opt/riscv/bin \
--with-extra-path=/opt/riscv/bin


# debug
sh configure \
--with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg \
--with-boot-jdk=/home/lgx/source/java/jdk20u/build/linux-x86_64-server-release/images/jdk \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--openjdk-target=riscv64-linux-gnu \
--with-sysroot=/opt/riscv/sysroot \
--with-toolchain-path=/opt/riscv/bin \
--with-extra-path=/opt/riscv/bin \
# 下面的hsdis相关内容在本地不行
--with-hsdis=binutils \
--with-binutils=/source/c/lib_src/binutils-riscv64/binutils/ \

# Debian sysroots
sudo debootstrap --no-check-gpg \
--foreign --arch=riscv64 --verbose \
--include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
--resolve-deps buster /opt/debian/sysroot-riscv64 \
http://httpredir.debian.org/debian-ports/
```

- arm Cross-compiling:
```
sudo apt install g++-aarch64-linux-gnu gcc-aarch64-linux-gnu

sudo debootstrap \
      --arch=arm64 \
      --verbose \
      --include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
      --resolve-deps \
      buster \
      /opt/debian/sysroot-arm64 \
      http://httpredir.debian.org/debian/

sudo chroot /opt/debian/sysroot-arm64 symlinks -cr .

sh configure \
--with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg \
--with-boot-jdk=/home/lgx/source/java/jdk20u/build/linux-x86_64-server-release/images/jdk \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--openjdk-target=aarch64-linux-gnu \
--with-sysroot=/opt/debian/sysroot-arm64
```

- riscv visionfive2
```
sh configure \
--with-jtreg=/home/user/source/jtreg \
--with-boot-jdk=/usr/lib/jvm/java-20-openjdk-riscv64 \
--with-gtest=/home/user/source/gtest \
--with-jmh=/home/user/source/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=binutils \
--with-binutils-src=/home/user/source/binutils

# 使用llvm来构建hsdis
--with-hsdis=llvm --with-llvm=/usr/lib/llvm-15

# capstone现在不支持riscv

# 使用llvm/clang工具链（不成功，链接报错）
--with-toolchain-type=clang \
--with-toolchain-path=/usr/lib/llvm-15/bin

# `make images JOBS=4`可能会内存溢出，用`JOBS=1`就好了。
# `JOBS=1`还是不行，`ld`链接时内存不足。
# 使用`lld`替换`ld`:
#   安装`lld`: `sudo apt install lld-15`
#   删除之前的`ld`符号链接（之前指向 `/usr/bin/riscv64-linux-gnu-ld`）： `sudo rm /usr/bin/ld`
#   使用`lld`: `sudo ln -s /usr/bin/ld.lld-15 /usr/bin/ld`
```

- arm rk3399
```
sh configure \
--with-jtreg=/home/pi/source/jtreg \
--with-boot-jdk=/home/pi/install/jdk-20.0.1 \
--with-gtest=/home/pi/source/googletest \
--with-jmh=/home/pi/source/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone
```

- Usage: `sh configure --with-jtreg="path" --with-boot-jdk="path" --with-gtest="path" --with-debug-level=slowdebug --with-native-debug-symbols=internal`
- Usage(simple): `sh configure --with-boot-jdk="path"`
	- the `--with-jtreg --with-gtest --with-jmh` are not needed, if you only want to build but not test.
	- the `--with-debug-level=slowdebug --with-native-debug-symbols=internal` are not needed if you don't want to debug hotspot.
	- Can use `make reconfigure` instead of `sh configure` after the first time.

### build
- `make images`
	- build all the code and generate the complete jdk
- `make clean`
	- clean the old build
- `make compile-commands`
    - generate compilation data for Clion or other IDE
- Coding c/c++
	- `ln -s  build/linux-x86_64-server-slowdebug/compile_commands.json compile_commands.json`
	- Clion: `Open`->`Select dir`->`Select compile_commands.json`->`Open As Project`
- Coding java
	- `sh bin/idea.sh`
	- IDEA: `Open`->`Select dir`
- Using cscode
    - `make vscode-project`
    - Open the file `jdk.code-workspace` as a workspace in the vscode

### test
- `make test TEST="some test target"`
	- TEST usage: "test type" : "directory path" : "groups"
	- eg: make test TEST="tier1"
	- eg: make test TEST="jtreg:/test/langtools:tier1"
	- eg: make test TEST="gtest:LogTagSetDescriptions"
	- eg: make test TEST="micro:java.lang.reflect" MICRO="FORK=1;WARMUP_ITER=2"
	- eg: make test TEST="jtreg:test/langtools/tools/javac/T8254557/T8254557.java"
	- eg: make test TEST="jtreg:hotspot:tier1_common jtreg:hotspot:tier1_gc jtreg:hotspot:tier1_runtime jtreg:hotspot:tier1_serviceability" JTREG="TIMEOUT_FACTOR=20;" JOBS=4

	- 如果设备性能很差，则使用`JTREG="TIMEOUT_FACTOR=20;"`来调节超时时间，避免超时引起的测试失败。注意`TIMEOUT_FACTOR`默认值是`4`，设置的值要比4大才有用。
	- 后台运行 `nohup make test TEST=jtreg:hotspot:tier1 JTREG="TIMEOUT_FACTOR=20;" JOBS=4 > out.log 2>&1 &`
	- 切换到后台运行
	```
	Ctrl + Z 暂停程序
	jobs -l 查看程序
	bg %NUMBER 后台继续执行一个程序，`NUMBER`换成`jobs -l`查到的具体的编号
	```
