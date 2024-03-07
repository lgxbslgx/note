## 调试内核
[Debugging kernel and modules via gdb](https://docs.kernel.org/dev-tools/gdb-kernel-debugging.html)
[Booting a Custom Linux Kernel in QEMU and Debugging It With GDB](https://nickdesaulniers.github.io/blog/2018/10/24/booting-a-custom-linux-kernel-in-qemu-and-debugging-it-with-gdb/)
[make-tiny-image.py: creating tiny initrds for testing QEMU or Linux kernel/userspace behaviour](https://www.berrange.com/posts/2023/03/09/make-tiny-image-py-creating-tiny-initrds-for-testing-qemu-or-linux-kernel-userspace-behaviour/)
[qemu文档 Direct Linux Boot](https://www.qemu.org/docs/master/system/linuxboot.html)
[Using the initial RAM disk (initrd)](https://docs.kernel.org/admin-guide/initrd.html)
[Explaining the "No working init found." boot hang message](https://docs.kernel.org/admin-guide/init.html)

- （一次性）安装qemu `sudo apt-get install qemu-system`
- （一次性）构建初始化文件系统 `initrd` `initial ram disk(file system)`
  - 创建目录 `mkdir ~/source/c/initramfs`
  - 进入目录 `cd ~/source/c/initramfs`
  - 下载代码 `https://gitlab.com/berrange/tiny-vm-tools/-/blob/master/make-tiny-image.py`
  - 把代码移动到当前目录 `mv ~/Downloads/make-tiny-image.py ~/source/c/initramfs`
  - 构建初始化文件系统 `python3 make-tiny-image.py`
  - 使用其他工具也可以，比如`busybox`。不过这里使用`make-tiny-image.py`更方便
- （一次性）修改gdb配置文件`vim ~/.gdbinit`
  - 添加`add-auto-load-safe-path ~/source/c/linux/scripts/gdb/vmlinux-gdb.py`
- （一次性）构建gdb脚本
  - 进入linux目录 `cd ~/source/c/linux`
  - 运行命令 `make scripts_gdb`

### 直接使用gdb
- 进入linux目录 `cd ~/source/c/linux`
- 构建内核，详见[building.md](/linux_kernel/debug/building.md)
- 启动gdb server `qemu-system-x86_64 -kernel arch/x86/boot/bzImage -nographic -append "console=ttyS0 nokaslr" -initrd ~/source/c/initramfs/tiny-initrd.img -s -S`
- gdb调试 `gdb vmlinux`
  - 在gdb里面连接gdb server `target remote :1234`
  - 继续运行代码 `continue`

### 使用Clion
- 打开linux代码，详见[clion.md](/linux_kernel/debug/clion.md)
  - `File` -> `Open`
  - `选择 compile_commands.json`
  - `选择 Open As Project`
- （一次性）新建远程调试配置 `Add Configuration -> Add Remote Debug`
  - Name: test-kernel
  - Debugger: GDB
  - target remote args: 127.0.0.1:1234
  - Symbol file: 选择 `~/source/c/linux/vmlinux`
- 命令行启动gdb server `qemu-system-x86_64 -kernel ~/source/c/linux/arch/x86/boot/bzImage -nographic -append "console=ttyS0 nokaslr" -initrd ~/source/c/initramfs/tiny-initrd.img -s -S`
- 点击Clion的debug按钮
- 注意断点可以打在`arch/x86/kernel/head_64.S::secondary_startup_64_no_verify`。`b *0xffffffff81000145`

### gdb中常用命令
- 加载vmlinux `lx-symbols`
- dump日记buffer `lx-dmesg`
- 查看进程 `lx-ps`
- 列出命令列表 `apropos lx`
- gdb中使用`quit`退出，`linux kernel命令行`中使用`exit`退出
- 查看对应地址内容 `x/<count><format><per-size> <start-address>` `x/1000xw 0x10000`
- 输出日记到文件 `set logging file test.log` `set logging enable on` `set logging redirect on` `set logging debugredirect on`
- 反编译代码 `disassembe <start-adress>,<end-address>`
- 显示汇编代码 `display /5i $pc`
- 显示汇编代码/寄存器窗口 `layout asm/regs`
- 切换窗口焦点 `focus reg/asm/cmd`
- 退出窗口 `Ctrl X + a`
- 多进程调试
  - `fork`后调试父进程还是子进程
    - 继续调试父进程 `set follow-fork-mode parent`
    - 调试子进程 `set follow-fork-mode child`
  - 是否断开其他进程的调试 `set detach-on-fork on`
    - `on`表示: 断开`follow-fork-mode`未指定的其他进程，让它们自己运行，不挂起（遇到断点好像还是挂起，和多线程一样？）
    - `set detach-on-fork on`类似于多线程调试中的`set scheduler-locking off`


### kernel常用断点

```
# 保护模式的boot
b *0x100000

# 内核初始化开始
b *0x1000080

# 内核初始化阶段，高地址映射后的开始位置，可以获取文件和符号信息，可以在clion断点调试
b *0xffffffff81000145

# 内核初始化阶段，C语言代码的开始位置
b x86_64_start_kernel

# 内核初始化，大量具体的初始化操作
b start_kernel
```
