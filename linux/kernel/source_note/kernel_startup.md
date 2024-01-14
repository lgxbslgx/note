## Linux内核启动流程

[The Linux/x86 Boot Protocol](https://docs.kernel.org/arch/x86/boot.html)
[Linux内核的引导启动](https://frankjkl.github.io/2019/03/12/Linux%E5%86%85%E6%A0%B8-%E5%BC%95%E5%AF%BC%E5%90%AF%E5%8A%A8/)
《Linux内核源代码情景分析》第10章 系统引导和初始化
《Professional Linux Kernel Architecture》APPENDIX D System Startup
《Understanding the Linux Kernel》APPENDIX A System Startup

### 硬件引导
和具体硬件有关，了解即可。`ROM stage -> RAM stage -> boot stage`
电脑开机时，会马上运行预存的一段代码（通常存在`EPROM`中。`ROM stage`）
这段存在`EPROM`的代码会加载更大的一段代码和数据到内存（`RAM stage`），并运行对应代码。
这2段代码，一般称为`BIOS`或`UEFI`。`BIOS`或`UEFI`的三大功能`初始化硬件、提供硬件的软件抽象、启动操作系统`。
`UEFI`的优势: `标准接口、开放统一`。详见: https://www.zhihu.com/question/21672895

`BIOS`的基本流程（不详细，没看过`BIOS`相关代码）:
- 上电自检（POST），检查硬件
- 初始化硬件
- 枚举并发现本地可以引导的设备
- 加载可引导设备的第一个扇区（`MBR`，512Byte），并运行其代码。进入`boot stage`。
  - `MBR`的前面446个字节是指令，接着64个字节是分区表，最后2个字节是魔数`0x55aa`
  - 加载地址为`0x7C00`，`CS寄存器`为`0x0000`，`IP寄存器`为`0x7c00`
  - 加载完成后，CPU还在16位实模式

`UEFI`的基本流程（不详细，没看过`UEFI`相关代码）:
- 上电自检（POST），检查硬件
- 初始化硬件
- 读取其引导管理器信息以确定从何处加载哪个UEFI应用。
  - 启动文件（比如BOOT.EFI），启动文件的格式是PE32或者PE32+（也就是Windows的EXE格式）
  - 启动分区（ESP分区）
- 按照引导管理器的信息，加载UEFI应用（所以`boot loader`可以说是一个UEFI应用？）
  - CPU为32位或者64位保护模式
  - 段寄存器、全局描述符表GDT、中断描述符表IDT、分页模式等都已经设置或者开启


### `boot loader`引导阶段
和具体的`boot loader`有关，了解即可。
目前常用的`boot loader`为`GRUB`（`Grand Unified Bootloader`）。
以前的常用`boot loader`为`LILO`
`boot loader`会把linux内核加载到内存，然后跳转到`setup.bin`的入口地址`_start`运行代码。
系统镜像的路径可能为`/vmlinuz`、`boot/vmlinuz`、`/bzImage`、`/boot/bzImage`
- 实模式的内容`setup.bin`会放到地址`0x0 - 0x10000`之间。（而qemu会把它加载到地址`0x10000`）
- 保护模式的内容`vmlinux.bin`会被放到地址`0x100000`
- 其中`vmlinux.bin`中的`Piggy.S`的`input_data`是压缩的内核，会放到地址`0x1000000`


### 操作系统的引导阶段
相关代码在linux内核中。

注意`vmlinux`和`vmlinx.bin`有同名的情况。
- `vmlinux`处于`linux`根目录，是整个内核代码
- `arch/x86/boot/compressed/vmlinux.bin`是由根目录的`vmlinux`去除调试等相关信息而成
- `arch/x86/boot/compressed/vmlinux.bin.zst`是`arch/x86/boot/compressed/vmlinux.bin`压缩而成
- **`arch/x86/boot/compressed/vmlinux`**是目录`arch/x86/boot/compressed`的代码加上**压缩的内核代码`arch/x86/boot/compressed/vmlinux.bin.zst`组成（在`piggy.S`的`input_data`中）**。
- `arch/x86/boot/vmlinux.bin`是由`arch/x86/boot/compressed/vmlinux`去除调试等相关信息而成


系统镜像`bzImage或vmlinuz`由`setup.bin`、`arch/x86/boot/vmlinux.bin`、`zoffset.h`打包而成
- `bzImage`由命令`arch/x86/boot/tools/build arch/x86/boot/setup.bin arch/x86/boot/vmlinux.bin arch/x86/boot/zoffset.h arch/x86/boot/bzImage`生成。
  - 打包代码详见`arch/x86/boot/tools/build.c`
  - `bzImage`构建内容详见`arch/x86/Makefile`、`arch/x86/boot/Makefile`、`arch/x86/boot/.bzImage.cmd`、`scripts/Kbuild.include::ifchanged`
- `setup.bin`和`vmlinux.bin`内容详见`arch/x86/boot/Makefile`
- `setup.bin`是`setup.elf`去掉调试等相关信息而成
  - `setup.elf`由链接文件`arch/x86/boot/setup.ld`生成
  - `setup.elf`实际上是内核引导`boot`的内容（也可以说是实模式的所有内容）
  - `arch/x86/boot/setup.ld`设置了代码入口地址`ENTRY(_start)`
- `arch/x86/boot/vmlinux.bin`是`arch/x86/boot/compressed/vmlinux`去掉调试等相关信息而成
  - `arch/x86/boot/vmlinux`是内核中除了`setup`外的内容（也可以说是保护模式的所有内容，还包括了处于`piggy.S`的整个压缩内核）
  - `arch/x86/boot/vmlinux`内容详见`arch/x86/boot/compressed/Makefile`、`arch/x86/boot/compressed/vmlinux.lds`、`arch/x86/boot/compressed/.vmlinux.cmd`、`scripts/Kbuild.include::ifchanged`


**第一阶段** 实模式阶段 `setup`
`qemu`会把`setup.bin`加载到地址`0x10000`。gdb断点`break *0x10200`，gdb不在断点处停下来，不知道原因，可能因为是实模式？

**`boot loader`调用入口地址`_start`的代码（在`/arch/x86/boot/header.S`中）**:
- 跳转到`start_of_setup`运行
- 设置栈段寄存器 `%ss`
- 调用`sti`，允许硬件中断
- // 其他代码
- 跳转到C语言函数`arch/x86/boot/main.c::main`继续运行

**`arch/x86/boot/main.c::main`的内容**:
- 设置io函数（就是x86的输入（in）输出（out）指令）
  - IO操作在`arch/x86/include/asm/shared/io.h`
- 把`setup_header`的数据拷贝到`struct boot_params boot_param`对应的字段中
  - 操作在`arch/x86/boot/main.c::copy_boot_params`
  - `struct boot_params boot_params`定义在`arch/x86/boot/main.c`
  - `struct boot_params`声明在`arch/x86/include/uapi/asm/bootparam.h`
  - `struct boot_params boot_param`也叫做零页zero page，保护模式开启后的第一个页
- 初始化控制台
  - 操作在`arch/x86/boot/early_serial_console.c::console_init`
  - 传入参数`serial,0x3f8,115200`、`serial,ttyS0,115200`、`ttyS0,115200`、`console=uart8250,io,0x3f8,115200n8`才需要初始化
  - 往`0x3f8 + 一个常量`的端口（寄存器）输出信息来初始化控制台 `early_serial_init`
- 调用`arch/x86/boot/tty.c::puts`输出日记，里面会同时使用BIOS的中断和刚刚初始化的控制台来输出内容
  - BIOS的中断代码在`arch/x86/boot/bioscall.S::intcall`
  - 控制台疏忽的代码在`arch/x86/boot/tty.c::serial_putchar`
- 初始化堆，也就是设置指针`heap_end`的值 `arch/x86/boot/main.c::init_heap`
- 验证CPU `arch/x86/boot/cpu.c::validate_cpu`、`arch/x86/boot/cpucheck.c::check_cpu`
- 通知BIOS当前CPU运行的模式 `arch/x86/boot/main.c::set_bios_mode`
- 物理内存侦探 `arch/x86/boot/main.c::detect_memory`
  - 三个BIOS中断可以侦探内存: `E820`、`E801`、`88`。这三个中断能获取的信息逐渐减少。
  - 侦探的结果放到`boot_params.e820_table`、`boot_params.alt_mem_k`、`boot_params.screen_info.ext_mem_k`中
- 初始化键盘 `arch/x86/boot/main.c::keyboard_init`
  - 侦探键盘锁状态
  - 设置键盘重复比率
- 查询`Intel SpeedStep (IST)`信息 `arch/x86/boot/main.c::query_ist`
  - SpeedStep技术是通过降低cpu主频来达到降低功耗的技术
- 查询电量管理信息 `APM Advanced Power Management` `arch/x86/boot/apm.c::query_apm_bios`
- 查询增强磁盘驱动器信息 `EDD Enhanced Disk Drive` `arch/x86/boot/edd.c::query_edd`
- 设置图像模式 `arch/x86/boot/video.c::set_video`
- 进入保护模式 `arch/x86/boot/pm.c::go_to_protected_mode`
  - 调用实模式切换钩子 `arch/x86/boot/pm.c::realmode_switch_hook`
  - 打开A20总线 `arch/x86/boot/a20.c::enable_a20`
  - 重置cr0的IGNNE（被浮点运算单元使用） `arch/x86/boot/pm.c::reset_coprocessor`
  - 禁用中断（PIC 可编程中断控制器） `arch/x86/boot/pm.c::mask_all_interrupts`
  - 设置中断描述符表为空（使用命令`lidtl`） `arch/x86/boot/pm.c::setup_idt`
  - 设置全局描述符表（用于保护模式下的段式管理，这里只设置了3项，如下所示）（使用命令`lgdtl`） `arch/x86/boot/pm.c::setup_gdt`
    - 代码段 GDT_ENTRY_BOOT_CS: 基地址为0，大小为4G，可读可执行
    - 数据段 GDT_ENTRY_BOOT_DS: 基地址为0，大小为4G，可读可写
    - 任务状态段（TSS task state segment）GDT_ENTRY_BOOT_TSS: 基地址为4096，大小为104B
  - 跳转到保护模式，并运行位置为`0x100000`的代码（该地址是保护模式的内核内容`vmlinux.bin`） `arch/x86/boot/pmjump.c::protected_mode_jump`
    - 设置`cr0`的`PE`位（保护模式位）为`1`
    - 跳转到`.Lin_pm32`运行（32位模式的代码）
    - 设置段寄存器
    - 设置任务寄存器的段描述符域 `ltr`
    - 清除多个寄存器
    - 设置本地描述符表为空（使用命令`lldt`）
    - 跳转到保护模式的代码`boot_params.hdr.code32_start`运行，也就是`0x100000`，也就是`vmlinux`的入口`arch/x86/boot/compressed/head_64.S::startup_32`


**第二阶段** 保护模式阶段 `vmlinux`
`qemu`会把`vmlinux`加载到地址`0x100000`。gdb断点`break *0x100000`。

**`vmlinux`入口在`arch/x86/boot/compressed/head_64.S::startup_32`，是32位的代码**，具体内容如下:
- 清理`EFLAGS`的`DF`位 `CLD`
- 禁止硬件中断 `cli`
- 设置栈指针寄存器`esp`
- 再次设置全局描述符表（使用命令`lgdt`）
- 设置段寄存器
- 设置新的栈指针寄存器`esp`
- 跳转到`1`。这一步使用了`lretl`指令来跳转，为了设置CS段寄存器
- 设置中断描述符表（使用命令`lidt`）`arch/x86/boot/compressed/mem_encrypt.S::startup32_load_idt`
  - 中断描述符表描述信息（地址、大小）在`mem_encrypt.S::boot32_idt_desc`
  - 中断描述符表在`mem_encrypt.S::boot32_idt`
  - 还会设置`VMM Communication Exception`的中断条目
    - `X86_TRAP_VC 对应函数为 mem_encrypt.S::startup32_vc_handler`
  - 所有中断条目的信息在`arch/x86/include/asm/trapnr.h`
- 验证CPU支持长模式和SSE `arch/x86/kernel/verify_cpu.S::verify_cpu`
- 计算内核转移的开始地址，放到寄存器`ebx`中。（设置页表时要用）
- 设置`CR4`的`PAE`位为`1`（2M大页，地址布局为`2|9|9|12`） [PAE百科](https://en.wikipedia.org/wiki/Physical_Address_Extension)
- 设置内存加密的内容（不懂）
- 把整个页表的内存空间设置为`0`
  - 页表在`arch/x86/boot/compressed/head_64.S::pgtable`
  - 大小为 32*4 KB
- 设置4级页表具体内容
  - 第四级页表叫做`PML4 page map level 4`，对应的页是刚刚`pgtable`的第一个页。它的第一项指向`pgtable`的下一个页（三级页表的一个页），权限是`存在内存present、可写writable、用户可访问accessable`
  - 第三级页表叫做**页目录指针表**`PDPT Page Directory Pointer Table`。目前只有一个页，对应`pgtable`的第二个页。它的前4项分别指向`pgtable`的下四个页，权限是`存在内存present、可写writable、用户可访问accessable`
  - 第二级页表叫做**页目录**`PDT Page Directory Table`。目前有四个页，`pgtable`的第3-6个页。这4个页的每一项（4*512=2048项）指向对应的内存空间（2048项 * 2M每个页 = 4G，所以现在可用的空间为4G），每个页的权限是`存在内存present、可写writable、使用2M页、全局翻译（也就是进程切换的时候，不需要flush对应的TLB Entry）`
  - 第一级页表叫做**页表**`PT Page Table`。因为用的是2M的页，所以没有第一级页表（4k的页才有）。
- 把第4级页表（根）的地址放入寄存器`cr3`
- 设置寄存器`EFER (Extended Feature Enable Register)`的`LME`位为`1`（启动长模式，使用64位地址和4级页表）
- 设置本地描述符表为空（使用命令`lldt`）
- 设置任务寄存器的段描述符域为全局的`TSS`段描述符 `ltr`
- 设置内存加密的内容（不懂）
- 获取`startup_64`的地址（如果是EFI引导的，则获取`startup_64_mixed_mode`的地址）
- 把`startup_64`地址放入栈中，然后调用`lret`来跳转到`startup_64`运行


**`arch/x86/boot/compressed/head_64.S::startup_64`，是64位的代码**，具体内容如下:
- 清理`EFLAGS`的`DF`位 `CLD`
- 禁止硬件中断 `cli`
- 设置段寄存器
- 计算当前压缩内核的开始地址，放到寄存器`rbp`中。如果不是可重定向地址（调试状态），则地址为`LOAD_PHYSICAL_ADDR 0x1000000`
- 计算内核转移的开始地址，放到寄存器`ebx`中。
- 设置栈指针寄存器`esp`
- 再次设置全局描述符表（使用命令`lgdtl`）
- 跳转到`.Lon_kernel_cs`。这一步使用了`lretq`指令来跳转，为了设置CS段寄存器。
- 设置中断描述符表（第一阶段）（使用命令`lidt`）`arch/x86/boot/compressed/idt_64.c::load_stage1_idt`
  - 中断描述符表描述信息（地址、大小）在`head_64.S::boot_idt_desc`
  - 中断描述符表在`head_64.S::boot_idt`
  - 还会设置`VMM Communication Exception`的中断条目
    - `X86_TRAP_VC 对应函数为 boot_stage1_vc arch/x86/kernel/sev-shared.c::do_vc_no_ghcb`
  - 所有中断条目的信息在`arch/x86/include/asm/trapnr.h`
- 设置内存加密的内容（不懂）`boot_params::cc_blob_address`为`0` `arch/x86/boot/compressed/misc.h::sev_enable`
- 配置5级页表`arch/x86/boot/compressed/pgtable_64.c::configure_5level_paging`
  - 要先跳到32位，再设置，然后再调回64位
  - [控制寄存器百科](https://en.wikipedia.org/wiki/Control_register)
  - 设置`EFER`的`LME Long Mode Enable`位为`1`（开启四级页表）
  - 设置`CR4`的`LA57 57-Bit Linear Addresses`位为`1`（开启五级页表）
  - 设置`CR0`的`PG`位`1`（开启分页）
  - **现在好像还没有硬件有五级页表？**
- 把`EFLAGS`清零
- 拷贝压缩内核到前面计算的地址中
- 清理`EFLAGS`的`DF`位 `CLD`
- 再次设置全局描述符表（因为前面拷贝操作可能覆盖了全局描述符表）（使用命令`lgdtl`）
- 跳转到`.Lrelocated`
- 清理BBS（不懂）
- 设置中断描述符表（第二阶段）（使用命令`lidt`） `arch/x86/boot/compressed/idt_64.c::load_stage2_idt`
  - 设置`Page Fault`的中断条目
    - `X86_TRAP_PF 对应函数为 boot_page_fault arch/x86/boot/compressed/ident_map_64.c::do_boot_page_fault`
  - 设置`VMM Communication Exception`的中断条目
    - `X86_TRAP_VC 对应函数为 boot_stage2_vc arch/x86/kernel/sev.c::do_boot_stage2_vc`
- 再次设置页表内容 `arch/x86/boot/compressed/ident_map_64.c::initialize_identity_maps`
  - 页表所在位置`_pgtable`还是和上面一样，在`arch/x86/boot/compressed/head_64.S::pgtable`。详见连接文件`vmlinux.lds`。
  - 设置寄存器`cr3`（顶层页表的开始地址）
- 解压内核 `arch/x86/boot/compressed/misc.h::extract_kernel`
  - 解压的目的地址还是在`0x1000000`
  - `extract_kernel`返回程序的入口地址`0x1000080`（也就是`arch/x86/kernel/head_64.S::startup_64`）
- 跳转到刚刚返回的入口地址`0x1000080`（也就是`arch/x86/kernel/head_64.S::startup_64`）


### 内核初始化阶段
前面内容都可以认为是boot阶段，涉及linux的代码都在目录`arch/x86/boot`中。接下来的内容则是内核自己的初始化过程。（断点`b *0x1000080`）

**`arch/x86/kernel/head_64.S::startup_64`（注意不是`compressed`目录的`head_64.S`）**，具体内容如下:
- 移动`boot_params`的地址到`r15`
- 设置栈指针寄存器`esp`
- 修改`Model-Specific Register (MSR)`寄存器 `wrmsr`
- 设置全局描述符表GDT、中断描述符表IDT（操作和前面的设置差不多） `arch/x86/kernel/head64.c::startup_64_setup_env`
- 跳转到`.Lon_kernel_cs`运行
- 设置内存加密的内容（不懂）`arch/x86/mm/mem_encrypt_identity.c::sme_enable`
- 验证CPU支持长模式和SSE `arch/x86/kernel/verify_cpu.S::verify_cpu`
- 设置、修正新页表的内容，因为后面要把`内核所在的低位物理地址`映射到`高位虚拟地址 0xffffffff80000000` `arch/x86/kernel/head64.c::__startup_64`
  - 注意，新页表的信息位于`arch/x86/kernel/head_64.S::early_top_pgt/level4_kernel_pgt/level3_kernel_pgt/level2_fixmap_pgt`等，而不是之前的`arch/x86/boot/compressed/head_64.S::pgtable`
  - 判断是否为5级页表，是则设置一些变量
  - 设置内存加密的内容（不懂）
  - 修正地址`0xffffffff80000000`在早期顶级页表`early_top_pgt`的条目（就是第512项，最后一项）
    - 指向`level4_kernel_pgt`。
    - 如果不是五级页表，则指向`level3_kernel_pgt`，`level4_kernel_pgt`不会被使用，`early_top_pgt`就是4级页表。
    - 设置权限为`存在、可写、用户可访问`，具体详见`arch/x86/include/asm/pgtable_types.h::_PAGE_TABLE_NOENC`
  - 修正四级页表`level4_kernel_pgt`第512项（最后一项）
  - 修正三级页表`level3_kernel_pgt`的第511、512项（最后两项）
  - 修正二级页表`level2_fixmap_pgt`的第507、508项
  - 设置早期顶级页表`early_top_pgt`的条目指向早期动态页表`early_dynamic_pgts`
  - 设置、修正早期动态页表`early_dynamic_pgts`的三级页表、二级页表
  - 设置、修正早期动态页表`early_dynamic_pgts`的三级页表、二级页表
  - 修正二级页表`level2_kernel_pgt`
- 跳转到`secondary_startup_64_no_verify::1`
- 设置`cr4`寄存器的`MCE（Machine Check Error）`位为`1`
- 开启`cr4`寄存器的分页信息
  - [控制寄存器百科](https://en.wikipedia.org/wiki/Control_register)
  - [PSE百科](https://en.wikipedia.org/wiki/Page_Size_Extension)
  - 设置`CR4`的`PSE Page Size Extension`位为`1`（开启大页，4M大页，地址布局为`|10|10|12`）
  - 设置`CR4`的`PAE Physical Address Extension`位`1`（开启2M大页，地址布局为`2|9|9|12`）
  - 设置`CR4`的`PGE Page Global Enabled`位为`1`（开启全局地址转换）
  - 设置`CR4`的`LA57 57-Bit Linear Addresses`位为`1`（开启五级页表）
  - 注意目前为止还设置寄存器`cr3`（顶层页表的开始地址），所以使用的还是boot阶段设置的`arch/x86/boot/compressed/head_64.S::pgtable`
- 验证新的页表的地址，内存加密的内容（不懂）
- 切换到新的页表，即设置寄存器`cr3`为`early_top_pgt`（顶层页表的开始地址）
- 再次设置`CR4`的`PGE Page Global Enabled`位为`1`（开启全局地址转换），确保TLB已经flush
- 进行一次跳转操作，确保使用新的页表进行虚拟地址转换（跳转到高地址`0xffffffff81000145`）（**现在开始gdb可以找到对应的文件和行号信息，也就可以用clion进行调试，不用面对黑框了！！**）（断点`b *0xffffffff81000145`）

- 判断`boot loader`是否设置了`smpboot_control`的最高位，如果设置了，则说明是多CPU启动`SMP`（这里先不看SMP的内容）
- 单CPU启动，则跳转到`.Lsetup_cpu`运行
- 设置栈
- 设置全局描述符表（使用命令`lgdtl`）
- 设置段寄存器`ds/ss/es/fs/gs`
- 修改`Model-Specific Register (MSR)`寄存器第6位，不知道干嘛的 `wrmsr`
- 设置中断描述符表（使用命令`lidt`）`arch/x86/kernel/head64.c::early_setup_idt`
  - 中断描述符表描述信息（地址、大小）在`head64.c::bringup_idt_descr`
  - 中断描述符表在`head_64.S::bringup_idt_table`
  - 还会设置`VMM Communication Exception`的中断条目
    - `X86_TRAP_VC 对应函数为 arch/x86/kernel/head_64.S::vc_boot_ghcb`
  - 所有中断条目的信息在`arch/x86/include/asm/trapnr.h`
- 通过指令`cpuid`获取处理器信息
- 修改`Model-Specific Register (MSR)`寄存器 `wrmsr`
- 设置寄存器`EFER (Extended Feature Enable Register)`
  - 启动系统调用 `EFER_SCE`
  - 设置不可执行位 `EFER_NX`
- 设置寄存器`cr0`为`CR0_STATE`
  - 内容在`arch/x86/include/uapi/asm/processor-flags.h::CR0_STATE`
  - 内容`(X86_CR0_PE | X86_CR0_MP | X86_CR0_ET | X86_CR0_NE | X86_CR0_WP | X86_CR0_AM | X86_CR0_PG)`
  - 主要关心的内容为设置保护模式`PE Protected Mode Enable`、启动数学错误报告`NE Numeric error`、启动写保护`WP Write protect 不能写到只读页`、启动分页`PG`
- 清零`EFLAGS`
- 跳转到C语言代码`initial_code`，也就是`x86_64_start_kernel`继续运行。（断点`b x86_64_start_kernel`）

**`arch/x86/kernel/head64.c::x86_64_start_kernel`具体内容**如下:
- 获取`cr4`地址，放入`cpu_tlbstate.cr4`中 。 `arch/x86/include/asm/tlbflush.h::cr4_init_shadow`
- 早期顶级页表`early_top_pgt`的前面511项置为`0`，写入`cr3`中。 `arch/x86/kernel/head64.c::reset_early_page_tables`
- 把bss段`__bss_start - __bss_stop`和brk段`__brk_base - __brk_limit`置为`0`。 `clear_bss`
- 清理`init_top_pgt`页。 `clear_page`
- 设置内存加密的内容（不懂）`sme_early_init`
- 设置`CR4`的`PGE Page Global Enabled`位为`1`（开启全局地址转换）。`__native_tlb_flush_global`
- 设置中断描述符表为`arch/x86/kernel/head_64.S::early_idt_handler_array`。 `idt_setup_early_handler`
- TDX（机密计算相关）初始化（不懂） `tdx_early_init`
- 把`arch/x86/boot/main.c::boot_params`的数据拷贝到`arch/x86/kernel/setup.c::boot_param`中。`copy_bootdata`
- Load microcode early on BSP（不懂）`load_ucode_bsp`
- 设置`init_top_pgt`的最后一项为`early_top_pgt`的最后一项，相当于复制。因为`early_top_pgt`只有最后一项有值。
- 跳到方法`x86_64_start_reservations`
- 判断`boot_params`是否已经拷贝，之前没拷贝则调用`copy_bootdata`拷贝
- 初始化x86的一些值`arch/x86/kernel/x86_init.c::x86_platform`（未仔细看）`x86_early_init_platform_quirks`
- **调用`init/main.c::start_kernel`来初始化内核**。（断点`b start_kernel`）


**`init/main.c::start_kernel`的具体内容**如下:
- 设置第一个任务`task`（初始任务）的数据结构`init/init_task.c::struct task_struct init_task`的栈字段`task_struct::stack`为`STACK_END_MAGIC 0x57AC6E9D`，用于溢出检测。 `kernel/fork.c::set_task_stack_end_magic`
- 获取构建的build id，放到`lib/buildid.c::vmlinux_build_id`。 `lib/buildid.c::init_vmlinux_build_id`
- 初始化`cgroup`模块，主要是设置`kernel/cgroup/cgroup.c::cgroup_init_early`的静态变量`cgroup_fs_context ctx`的内容
  - 设置cgroup根`cgroup_fs_context.cgroup_root *root`为`kernel/cgroup/cgroup.c::cgrp_dfl_root`
  - 初始化cgroup根
    - 初始化子列表`cgroup_root->root_list`，指向自己，即子列表为空
    - 设置组数量`cgroup_root->nr_cgrps`设置为`1`
    - 设置根的cgroup的根`cgroup_root->cgrp->root`指向自己`cgroup_root`
    - 初始化根的cgroup`cgroup_root->cgrp`各种字段（兄弟节点、儿子节点、每个子系统等，大部分都为空） `kernel/cgroup/cgroup.c::init_cgroup_housekeeping`
  - 设置初始任务`init_task`的`cgroups`信息
  - 初始化每个子系统`cgroup_subsys`的信息
- 设置不允许本地中断 `cli`
- 初始化当前`cpu` `boot_cpu_init`
  - 递增cpu数量`__num_online_cpus`
  - 在`__cpu_active_mask`中设置当前cpu活跃
  - 在`__cpu_present_mask`中设置当前cpu存在
  - 在`__cpu_possible_mask`中设置当前cpu可能存在
  - 设置引导cpu`__boot_cpu_id`为当前cpu
- 初始化安全`security`模块
  - 设置`security/security.c::security_hook_heads`中各个类型的钩子列表为空
  - 准备`security/security.c::__start_early_lsm_info`各个安全模块信息，并运行它们的初始化函数`init`
- **设置架构指定的内容，x86则运行`arch/x86/kernel/setup.c::setup_arch`的代码。很多内容，在后面单独列出。**
- 设置bootconfig。`init/main.c::setup_boot_config`
- 设置命令行参数（把命令行参数拷贝到新的位置）。`init/main.c::setup_command_line`
- 设置每个CPU的区域。`arch/x86/kernel/setup_percpu.c::setup_per_cpu_areas`
- 调用boot-cpu的钩子`hooks`。
- 设置CPU热插拔
- 初始化跳转符号（Jump Label）表`__start___jump_table - __stop___jump_table`。`kernel/jump_label.c::jump_label_init`
- 解析命令行参数。`init/main.c::parse_early_param`
- 设置日记buf。`kernel/printk.c::setup_log_buf`
- 初始化虚拟文件系统（新建dcache和inode使用的hashtable）。`fs/dcaches.c::vfs_caches_init_early`
- 排序异常表。`kernel/extable.c::sort_main_extable`
- 初始化trap。`arch/x86/kernel/traps.c::trap_init`
- 初始化内存分配器。`mm/mm_init.c::mm_core_init`
- 初始化poking。`arch/x86/mm/init.c::poking_init`
- 初始化ftrace（内核空间的调试工具）。`kernel/trace/ftrace.c::ftrace_init`
- 初始化trace（内核数据跟踪）。`kernel/trace/trace.c::early_trace_init`
- 初始化调度相关内容。`kernel/sched.c::sched_init`
- 初始化基数树（基数树radix tree是将指针与long 整数键值相关联的机制）。`lib/radix-tree.c::radix_tree_init`
- 初始化maple树（好像是用来取代红黑树的）。`lib/maple_tree.c::maple_tree_init`
- 初始化housekeeping（任务隔离相关）。`kernel/sched/isolation.c::housekeeping_init`
- 初始化workqueue（一个进程，用于执行延时异步操作）。`kernel/workqueue.c::workqueue_init_early`
- 初始化rcu（Read-Copy Update 读拷贝更新机制，一种同步机制）。`kernel/rcu/tree.c::rcu_init`
- 初始化trace（内核数据跟踪）。`kernel/trace/trace.c::trace_init`
- 初始化IRQ（Interrupt ReQuest 来自设备的中断请求）。`kernel/irq/irqdesc.c::early_irq_init`和`arch/x86/kernel/irqinit.c::init_IRQ`
- 初始化tick（tick是时间片轮转调度以及延迟操作的时间度量单位）。`kernel/time/tick-common.c::tick_init`
- 初始化timers（计时相关）。`kernel/time/timer.c::init_timers`
- 初始化srcu（Sleepable Read-Copy Update 可睡眠的读拷贝更新机制）。
- 初始化hrtimers（high resolution timer 高精度定时器）。`kernel/time/hrtimer.c::hrtimers_init`
- 初始化软中断。`kernel/softirq.c::softirq_init`
- 初始化时间模块。`kernel/time/timekeeping.c::timekeeping_init`、`arch/x86/kernel/time.c::time_init`
- 初始化随机数相关内容。`drivers/char/random.c::random_init`
- 初始化kfence的内容（用于捕获内核及内核模块的内存污染问题）。`mm/kfence/core.c::kfence_init`
- 初始化栈保护的内容。`arch/x86/include/asm/stackprotector.h::boot_init_stack_canary`
- 初始化perf event（对用户态提供软硬件性能数据的一个统一的接口）。`kernel/events/core.c::perf_event_init`
- 初始化profile（监控性能）。`kernel/profile.c::profile_init`
- 初始化call function。（不知道作用）`kernel/smp.c::call_function_init`
- 启动中断（使用`sti`命令）。`arch/x86/include/asm/paravirt.h::arch_local_irq_enable`
- 初始化`kmem_cache`。`mm/slub.c::kmem_cache_init_late`
  - kmem_cache是slab的核心结构体，主要描述slab的各种信息和链接空闲slab，还保存高速缓存的指针数组
  - slab是伙伴系统下的更细粒度的内存分配器
- 初始化控制台设备。`kernel/printk.c::console_init`
- 初始化每个CPU的页集合pageset（每个CPU自己的页缓存，避免每次都跟伙伴系统申请页）。`mm/page_alloc.c::setup_per_cpu_pageset`
- 初始化numa策略。`mm/mempolicy.c::numa_policy_init`
- 初始化ACPI。`drivers/acpi/bus.c::acpi_early_init`
- 初始化late time。`arch/x86/kernel/time.c::x86_late_time_init`
- 初始化调度时钟Scheduling Clock。`kernel/sched.c::sched_clock_init`
- 初始化calibrate delay校准延迟。`init/calibrate.c::calibrate_delay`
- 结束初始化CPU。`arch/x86/kernel/cpu/common.c::arch_cpu_finalize_init`
- 初始化整数ID管理机制。`kernel/pid.c::pid_idr_init`
- 初始化匿名反向映射的内容（页表可以说是`虚拟页->物理页`正向映射，这里是`物理页->虚拟页`反向映射）。`mm/rmap.c::anon_vma_init`
- 初始化证书`credential`相关内容。`kernel/cred.c::cred_init`
- 初始化fork相关内容（设置最大进程数、初始化init_task进程等）。`kernel/fork.c::fork_init`
- 初始化进程缓存（创建新进程需要的数据）。`kernel/fork.c::proc_caches_init`
- 初始化UTS（Time-Sharing System 提供了对两个系统标识符的隔离：主机名和NIS`网络信息服务`域名）。`kernel/utsname.c::uts_ns_init`
- 初始化秘钥（key）管理的内容。`security/keys.c::key_init`
- 初始化安全框架。`security/security.c::security_init`
- 初始化调试（gdb）相关内容。`kernel/debug/debug_core.c::dbg_late_init`
- 初始化网络命名空间。`net/core/net_namespace.c::net_ns_init`
- 初始化虚拟文件系统`vfs`的缓存内容。`fs/dcache.c::vfs_caches_init`
- 初始化页缓存的内容。`mm/filemap.c::pagecache_init`
- 初始化signal信号相关内容。`kernel/signal.c::signals_init`
- 初始化Sequence file（序列文件，把信息导出到用户空间。和proc差不多？为了取代proc？）。`fs/seq_file.c::seq_file_init`
- 初始化proc内容（提供内核与用户进行交互的平台，方便用户实时查看进程的信息）。`fs/root.c::proc_root_init`
- 初始化nsfs文件系统。`fs/nsfs.c::nsfs_init`
- 初始化cpusets（用于CPU资源的划分和进程的绑定）。`kernel/cgroup/cpuset.c::cpuset_init`
- 初始化cgroup（用于资源划分和隔离）。`kernel/cgroup/cgroup.c::cgroup_init`
- 初始化task status（用于从内核向用户空间发送任务及进程的统计信息）。`kernel/taskstats.c::taskstats_init_early`
- 初始化delay account延迟计数（统计等待系统资源的时间）。`kernel/delayacct.c::delayacct_init`
- 初始化ACPI子系统。`drivers/acpi/bus.c::acpi_subsystem_init`和`arch/x86/kernel/process.c::arch_post_acpi_subsys_init`
- 初始化其余的内容。`init/main.c::arch_call_rest_init -> rest_init`
  - `kernel/sched/core.c::schedule_preempt_disabled`会创建1号进程（当前为0号进程），1号进程则按需启动其他进程。
  - `kernel/sched/idle.c::cpu_startup_entry`里面有一个不会退出的循环，不断调用`do_idle`。当CPU空闲时，调度器就会调度该idle进程（0号进程）进行操作（具体操作未看）。


**`arch/x86/kernel/setup.c::setup_arch`的内容**:
- 打印命令行参数
- 设置中断描述符表为`arch/x86/kernel/idt.c::idt_table`。`arch/x86/kernel/idt.c::idt_setup_from_table`
  - 设置调试、断点、虚拟化异常的中断条目`arch/x86/kernel/idt.c::early_idts`
  - 使用命令`lidtl`完成设置
- 初始化cpu。`arch/x86/cpu/common.c::early_cpu_init`
  - 把`__x86_cpu_dev_start`开始的内容设置到`arch/x86/cpu/common.c::cpu_devs`
  - CPU侦探，获取CPU相关信息（厂商、性能、地址位数等）
- 初始化跳转符号（Jump Label）表`__start___jump_table - __stop___jump_table`。`kernel/jump_label.c::jump_label_init`
- 初始化静态调用表。`kernel/static_call_init.c::static_call_init`
- 初始化`ioremap`相关信息，`ioremap`用于映射外设寄存器到内存。`arch/x86/mm/ioremap.c::early_ioremap_init`
- 设置屏幕相关信息（`screen_info`、`edid_info`、`saved_video_mode`）
- 设置`bootloader`相关信息。
- 保留一些物理内存到`memblock`: 内核相关的内存、前64K、初始RAM磁盘（initrd）的空间、启动阶段setup的数据、BIOS的区域、`Sandy Bridge graphics`的区域。`arch/x86/kernel/setup.c::early_reserve_memory`
- 初始化BIOS提供的e820内存信息。`arch/x86/kernel/e820.c::e820__memory_setup`
- 解析boot阶段传过来的setup数据。`boot_params.hdr.setup_data`。`arch/x86/kernel/setup.c::parse_setup_data`
- 复制BIOS的EDD数据`Enhanced Disk Drive`。`arch/x86/kernel/setup.c::copy_edd`
- 设置内核各个段的地址（text、rodata、data、bss）
- 复制命令行参数。`lib/string.c::strscpy`
- 解析命令行参数。`init/main.c::parse_early_param`
- 保留BIOS提供的e820内存到`memblock`。`arch/x86/kernel/e820.c::e820__reserve_setup_data`
- 设置DMI（Direct Media Interface 直接媒体接口）系统信息 `drivers/firmware/dmi_scan.c::dmi_setup`
- 初始化`hypervisor`相关信息（内核运行在虚拟机时）。`arch/x86/cpu/hypervisor.c::init_hypervisor_platform`
- 初始化TSC（时间戳计数器，Time Stamp Counter）。`arch/x86/kernel/tsc.c::tsc_early_init`
- 侦探ROM内存，加入到资源信息`iomem_resource`中。`arch/x86/kernel/probe_roms.c::probe_roms`
- 把刚刚设置的内核各个段地址信息加入到资源信息`iomem_resource`中
- 添加内核和BIOS的内存段到资源信息`iomem_resource`中。
- 检测GART（Graphic Address Remapping Table）（I/O memory management unit IOMMU，GPU相关内容）。`arch/x86/kernel/aperture_64.c::early_gart_iommu_check`
- 设置MTRR（Memory Type Range Register）和PAT（页面属性表Page Attribute Table）。和内存访问权限有关。`arch/x86/kernel/cpu/cacheinfo.c::cache_bp_init`
- 检测`x2apic`是否启用。（x2apic是一种高级中断控制器特性。 它可以使硬件中断控制更高效，从而提高系统性能。）`arch/x86/kernel/apic/apic.c::check_x2apic`
- 找boot阶段的SMP配置（Symmetrical Multi-Processing 对称多处理）。`arch/x86/kernel/mpparse.c::default_find_smp_config`
- 分配页表，这里只分配空间，后面会使用。`arch/x86/mm/init.c::early_alloc_pgt_buf`
- 保留brk申请的内存到`memblock`。`arch/x86/kernel/setup.c::reserve_brk`
- 清理未使用的页表项，只保留地址`_text`到`_brk_end`之间的页表。注意这里使用的页表还是`arch/x86/kernel/head_64.S::startup_64`设置的页表。`arch/x86/mm/init_64.c::cleanup_highmap`
- 再次设置保留的内存`memblock`
- 设置内存加密的内容。（未看）`arch/x86/mm/mem_encrypt.c::mem_encrypt_setup_arch`
- 设置efi（Extensive Firmware Interface 可拓展固件接口）的内容。（未看）`efi_ 开头的多个方法`
- BIOS损坏检测。`arch/x86/kernel/check.c::setup_bios_corruption_check`
- 保留实模式涉及的内存到`memblock`。`arch/x86/realmode/init.c::reserve_real_mode`
- 初始化内存映射信息。`arch/x86/realmode/init.c::init_mem_mapping`
  - 像`arch/x86/kernel/head_64.S::startup_64`一样设置页表管理相关的寄存器
  - 设置一些内存的页表项
  - 设置CR3为`init_top_pgt`，之前是`early_top_pgt`
- 添加`Page Fault`中断描述符条目到`arch/x86/kernel/idt.c::idt_table`。 `arch/x86/kernel/idt.c::idt_setup_early_pf`
- 获取CR4寄存器的内容放到`mmu_cr4_features`
- 设置日记buf。`kernel/printk.c::setup_log_buf`
- 保留初始RAM磁盘（initrd）的内存到`memblock`。（有relocate操作）`arch/x86/kernel/setup.c::reserve_initrd`
- 设置ACPI表（Advanced Configuration and Power Interface 高级配置与电源接口）。`drivers/acpi/tables.c::acpi_table_upgrade`
- 保留ACPI表的内存到`memblock`。`arch/x86/kernel/acpi/tables.c::acpi_boot_table_init`
- 初始化vsmp（未看）
- 检测系统的DMI（Direct Media Interface 直接媒体接口）数据。`arch/x86/kernel/io_delay.c::io_delay_init`
- 初始化ACPI。`arch/x86/kernel/acpi/boot.c::early_acpi_boot_init`
- 初始化内存（这里只初始化numa相关内容）。`arch/x86/mm/numa_64.c::initmem_init -> arch/x86/mm/numa.c::x86_numa_init`
- 为crash kernel保留内存（不懂）。`arch/x86/kernel/setup.c::arch_reserve_crashkernel`
- 计算DMA需要的内存，把结果保存在`mm/mm_init.c::dma_reserve`。`arch/x86/mm/init.c::memblock_find_dma_reserve`
- 设置xdbc（不懂）。
- 初始化分页相关信息。（未认真看）`arch/x86/mm/init_64.c::paging_init`
- tboot（启动环境测量）侦探。`arch/x86/kernel/tboot.c::tboot_probe`
- 映射vsysall（虚拟系统调用、快速系统调用）。`arch/x86/entry/vsyscall/vsyscall_64.c::map_vsyscall`
  - 设置`arch/x86/entry/vsyscall/vsyscall_64.c::gate_vma::vm_flags`为`VM_EXEC`
- 检测PCI设备，结果放在`early_qrk`。`arch/x86/kernel/early-quirks.c::early_quirks`
- 初始化ACPI。`arch/x86/kernel/acpi/boot.c::acpi_boot_init`
- 初始化ACPI映射。`arch/x86/kernel/acpi/apic.c::init_apic_mappings`
- 预填充CPU相关的mask。`arch/x86/kernel/smpboot/smpboot.c::prefill_possible_map`
- 设置CPU到对应的numa节点。`arch/x86/mm/numa.c::init_cpu_to_node`
- 添加e820的信息到资源信息`iomem_resource`中。`arch/x86/kernel/e820.c::e820__reserve_resources`
- 保留IO资源到资源信息`ioport_resource`中。`arch/x86/kernel/setup.c::reserve_standard_io_resources`
- 其他 // TODO

