## Linux内核构建
[How to quickly build a trimmed Linux kernel](https://docs.kernel.org/admin-guide/quickly-build-trimmed-linux.html)

### 本地构建
- （一次性）获取代码 `git clone https://github.com/torvalds/linux.git`
- （一次性）安装依赖 `sudo apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison`
- 配置（一般都是一次性配置）
  - 第一次配置，使用当前操作系统的配置 `yes "" | make localmodconfig`
  - 不是第一次，则直接使用旧的配置 `make olddefconfig`
- 修改配置 `make menuconfig`（一般都是一次性配置）
  - 执行`scripts/config --disable SYSTEM_REVOCATION_KEYS`
  - 修改`CONFIG_RANDOMIZE_BASE`为`n`。`Processor type and features -> Build a relocatable kernel -> 不选择 Randomize the address of the kernel image (KASLR)` （Shift+N 表示不选择）
  - 下面内容应该已经是默认选项，如果不是默认选项才要改
    - `Kernel hacking -> Compile-time checks and compiler options -> Compile the kernel with debug info -> 选择 Generate DWARF Version 5 debuginfo`（Shift+Y 表示选择）
- 构建 `make -j2`
- 安装内核模块（newbies先别不安装）`command -v installkernel && sudo make modules_install install`

### 交叉编译 ARM64
// TODO

### 交叉编译 RISCV64
// TODO

### 生成的内容
- `vmlinx` 未压缩的内核文件
- `arch/x86/boot/bzImage`或`arch/x86_64/boot/bzImage` 压缩后的镜像文件
- 查看内容 `sudo find ~/source/c/linux -name *linux*.gz -or -name *linux*.bz2 -or -name *linux*.lzma -or -name *linux*.xz -or -name *linux*.lzo -or -name *linux*.lz4 -or -name *linux*.zst`
