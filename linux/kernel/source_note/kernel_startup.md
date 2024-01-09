## Linux内核启动流程

[The Linux/x86 Boot Protocol](https://docs.kernel.org/arch/x86/boot.html)
《Linux内核源代码情景分析》第10章
[Linux内核的引导启动](https://frankjkl.github.io/2019/03/12/Linux%E5%86%85%E6%A0%B8-%E5%BC%95%E5%AF%BC%E5%90%AF%E5%8A%A8/)

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
- `arch/x86/boot/compressed/vmlinux.bin`是有根目录的`vmlinux`去除调试等相关信息而成
- `arch/x86/boot/compressed/vmlinux.bin.zst`是`arch/x86/boot/compressed/vmlinux.bin`压缩而成
- **`arch/x86/boot/compressed/vmlinux`**是目录`arch/x86/boot/compressed`的代码加上**压缩的内核代码`arch/x86/boot/compressed/vmlinux.bin.zst`组成（在`piggy.S`的`input_data`中）**。
- `arch/x86/boot/vmlinux.bin`是由`arch/x86/boot/compressed/vmlinux`去除调试等相关信息而成
- `arch/x86/boot/vmlinux.bin`是由`arch/x86/boot/setup.bin`、`arch/x86/boot/arch/x86/boot/vmlinux.bin`、`arch/x86/boot/zoffset.h`打包而成


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
- 切换到新的页表，即设置寄存器`cr3`（顶层页表的开始地址）
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
- 设置架构指定的内容，x86则运行`arch/x86/kernel/setup.c::setup_arch`的代码。很多内容。
  - // TODO
- 


