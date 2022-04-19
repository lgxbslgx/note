## build jdk
### configure
- If want to use jmh: `sh make/devkit/createJMHBundle.sh`
- Usage: `sh configure --with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg --with-boot-jdk=/home/lgx/source/java/jdk18u/build/linux-x86_64-server-release/images/jdk --with-gtest=/home/lgx/source/cpp/gtest --with-jmh=/home/lgx/source/java/jdk/build/jmh/jars --with-debug-level=slowdebug --with-native-debug-symbols=internal`
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
	- `ln -s  build/linux-x86_64-server-fastdebug/compile_commands.json compile_commands.json`
	- Clion: `Open`->`Select dir`->`Select compile_commands.json`->`Open As Project`
- Coding java
	- `sh bin/idea.sh`
	- IDEA: `Open`->`Select dir`

### test
- `make test TEST="some test target"`
	- TEST usage: "test type" : "directory path" : "groups"
	- eg: make test TEST="tier1"
	- eg: make test TEST="jtreg:/test/langtools:tier1"
	- eg: make test TEST="gtest:LogTagSetDescriptions"
	- eg: make test TEST="micro:java.lang.reflect" MICRO="FORK=1;WARMUP_ITER=2"
	- eg: make test TEST="jtreg:test/langtools/tools/javac/T8254557/T8254557.java"
