## hotspot debug using gdb
- Same as debugging c/c++ code using gdb.
- Usage: gdb ~/source/java/jdk/build/linux-x86_64-server-slowdebug/images/jdk/bin/java
	- Usage: r Test2
	- Usage: b, c, n, s, i, finish, print, info


## hotspot debug using CLion
- Add a `custom build application` configuration
	- targer: the target for building
		- Add `custom build target` using `make`
	- executable: select the `java` command
	- program arguments: the java program you want to run
	- working directory: the directory of your java program
	- before launch: if your java program was not compiled, you can add a `run external tool` in here to compile your program.
- set breakpoint, start debugging or running.


## TODO uncomplete. hotspot remote debug using cLion
- Command Line: `gdbserver :1234 ~/source/java/jdk/build/linux-x86_64-server-slowdebug/images/jdk/bin/java`
- CLion: Set a gdb remote debug configurations
	- name: any
	- gdb: /usr/bin/gdb
	- target: 127.0.0.1:1234
	- symbol file: /home/lgx/source/java/jdk/build/linux-x86_64-server-slowdebug/jdk/bin/java
	- sysroot: /home/lgx/source/java/jdk
	- path mappings
		- remote: /home/lgx/source/java/jdk
		- local: /home/lgx/source/java/jdk

