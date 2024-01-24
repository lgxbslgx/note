## core dump文件相关内容
core dump文件一般会直接输出到当前目录，但是现在一些新版本的系统有一些新的处理方式，详见下文。

### core dump文件大小
```
# 查看文件最大值
ulimit -c

# 设置文件最大值为不限定
ulimit -c unlimited
```

### core dump文件输出
使用命令`cat /proc/sys/kernel/core_pattern`查看文件输出的格式。可能格式有：
- 单纯的路径和文件名格式，则相当于使用`>`把输出重定向到对应文件。
  - 如果只有文件名格式，则输出内容到**当前目录**的对应文件中。比如`core-%e-%p-%t`
  - 如果有路径和文件名，则输出内容到**对应目录**的对应文件中。比如`/tmp/core-%e-%p-%t`
- 以`|`开头的情况，相当于使用linux的管道`|`把输出交给`|`后面的命令进行处理。
  - `|`后面的命令和平常一样，可以是可执行文件和脚本文件。常见的是python脚本。
  - 后面的命令一般可能在目录`/usr/share/`和`/usr/lib`中
    - 比如命令`/usr/share/apport/apport`
    - 比如命令`/usr/lib/systemd/systemd-coredump`
  - 而具体的处理和输出路径则要看对应的可执行文件和脚本文件。这些可执行文件和脚本文件一般都是输出整体的日记信息到一个文件，然后把传来的core dump信息输出到一个文件。
    - 比如把整体信息输出到`/var/log/apport`、`/var/log/systemd`
    - 比如**把core dump信息输出到目录`/var/lib/apport/coredump`、`/var/lib/systemd/coredump`**

