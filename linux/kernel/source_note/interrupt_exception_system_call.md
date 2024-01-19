## 中断、异常、系统调用
《Linux Kernel Development》
  - 第5章 System Calls
  - 第7章 Interrupts and Interrupt Handlers
  - 第8章 Bottom Halves and Deferring Work
《Linux内核源代码情景分析》
  - 第3章 中断、异常和系统调用
《Professional Linux Kernel Architecture》
  - 第13章 System Calls
  - 第14章 Kernel Activities
《Understanding the Linux Kernel》
  - 第4章 Interrupts and Exceptions
  - 第10章 System Calls
  - 第11章 Signals

### 中断`interrupt`、异常`exception`的区别
- 中断`interrupt`来源
  - 外部硬件设备发出的中断，比如网卡准备就绪。
  - 由CPU运行的指令发出，比如X86的`INT n`指令，恢复后，会执行下一条指令。
- 异常`exception`来源
  - 由CPU侦探到异常状态触发，比如除0异常，`Page fault`
  - 由CPU运行的指令发出，比如X86的`INT0/INT1/INT3/BOUND`指令，恢复后，会执行下一条指令。
  - 机器检测异常

异常`exception`分类
- Faults: 中断处理程序返回后，**会重新执行一次产生异常的指令**，比如`Page fault`缺页中断完成后，会继续执行对应的内存读写操作。
- Traps: 中断处理程序返回后，会执行产生异常的指令的下一条指令，比如`INT $0x80`系统调用完成后，会执行系统调用的下一条指令。
- Aborts: 报告对应信息后，直接终止程序，不能恢复程序。

x86提供的门gate：
- 任务门：用于切换任务，在GDT、LDT或IDT中。**linux不使用该机制来切换任务**。
- 中断门：用于处理硬件中断，**在IDT中**
- 陷阱门：用于处理软件中断（陷阱trap、异常exception），**在IDT中**
- 调用门：用于系统调用，在GDT、LDT中，**不在IDT中**。**linux不使用该机制来进行系统调用**，而是用中断和`sysenter/syscall`进行系统调用。

Linux在X86的实现使用了`中断门`和`陷阱门`，主要使用`中断门`，少量使用`陷阱门`。


### IDT（中断描述符表）
初始化代码主要在:
```
arch/x86/kernel/traps.c::trap_init
kernel/irq/irqdesc.c::early_irq_init
arch/x86/kernel/irqinit.c::init_IRQ
```

IDT的初始信息在:
```
arch/x86/kernel/idt.c::struct idt_data early_idts
arch/x86/kernel/idt.c::struct idt_data def_idts
arch/x86/kernel/idt.c::struct idt_data ia32_idt
arch/x86/kernel/idt.c::struct idt_data apic_idts
arch/x86/kernel/idt.c::struct idt_data early_pf_idts
```

每个中断向量标号对应的中断处理函数在`arch/x86/include/asm/idtentry.h`的宏`DECLARE_IDTENTRY_*`中**声明**。
每个实际工作的Linux中断函数都会生成一个以`asm_`和`xen_asm_`开头的函数名。
比如`X86_TRAP_NP`对应的函数为`exc_segment_not_present`，在`arch/x86/include/asm/idtentry.h`会声明函数`asm_exc_segment_not_present`、`xen_asm_exc_segment_not_present`、`exc_segment_not_present`。

每个中断向量标号对应的中断处理函数的C语言部分（即实际操作）在`arch/x86/kernel/traps.c`中**定义**（注意，定义使用了`arch/x86/include/asm/idtentry.h`的宏`DEFINE_IDTENTRY_*`）。
比如`X86_TRAP_NP`对应的函数为`exc_segment_not_present`，在`arch/x86/kernel/traps.c`会使用`DEFINE_IDTENTRY_ERRORCODE(exc_segment_not_present)`定义`exc_segment_not_present`C语言函数。

每个中断向量标号对应的中断处理函数的汇编语言部分（即以`asm_`开头的汇编语言函数，比如`asm_exc_segment_not_present`）在`arch/x86/entry/entry_64.S`**定义**，主要在下列宏中：
```
.macro idtentry_irq
.macro idtentry
.macro idtentry_body
```

还有以`xen_asm_`开头的函数在`arch/x86/xen/xen-asm.S`中定义，在宏`.macro xen_pv_trap`中。

IDT的条目只有256项，前32条为CPU保留的，后面`224`条不能满足所有外部设备的中断请求，所以需要把第255项（最后一项）设置为通用项，对应的中断处理函数为`common_interrupt`（定义在`arch/x86/kernel/irq.c`）。函数`common_interrupt`通过传过来的向量号，在表`arch/x86/include/asm/hw_irq.h::vector_irq`中获取对应的中断描述信息（包括中断处理函数）进行运行。调用路径（倒序）如下：
```
timer_interrupt time.c:57 // 具体的中断处理函数，这里`timer_interrupt`是计时器中断的处理函数
__handle_irq_event_percpu handle.c:158 // 这一步调用中断描述信息中的`struct irqaction	*action`中的`irq_handler_t	 handler`，即具体的中断处理函数
handle_irq_event_percpu handle.c:193
handle_irq_event handle.c:210
handle_level_irq chip.c:648
generic_handle_irq_desc irqdesc.h:161 // 这一步调用中断描述信息中的函数`handle_irq`
handle_irq irq.c:238
__common_interrupt irq.c:257 // 这一步从vector_irq获取对应的中断描述信息`struct irq_desc`
common_interrupt irq.c:247
asm_common_interrupt idtentry.h:640
<unknown> 0x0000000000000000
```


### 系统调用
X86系统调用可以**通过中断（中断编号为`0x80`）来实现**，也可以**通过专有命令`sysenter/sysexit`（32位）和`syscall/sysret`（64位）来实现**。
x86_64系统调用表定义在`arch/x86/entry/syscall_64.c::sys_call_table`，arm64系统调用表定义在`arch/arm64/kernel/sys.c::sys_call_table`。


#### 通过中断实现系统调用（中断编号为`0x80`）
X86系统调用在中断编号`IA32_SYSCALL_VECTOR 0x80`中，初始化代码在`arch/x86/kernel/idt.c::idt_setup_traps`，初始化信息为`arch/x86/kernel/idt.c::ia32_idt::SYSG(IA32_SYSCALL_VECTOR,	asm_int80_emulation)`。

中断编号`IA32_SYSCALL_VECTOR 0x80`对应的中断处理函数为`asm_int80_emulation`，在`arch/x86/include/asm/idtentry.h`中**声明**函数`asm_int80_emulation`、`xen_asm_int80_emulation`、`int80_emulation`。

在`arch/x86/entry/common.c`中**定义**`IA32_SYSCALL_VECTOR`对应的函数为`int80_emulation`。

`arch/x86/entry/common.c::int80_emulation`通过下面调用链**获取系统调用编号对应的处理函数，并运行它**。
```
arch/x86/entry/common.c::int80_emulation
arch/x86/entry/common.c::do_syscall_32_irqs_on
arch/x86/entry/syscall_32.c::ia32_sys_call_table
具体的系统调用处理函数（详见下文**系统调用处理函数的代码结构**）
```


#### 通过专有命令实现系统调用 `sysenter/sysexit`（32位）和`syscall/sysret`（64位）
函数`arch/x86/kernel/traps.c::trap_init -> arch/x86/kernel/cpu/common.c::cpu_init -> arch/x86/kernel/cpu/common.c::syscall_init`使用指令`WRMSR`设置寄存器`IA32_LSTAR`（也叫`MSR_LSTAR`）为`arch/x86/entry/entry_64.S::entry_SYSCALL_64`。即系统调用的处理函数为`arch/x86/entry/entry_64.S::entry_SYSCALL_64`。

`arch/x86/entry/entry_64.S::entry_SYSCALL_64`通过下面调用链**获取系统调用编号对应的处理函数，并运行它**。
```
arch/x86/entry/entry_64.S::entry_SYSCALL_64
arch/x86/entry/common.c::do_syscall_64
arch/x86/entry/common.c::do_syscall_x64
arch/x86/entry/syscall_64.c::sys_call_table[系统调用号]
具体的系统调用处理函数（详见下文**系统调用处理函数的代码结构**）
```

#### 系统调用处理函数的代码结构（以`read`为例）
每个系统调用都由宏`include/linux/syscall.h::SYSCALL_DEFINE<N>`定义，其中`<N>`指该系统调用的参数数量。

比如系统调用`read`的定义在`fs/read_write.c`，具体内容：
定义的代码
```
SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count){ 省略内容 }
```

`SYSCALL_DEFINE<N>`会创建相关元数据:
- 参数类型名数组 `types__read`
- 参数变量名数组 `args__read`
- 进入、退出系统调用的元数据`event_enter__read`、`event_exit__read`，和对应指针`__event_enter__read`、 `__event_exit__read`
- 系统调用元数据`__syscall_meta__read`，和对应指针`__p_syscall_meta__read`。

`SYSCALL_DEFINE<N>`还会创建对应方法:
- 体系结构对应的全局函数（对外可见） `__x64_sys_read`、`__ia32_sys_read`
- 本地内部（static）的函数 `__se_sys_read`
- 实际工作的函数 `__do_sys_read`

对外可见的函数`__x64_sys_read和__ia32_sys_read`调用内部（static）函数`__se_sys_read`完成操作
内部（static）函数`__se_sys_read`调用实际工作的`__do_sys_read`完成具体操作后，进行一些其他操作（没具体看），再返回

