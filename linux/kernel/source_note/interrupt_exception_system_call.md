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


### 中断`interrupt`、异常`exception`相关信息
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

注意，虽然中断和异常有很多分类、区别，但是实际上都是通过**中断机制**来实现，所以Linux实现的时候不按照上文那样详细地分类。


### 中断的基本流程
外部设备发送一个中断信号到中断控制器，中断控制器记录相关信息并发送中断信号给CPU，CPU停止当前运行的任务，在**中断描述符表**查询对应的中断描述符项，跳转到对应的中断处理器来运行。**中断描述符表**的信息见下文。

中断处理器（Interrupt Handler）也叫中断服务例程（interrupt service routine ISR）。

资料：[漫谈中断（一）：PIC](https://r12f.com/posts/interrupts/)


### 中断描述符表（也叫中断向量表）（IDT Interrupt Descriptor Table）
中断的类型、编号在文件`arch/x86/include/asm/trapnr.h`和`arch/x86/include/asm/irq_vectors.h`中。

**中断描述符表的每一项**在X86叫做门（gate）。x86提供的中断相关的门有`中断门`和`陷阱门`。Linux主要使用`中断门`，少量使用`陷阱门`。

中断描述符表初始化操作主要在下面的函数中:
```
arch/x86/kernel/traps.c::trap_init
kernel/irq/irqdesc.c::early_irq_init
arch/x86/kernel/irqinit.c::init_IRQ
```

中断描述符表的初始化信息在下面的变量中，它们全部被赋值到中断描述符表`arch/x86/kernel/idt.c::struct idt_data idt_table`。
```
arch/x86/kernel/idt.c::struct idt_data early_idts
arch/x86/kernel/idt.c::struct idt_data def_idts
arch/x86/kernel/idt.c::struct idt_data ia32_idt
arch/x86/kernel/idt.c::struct idt_data apic_idts
arch/x86/kernel/idt.c::struct idt_data early_pf_idts
```

中断描述符表`arch/x86/kernel/idt.c::struct idt_data idt_table`的条目只有256项，前32条为CPU保留的，还有一些是APIC确定的，剩下的项不能满足所有外部设备的中断请求。所以在`arch/x86/kernel/idt.c::idt_setup_apic_and_irq_gates`把空余的（未设置的）项全设置为通用项`arch/x86/include/asm/idtentry.h::irq_entries_start`。然后通用项`irq_entries_start`调用`asm_common_interrupt/common_interrupt`，根据传过来的编号，在表`arch/x86/include/asm/hw_irq.h::vector_irq`中获取对应的中断描述信息（包括中断处理器）来运行。


### 中断处理器的定义和注册
从上文的`中断描述符表`，我们知道中断描述符表的每一项有2种情况，它们有不同的定义方式。
- 一些CPU保留、APIC确定的项，下文称做`普通的中断处理器`
- 通用项的中断处理器主要在`arch/x86/include/asm/idtentry.h::irq_entries_start`

#### 普通的中断处理器
上文`初始化中断描述符表`就是`普通的中断处理器`的注册操作。注册时提供的函数指针，它们的声明和定义如下所示。

中断向量编号对应的中断处理器在`arch/x86/include/asm/idtentry.h`的宏`DECLARE_IDTENTRY_*`中**声明**。会生成一个以`asm_`和`xen_asm_`开头的函数名。
比如`X86_TRAP_NP`对应的函数为`exc_segment_not_present`，在`arch/x86/include/asm/idtentry.h`会声明函数`asm_exc_segment_not_present`、`xen_asm_exc_segment_not_present`、`exc_segment_not_present`。

每个中断向量编号对应的中断处理器的C语言部分（即实际操作）在`arch/x86/kernel/traps.c`中**定义**（注意，定义使用了`arch/x86/include/asm/idtentry.h`的宏`DEFINE_IDTENTRY_*`）。
比如`X86_TRAP_NP`对应的函数为`exc_segment_not_present`，在`arch/x86/kernel/traps.c`会使用`DEFINE_IDTENTRY_ERRORCODE(exc_segment_not_present)`定义`exc_segment_not_present`C语言函数。

每个中断向量编号对应的中断处理器的汇编语言部分（即以`asm_`开头的汇编语言函数，比如`asm_exc_segment_not_present`）在`arch/x86/entry/entry_64.S`**定义**，主要在下列宏中：
```
.macro idtentry_irq
.macro idtentry
.macro idtentry_body
```

还有以`xen_asm_`开头的函数在`arch/x86/xen/xen-asm.S`中**定义**，在宏`.macro xen_pv_trap`中。

#### 通用项`irq_entries_start`的中断处理器
通用项`irq_entries_start`的注册和上文普通的中断处理器一样，不过通用项`irq_entries_start`里面`具体外设的中断处理器`则要进行自己的注册处理。

使用函数`request_irq`和`free_irq`设置表`arch/x86/include/asm/hw_irq.h::vector_irq`的内容。
- 注册一个外设中断 `include/linux/interrupt.h::request_irq`
  - 函数参数`irq_handler_t handler`就是中断处理器。
  - 中断处理器的函数类型为 `static irqreturn_t intr_handler(int irq, void *dev)`
- 释放一个外设中断 `kernel/irq/manage.c::free_irq`

对外设中断进行处理的时候，通用项`irq_entries_start`调用`asm_common_interrupt/common_interrupt`，根据传过来的编号，在表`arch/x86/include/asm/hw_irq.h::vector_irq`中获取对应的中断描述信息（包括中断处理器）来运行。调用过程如下：
```
arch/x86/include/asm/idtentry.h::irq_entries_start
arch/x86/include/asm/idtentry.h::asm_common_interrupt
arch/x86/kernel/irq.c::common_interrupt
arch/x86/kernel/irq.c::__common_interrupt // 这一步从vector_irq获取对应的中断描述信息`struct irq_desc`
arch/x86/kernel/irq.c::handle_irq
include/linux/irqdesc.h::generic_handle_irq_desc // 这一步调用中断描述信息中的函数`handle_irq`
hkernel/irq/chip.c::handle_level_irq
kernel/irq/handle.c::handle_irq_event
kernel/irq/handle.c::handle_irq_event_percpu
kernel/irq/handle.c::__handle_irq_event_percpu // 这一步调用中断描述信息中的`struct irqaction	*action`中的`irq_handler_t handler`，即具体的中断处理器
arch/x86/kernel/time.c::timer_interrupt // 具体的中断处理器，这里`timer_interrupt`是计时器中断的处理器
```


### 中断处理器的具体工作
中断处理至少要满足2个目标
- 快速执行、响应中断
- 执行大量的操作

这2个目标是互相矛盾的，想快速执行就不能做太多的工作。所以中断处理分成上下两部分，`top halves`和`bottom halves`。CPU执行完上半部分后，就立刻返回`已完成`的信息给中断源。之后就进行其他操作，等以后再通过调度来执行下半部分。
- 上半部分`top halves`执行时间敏感的操作（立即执行的操作）。内容主要有：
  - 时间敏感的操作
  - 和硬件设备相关的操作
  - 不想让其他中断打断的工作
- 下半部分`bottom halves`执行时间不敏感的操作（推迟执行的操作）

比如一个网卡发起的中断信息，通知CPU数据包准备好了，对应的操作为：
- 上半部分：确认信息、把数据包从网卡拷贝到主存
- 下半部分：整理、处理刚刚拷贝的数据包等操作

上半部分的操作就是前面注册的中断处理器的内容。接下来主要看下半部分。

#### 中断处理下半部分`bottom halves`
中断处理下半部分`bottom halves`的机制主要有：
- 下半部分 `Bottom Half` `BH`（**这个方法已经弃用了**）
  - 最开始的时候，只有这一种机制，所以起了这个名字
  - 维护一个`int`列表来记录是否需要执行下半部分，一个int值只有32位，所以只能有32个处理器。
  - 如果需要执行下半部分，则在上半部分`top halves`设置对应的位为1
- 任务队列 `Task Queues`（**这个方法也已经弃用了**，现在改成使用**工作队列`Work Queue`**）
  - 维护一系列的队列，每个队列对应的运行时间不同
  - 设备驱动根据自己的情况往某个队列中注册自己的中断处理下半部分任务
- 软中断 `Softirqs`
  - 只能在编译器静态决定软中断的内容
- 任务片段 `Tasklets`
  - 任务片段`Tasklets`和任务`task`（进程`process`）没关系
  - 可以把`Tasklets`理解为灵活、动态、易于使用、不能并行运行的软中断`Softirqs`
- 工作队列 `Work Queue`
- 计时器中断`timer interrupt`，适合固定延迟时间的工作。详见`time_management.md`。

所以目前在用的机制有4种：`Softirqs`、`Tasklets`、`Work Queue`、`timer interrupt`

##### 软中断`Softirqs`的内容
多个CPU可以并行运行**同一个软中断处理器**，意味着软中断处理器里面操作共享数据时要注意同步操作，注意是**同一个软中断处理器可以被多个CPU运行**。当然，**不同软中断处理器的共享数据和同步问题本来就要注意**。

目前只剩9个软中断，存储在数组`kernel/softirq.c::softirq_vec`中，对应的类型在`include/linux/interrupt.h的枚举NR_SOFTIRQS`中。数组`softirq_vec`每一项的类型`struct softirq_action`里面只有一个函数指针。每个指针可以叫软中断处理器？

软中断`Softirqs`的类型:
- HI_SOFTIRQ High-priority tasklets
- TIMER_SOFTIRQ Timers
- NET_TX_SOFTIRQ Send network packets
- NET_RX_SOFTIRQ Receive network packets
- BLOCK_SOFTIRQ Block devices
- TASKLET_SOFTIRQ Normal priority tasklets
- SCHED_SOFTIRQ Scheduler
- HRTIMER_SOFTIRQ High-resolution timers
- RCU_SOFTIRQ RCU locking

注册一个软中断的方法：
- 在`include/linux/interrupt.h的枚举NR_SOFTIRQS`前加上对应的软中断编号枚举量
- 使用函数`kernel/softirq.c::open_softirq`注册（设置数组`softirq_vec`的其中一项），参数为软中断编号和软中断处理函数

发起一个软中断的方法（一般在中断处理器（前半部分）最后触发软中断）：`kernel/softirq.c::raise_softirq`或`kernel/softirq.c::raise_softirq_irqoff`

执行软中断`Softirqs`的位置：
- 中断后
- `ksoftirqd`线程
- 任何需要显式检测和执行软中断的地方

执行软中断的方法为`kernel/softirq.c::do_softirq -> kernel/softirq.c::__do_softirq`，一个对应的调用栈如下：
```
include/linux/spinlock.h::spin_unlock_bh
kernel/locking/spinlock.c::_raw_spin_unlock_bh
kernel/locking/spinlock.c::_raw_spin_unlock_bh
include/linux/spinlock_api_smp.h::__raw_spin_unlock_bh
kernel/softirq.c::__local_bh_enable_ip
arch/x86/include/asm/preempt.h::do_softirq
kernel/softirq.c::do_softirq
kernel/softirq.c::__do_softirq
```

函数`kernel/softirq.c::__do_softirq`的执行流程：
- 获取正在等待执行的软中断，放到变量`pending`中。`include/linux/interrupt.h::local_softirq_pending`
  - 一个int值，里面的每个bit表示一个软中断，bit设置为1则为要执行该软中断
- 增加软中断执行计数。`account_softirq_enter`
- 设置正在等待执行的软中断对应的int值为0，即没有正在等待执行的软中断（因为当前在执行）。`set_softirq_pending`
- 设置运行中断。`local_irq_enable`
- **检测变量`pending`的每个bit，如果为1，则执行`kernel/softirq.c::softirq_vec`对应位置的软中断处理器`softirq_action->action`。**
- 所有软中断处理完成后，再获取正在等待执行的软中断，如果还有等待的内容，则唤醒`ksoftirqd`线程。
  - `ksoftirqd`线程会周期性调用`kernel/softirq.c::do_softirq`来处理软中断
  - `ksoftirqd`线程有最低的优先权，nice值为19。


##### 任务片段`Tasklets`的内容
前面说了多个CPU可以并行运行**同一个软中断处理器**。对于`Tasklets`，则是CPU只可以并行运行**不同`Tasklets`**，所以`Tasklets`内部需要注意的同步操作就少了一些，理论上比软中断`Softirqs`更容易写。**不过还是要注意和其他`Tasklets`的数据共享和同步问题**。

`Tasklets`的实现建立在软中断`Softirqs`的基础上，使用了软中断`Softirqs`的2个类型
- `HI_SOFTIRQ`，对应的软中断处理器为`tasklet_action`
- `TASKLET_SOFTIRQ`，对应的软中断处理器为`tasklet_hi_action`

`Tasklets`存储在`kernel/softirq.c::tasklet_vec`和`kernel/softirq.c::tasklet_hi_vec`这2个列表中。列表每一项的类型是`include/linux/interrupt.h::struct tasklet_struct`。

`include/linux/interrupt.h::struct tasklet_struct`里面的字段：
- 列表下一项的指针`struct tasklet_struct *next`
- 状态`unsigned long state`。每个bit表示一种状态，目前只有2个bit被使用：
  - 是否已经调度`TASKLET_STATE_SCHED`
  - 是否在运行`TASKLET_STATE_RUN`
- 计数`atomic_t count`，计数表示处理函数是否生效、是否调度处理器。。大于0则不执行处理函数，等于0则要执行处理函数。
- 是否使用callback函数`use_callback`
- 处理函数
  - 函数`func`，当`use_callback`为0时，则使用`func`函数
  - 函数`callback`，当`use_callback`为1时，则使用`callback`函数
- 相关数据`data`

注册一个`Tasklets`的方法：
- 创建一个`tasklet_struct`
  - 使用宏`DECLARE_TASKLET`创建，计数`count`为0，`use_callback`为1
  - 使用宏`DECLARE_TASKLET_DISABLED`创建，计数`count`为1，`use_callback`为1
  - 使用宏`DECLARE_TASKLET_OLD`创建，计数`count`为0，`use_callback`为0
  - 使用宏`DECLARE_TASKLET_DISABLED_OLD`创建，计数`count`为1，`use_callback`为0
  - 使用函数`tasklet_init`创建
- 把创建的`tasklet_struct`加入列表中，并发起`kernel/softirq.c::raise_softirq_irqoff`软中断
  - 调用`include/linux/interrupt.h::tasklet_schedule`即可加入列表`tasklet_vec`
  - 调用`include/linux/interrupt.h::tasklet_hi_schedule`即可加入列表`tasklet_hi_vec`

启动、关闭一个`Tasklets`：
- 启动`Tasklets`，其实就是递增其计数`count`。对应函数为`tasklet_enable`、`tasklet_disable_nosync`
- 关闭`Tasklets`，其实就是递减其计数`count`。对应函数为`tasklet_disable`、`tasklet_disable_nosync`

执行`Tasklets`:
上文软中断`Softirqs`执行软中断处理器`softirq_action->action`的时候，会执行类型`HI_SOFTIRQ`和`TASKLET_SOFTIRQ`对应的软中断处理器`kernel/softirq.c::tasklet_action`和`kernel/softirq.c::tasklet_hi_action`。`kernel/softirq.c::tasklet_action`和`kernel/softirq.c::tasklet_hi_action`都调用`kernel/softirq.c::tasklet_action_common`完成操作，只是传入的`Tasklets`列表不同，列表分别是上文说的`kernel/softirq.c::tasklet_vec`和`kernel/softirq.c::tasklet_hi_vec`。

`kernel/softirq.c::tasklet_action_common`具体操作：
- 关闭中断。`local_irq_disable`
- 获取传入的队列，并把原始队列置为空
- 启动中断。`local_irq_enable`
- 遍历队列的每一个`Tasklets`，执行对应的处理函数，每个`Tasklets`的操作如下：
  - 测试状态`state`是否为`TASKLET_STATE_RUN`
    - 是则表示其他CPU真正执行该`Tasklets`，直接跳过
    - 不是则设置状态`state`为`TASKLET_STATE_RUN`
    - **这里证明了开头说的同一个`Tasklets`不会被多个CPU并行执行**
  - 判断计数`count`是否为0，不为0则不需要执行处理函数，直接跳过。为0则继续执行
  - 执行处理器。判断`use_callback`是否为1，是1则执行`callback`函数，是0则执行`func`函数
  - 清理设置状态`state`


##### 工作队列`Work Queue`的内容
工作队列`Work Queue`不像`Tasklets`一样依赖`Softirqs`的机制，有自己的独立实现。工作队列`Work Queue`运行在进程上下文`process context`，操作期间可以睡眠，耗时长的工作需要**睡眠**让出CPU，避免独占CPU太久，这时候就要选择工作队列`Work Queue`，而不是`Tasklets`或`Softirqs`。

工作队列`Work Queue`相关的数据结构：
- 一个`worker`线程的数据 `kernel/workqueue_internal.h::struct worker`
  - `struct task_struct *task`是关联的线程数据 `worker:task_struct=1:1`
  - `struct worker_pool *pool`是关联的工作池 `worker:worker_pool=N:1`
  - `struct list_head scheduled`已经调度的工作列表（即将要运行的工作列表）
  - `struct work_struct *current_work`是当前的具体工作
  - `work_func_t current_func`是当前具体工作的具体工作函数
  - `struct pool_workqueue *current_pwq`是当前具体工作所在的工作队列
  - `struct list_head node`下一个worker线程
- 所有CPU的工作池定义在`kernel/workqueue.c::struct worker_pool [NR_STD_WORKER_POOLS] cpu_worker_pools`
- 一个工作池 `kernel/workqueue.c::struct worker_pool`
  - `struct list_head	worklist`是等待处理的工作列表，每个工作的类型为`work_struct`
  - `struct list_head	workers`使用该工作池的worker线程列表 `worker:worker_pool=N:1`
  - `struct workqueue_attrs *attrs`该工作池的属性
  - 工作池没有一个关联到它的工作队列的信息，不过工作池和关联它的每个工作队列的属性应该是一样的？
- 工作池的工作队列 `kernel/workqueue.c::struct pool_workqueue`
  - `struct worker_pool *pool`是关联的工作池 `pool_workqueue:worker_pool=N:1`
  - `struct workqueue_struct *wq`是所在的工作队列 `workqueue_struct:pool_workqueue=1:N`
  - `struct list_head	inactive_works`不活跃的工作列表，工作池满了，就把工作提交到这里
- 所有工作队列定义在`kernel/workqueue.c::workqueues`
- 工作队列 `kernel/workqueue.c::struct workqueue_struct`
  - `struct list_head	pwqs`工作池的工作队列**列表** `workqueue_struct:pool_workqueue=1:N`
  - `struct list_head	list`在列表`kernel/workqueue.c::workqueues`中的下一个工作队列
  - `struct pool_workqueue **cpu_pwq`每个CPU的工作池的工作队列
- 工作`include/linux/workqueue.h::struct work_struct`
  - `data`由很多信息组成，主要有该工作对应的`pool_workqueue`、工作池`worker_pool`、一些标记信息
  - 该工作在其列表中的下一个工作`struct list_head entry`
  - 工作的具体操作函数`work_func_t func`

工作线程的具体操作在`kernel/workqueue.c::worker_thread`，操作如下：
- 获取该工作线程关联的工作池`worker->pool`
- 根据工作池`worker->pool`的工作列表`worklist`是否为空，判断是否要继续后面操作。
  - 如果工作列表`worklist`为空，则直接跳到最后，调度其他线程`schedule`，也可以认为是该线程睡眠了
- 不断执行工作列表`worklist`里的工作`work_struct`，具体流程如下：
  - 获取工作列表`worklist`里的工作`work_struct`，并把它从列表中删除。`list_first_entry`
  - 把刚刚获取的工作放到`worker`的列表`scheduled`中。`assign_work`
  - 执行`worker`的列表`scheduled`的里面的工作。`process_scheduled_works -> process_one_work`
- 调度其他线程`schedule`，也可以认为是该线程睡眠了

创建一个工作`work_struct`的方法：
- 使用宏`include/linux/workqueue.h::DECLARE_WORK`
- 使用宏`include/linux/workqueue.h::INIT_WORK`

触发一个工作的方法：
- 把工作`work_struct`加入到系统工作队列`system_wq`中。`include/linux/workqueue.h::schedule_work`
- 把延迟工作`delayed_work`加入到系统工作队列`system_wq`中。`include/linux/workqueue.h::schedule_delayed_work`

取消一个延迟工作的方法：`kernel/workqueue.c::cancel_delayed_work`

运行系统工作队列`system_wq`所有工作的方法：
`include/linux/workqueue.h::flush_scheduled_work -> include/linux/workqueue.h::__flush_workqueue`

创建新的工作队列的方法（创建、初始化一个`workqueue_struct`，并加入列表`kernel/workqueue.c::workqueues`中。）：
`include/linux/workqueue.h::create_workqueue -> kernel/workqueue.c::alloc_workqueue`


### 系统调用
X86系统调用可以**通过中断（中断编号为`0x80`）来实现**，也可以**通过专有指令`sysenter/sysexit`（32位）和`syscall/sysret`（64位）来实现**。
x86_64**系统调用表**定义在`arch/x86/entry/syscall_64.c::sys_call_table`，arm64系统调用表定义在`arch/arm64/kernel/sys.c::sys_call_table`。


#### 通过中断实现系统调用（中断编号为`0x80`）
X86系统调用在中断编号`IA32_SYSCALL_VECTOR 0x80`中，初始化代码在`arch/x86/kernel/idt.c::idt_setup_traps`，初始化信息为`arch/x86/kernel/idt.c::ia32_idt::SYSG(IA32_SYSCALL_VECTOR,	asm_int80_emulation)`。

中断编号`IA32_SYSCALL_VECTOR 0x80`对应的中断处理器为`asm_int80_emulation`，在`arch/x86/include/asm/idtentry.h`中**声明**函数`asm_int80_emulation`、`xen_asm_int80_emulation`、`int80_emulation`。

在`arch/x86/entry/common.c`中**定义**`IA32_SYSCALL_VECTOR`对应的函数为`int80_emulation`。

`arch/x86/entry/common.c::int80_emulation`通过下面调用链**获取系统调用编号对应的处理器，并运行它**。
```
arch/x86/entry/common.c::int80_emulation
arch/x86/entry/common.c::do_syscall_32_irqs_on
arch/x86/entry/syscall_32.c::ia32_sys_call_table
具体的系统调用处理器（详见下文**系统调用处理器的代码结构**）
```


#### 通过专有指令实现系统调用 `sysenter/sysexit`（32位）和`syscall/sysret`（64位）
函数`arch/x86/kernel/traps.c::trap_init -> arch/x86/kernel/cpu/common.c::cpu_init -> arch/x86/kernel/cpu/common.c::syscall_init`使用指令`WRMSR`设置寄存器`IA32_LSTAR`（也叫`MSR_LSTAR`）为`arch/x86/entry/entry_64.S::entry_SYSCALL_64`。即系统调用的处理器为`arch/x86/entry/entry_64.S::entry_SYSCALL_64`。

`arch/x86/entry/entry_64.S::entry_SYSCALL_64`通过下面调用链**获取系统调用编号对应的处理器，并运行它**。
```
arch/x86/entry/entry_64.S::entry_SYSCALL_64
arch/x86/entry/common.c::do_syscall_64
arch/x86/entry/common.c::do_syscall_x64
arch/x86/entry/syscall_64.c::sys_call_table[系统调用号]
具体的系统调用处理器（详见下文**系统调用处理器的代码结构**）
```

#### 系统调用处理器的代码结构（以`read`为例）
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


#### 应用层使用系统调用的方法
**这里的应用层主要是对应语言的函数库，比如C语言的Glibc库**，我们自己写的应用层代码则直接使用对应语言的函数库就行。Glibc的系统调用内容详见文档`glibc/syscall.md`

