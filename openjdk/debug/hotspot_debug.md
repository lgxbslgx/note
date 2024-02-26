## hotspot debug using gdb
- Same as debugging c/c++ code using gdb.
- Usage: gdb ~/source/java/jdkvm/build/linux-x86_64-server-slowdebug/images/jdk/bin/java
	- Usage: r Test2
	- Usage: b, c, n, s, i, finish, print, info

## hotspot debug using CLion（不适用交叉编译）
- Add a `custom build application` configuration
  - target: `configure custom build target -> add -> 选择Build -> add`
    - Name: make images
    - Group: 默认的External Tools
    - Description: make images JOBS=2
    - Program: /usr/bin/make
    - Arguments:  images JOBS=2
    - Working directory: /home/lgx/source/java/slow-jdk
  - executable: select the `java` command
  - program arguments: the java program you want to run
  - working directory: the directory of your java program
  - before launch: if your java program was not compiled, you can add a `run external tool` in here to compile your program.
- set breakpoint, start debugging or running.


- 交叉编译使用qemu和原生gdb调试:
  ```
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/riscv/sysroot/lib:/opt/riscv/sysroot/usr/lib
  qemu-riscv64 -L /opt/riscv/sysroot -g 33334 \
  /source/java/jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/bin/java \
  --version

  /opt/riscv/bin/riscv64-unknown-linux-gnu-gdb \
  --eval-command="target remote localhost:33334" \
  --eval-command="set solib-search-path \
  /source/java/jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/lib:/source/java/jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/lib/jli:/source/java/jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/lib/server:/opt/riscv/sysroot/lib:/opt/riscv/sysroot/usr/lib" \
  --args /source/java/jdk-riscv64/build/linux-riscv64-server-slowdebug/images/jdk/bin/java
  ```

## 连接另一台机器进行远程**开发**和调试（比如嵌入式riscv开发板）: 
- 开发板:
  - 安装CMake（主要是本地CLion需要）、其他构建需要的工具和库（看文档`build_and_test.md`）
  - `gdbserver :33334 /home/user/source/jdk/build/linux-riscv64-server-slowdebug/images/jdk/bin/java --version`
- 本地Clion
  - 新建远程工具链
    - [文档](https://www.jetbrains.com/help/clion/remote-projects-support.html)
	  - 设置路径: `Settings | Build, Execution, Deployment | Toolchains`
	    - `Credentials`类似ssh远程连接的配置
	    - CLion会自动侦探远程的工具链（注意远程要安装CMake、rsync、gdb等）
  - 设置远程开发工具
    - 设置路径: `Settings | Build, Execution, Deployment | Deployment`
	  - `Connection`
	    - `Type`: `SFTP`
		  - `Root path`: `/home/user`
	  - `Mappings`
	    - `/source/java/jdk-riscv64` -> `/source/jdk`
		  - `/home/lgx/source/cpp/gtest/googlemock/src/gmock-all.cc` -> `/source/gtest/googlemock/src/gmock-all.cc`
		  - `/home/lgx/source/cpp/gtest/googletest/src/gtest-all.cc` -> `/source/gtest/googletest/src/gtest-all.cc`
	  - `Excluded Paths`: 新加`Local Path` -> `/source/java/jdk-riscv64/build`
  - 新建`Remote Debug`运行配置
    - name: riscv-remote
    - gdb: Remote Host Gdb
    - target: 192.168.0.103:33334
    - path mappings
      - remote: /home/user/source/jdk
      - local: /source/java/jdk-riscv64/


## 常见问题
gdb提示`不合法指令`等情况，会造成gdb在`非自己设置的断点`的位置停止，使用下面命令避免频繁的停止：
```
handle SIGILL nostop
```

设置只当前线程运行:
```
set scheduler-locking on
```

注意: 自动开启了类数据共享，所以断点打在类加载相关的类和方法上，不会被运行到，如果要调试，则使用`-Xshare:off`关闭类数据共享。相关内容在`class_load.md`和`cds.md`。
