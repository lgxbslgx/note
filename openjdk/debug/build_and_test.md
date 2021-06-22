## build jdk
### configure
- Usage: `sh configure --with-jtreg=/home/lgx/source/java/jtreg-stable/build/images/jtreg --with-boot-jdk=/home/lgx/source/java/jdk16u/build/linux-x86_64-server-release/images/jdk --with-gtest=/home/lgx/source/cpp/gtest --with-debug-level=slowdebug --with-native-debug-symbols=internal`
- Usage: `sh configure --with-jtreg="path" --with-boot-jdk="path" --with-debug-level=slowdebug --with-native-debug-symbols=internal`
- Usage(simple): `sh configure --with-boot-jdk="path"`
	- the `--with-jtreg --with-gtest` are not needed, if you only want to build but not test.
	- the `--with-debug-level=slowdebug --with-native-debug-symbols=internal` are not needed if you don't want to debug hotspot.
	- Can use `make reconfigure` instead of `sh configure` after the first time.

### build
- `make images`
	- build all the code and generate the complete jdk
- `make clean`
	- clean the old build
- `sh bin/idea.sh`
	- generate some files to support the Intellij IDE
	- java program can be debugged by using IDEA
	- hotspot(c/c++) can be debugged by using CLion

### test
- `make test TEST="some test target"`
	- TEST usage: "test type" : "directory path" : "groups"
	- eg: make test TEST="tier1"
	- eg: make test TEST="jtreg:/test/langtools:tier1"
	- eg: make test TEST="gtest:LogTagSetDescriptions"
	- eg: make test TEST="micro:java.lang.reflect" MICRO="FORK=1;WARMUP_ITER=2"
	- eg: make test TEST="jtreg:test/langtools/tools/javac/T8254557/T8254557.java"
