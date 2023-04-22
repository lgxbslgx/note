## build jdk
### configure
- If want to use jmh: `sh make/devkit/createJMHBundle.sh`
- Usage: 

```
sh configure \
--with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg \
--with-boot-jdk=/home/lgx/source/java/jdk19u/build/linux-x86_64-server-release/images/jdk \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--with-hsdis=capstone \
```

- Cross-compiling: 

```
export PATH=/opt/riscv/bin:$PATH
export sysroot=/opt/riscv/sysroot
export prefix=$sysroot/usr
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/riscv/sysroot/lib:/opt/riscv/sysroot/usr/lib


sh configure \
--with-boot-jdk=/home/lgx/source/java/jdk19u/build/linux-x86_64-server-release/images/jdk \
--disable-warnings-as-errors \
--openjdk-target=riscv64-linux-gnu \
--with-sysroot=/opt/riscv/sysroot \
--with-toolchain-path=/opt/riscv/bin \
--with-extra-path=/opt/riscv/bin


# debug
sh configure \
--with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg \
--with-boot-jdk=/home/lgx/source/java/jdk19u/build/linux-x86_64-server-release/images/jdk \
--with-gtest=/home/lgx/source/cpp/gtest \
--with-jmh=/home/lgx/source/java/jdk/build/jmh/jars \
--disable-warnings-as-errors \
--with-debug-level=slowdebug \
--with-native-debug-symbols=internal \
--openjdk-target=riscv64-linux-gnu \
--with-sysroot=/opt/riscv/sysroot \
--with-toolchain-path=/opt/riscv/bin \
--with-extra-path=/opt/riscv/bin \
--with-hsdis=binutils \
--with-binutils=/source/c/lib_src/binutils \

# Debian sysroots
sudo debootstrap --no-check-gpg \
--foreign --arch=riscv64 --verbose \
--include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
--resolve-deps buster /opt/debian/sysroot-riscv64 \
http://httpredir.debian.org/debian-ports/
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
--with-hsdis=capstone \

## `make images JOBS=4`可能会内存溢出，用`JOBS=1`就好了
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
