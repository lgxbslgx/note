## 进程（任务、线程）管理 process_management.md
《Linux Kernel Development》
  - 第3章 Process Management
  - 第4章 Process Scheduling
《Linux内核源代码情景分析》
  - 第4章 进程与进程调度
《Professional Linux Kernel Architecture》
  - 第2章 Process Management and Scheduling
《Understanding the Linux Kernel》
  - 第3章 Processes
  - 第7章 Process Scheduling


### 相关数据结构
常用类型定义在下列文件中
```
include/linux/sched.h
include/linux/sched/task.h
include/uapi/linux/personality.h
include/uapi/linux/resource.h
```

- `include/linux/sched.h::task_struct`表示一个任务（可能是进程或者线程）
  - `__state`线程状态
  - `stack`线程栈（一些书中`task_struct`和栈重用一部分空间，主线代码已改成现在这样）
  - `rt_priority`优先级
  - `exit_state/exit_code/exit_signal`进程退出信息
  - `policy`调度策略
  - `loginuid/sessionid`进程组信息
  - `struct mm_struct *mm/active_mm` 虚拟内存相关内容，详见[内存管理 memory_management.md](/linux_kernel/source_note/memory_management.md)
  - `pid`进程号
  - `real_parent/parent/children/sibling/`相关进程（父进程、子进程、兄弟进程等）
  - `thread_pid/pid_links/thread_node`进程号组成的哈希表，用于根据进程号`pid`查找进程`task_struct`
  - `files`打开的文件信息
  - 其它

- `include/linux/sched.h::TASK_*`任务状态
  - `TASK_RUNNING` 就绪
  - `TASK_INTERRUPTIBLE` 睡眠，可被信号`signal`中断
  - `TASK_UNINTERRUPTIBLE` 睡眠，不可被信号`signal`中断
  - `__TASK_STOPPED` 暂停
  - `TASK_ZOMBIE` 已死亡，等待注销

- `include/linux/sched.h::PF_*`进程flags
- `include/uapi/linux/personality.h::PER_*`进程的“个性”属性
- `include/uapi/linux/resource.h -> include/asm-generic/resource.h::RLIMIT_*`进程的需要的各种资源信息
- `include/linux/sched/user.h`、`kernel/user.c`用户相关信息
  - `user_struct`用户信息
  - `hlist_head uidhash_table`所有用户组成的哈希表
- `include/linux/fdtable.h`、`include/linux/fs.h`、`include/linux/fs_struct.h`、`fs/file.c`文件相关信息
  - `include/linux/fs_struct.h::fs_struct`文件系统信息
  - `include/linux/fdtable.h::files_struct`打开的文件表信息
  - `include/linux/fs.h::file`文件信息
  - `include/linux/binfmts.h::linux_binprm`表示一个可执行二进制文件
- `include/linux/sched/signal.h`信号相关信息即，进程通信的一种手段
  - `signal_struct`信号信息
- `include/linux/sched.h::SCHED_*`进程调度策略，详见下文


### 相关操作

#### 进程创建、执行和退出
`fork`、`clone`、`vfork`3个系统调用可以创建一个进程
- `fork系统调用`完全复制进程（这里类似生物、医学所说的克隆`clone`）
- `clone系统调用`自定义地复制进程
- `vfork系统调用`创建线程，创建完成后，父进程会阻塞直到执行`execve`或者`exit`等操作

- `execve系统调用`执行一个可执行文件（ELF、srcipt等），里面有**具体的加载和链接操作，详见[loader_linker.md](/linux_kernel/source_note/loader_linker.md)**。
- `exit系统调用`进程退出。
- `wait4系统调用`进程等待。


#### 进程调度
调用`kernel/sched/core.c::schedule`函数来进行进程调度。`schedule`函数要判断`need_resched`是否为1，来判断是否需要调度。
- 内核内部主动调用
- 从内核空间返回用户空间前调用

`need_resched`为1的场景：
- 时钟中断的服务程序中，发现当前进程运行的时间过长
- 唤醒一个睡眠中的进程时，发现被唤醒的进程比当前进程优先级更高
- 进程通过系统调用改变`调度策略`或者`nice值`。



##### 进程优先级`weight`
- 优先级`weight`，由下面组合而成
  - `counter`：进程被分配的（剩下的）时间片（**每次分配的时间片由下面的`nice`值计算而来**）
  - `nice`（`20-nice`）：进程的`谦让值`。范围为`-19`到`20`，值越小越容易被调度
  - `rt_priority`（`1000+rt_priority`）：实时优先级


##### 进程调度策略
- `sched_setscheduler系统调用`设置进程的调度策略。
- `sched_getscheduler系统调用`获取进程的调度策略。

每个进程有一个调度策略，调度策略的分类如下：
- `SCHED_NORMAL`
- `SCHED_FIFO`先进先出（First In First Out）调度策略
  - **需要进程自愿让出**或者**被更高优先级的进程抢占**
- `SCHED_RR`时间片轮转调度策略
  - 相同优先级的进程轮流被分配执行时间
- `SCHED_BATCH`
- `SCHED_IDLE`
- `SCHED_DEADLINE`


### 相关系统调用

#### fork系统调用
`kernel/fork.c::SYSCALL_DEFINE0(fork)`

#### clone系统调用
`kernel/fork.c::SYSCALL_DEFINE5(clone, ...)`

#### vfork系统调用
`kernel/fork.c::SYSCALL_DEFINE0(vfork)`

#### execve系统调用
`fs/exec.c::SYSCALL_DEFINE3(execve, ...)`

#### exit系统调用
`kernel/exit.c::SYSCALL_DEFINE1(exit, ...)`

#### wait4系统调用
`kernel/exit.c::SYSCALL_DEFINE4(wait4, ...)`

#### nanosleep系统调用
`kernel/time/hrtimer.c::SYSCALL_DEFINE2(nanosleep, ...)`

#### pause系统调用
`kernel/signal.c::SYSCALL_DEFINE0(pause)`

#### sched_setscheduler系统调用
`kernel/sched/core.c::SYSCALL_DEFINE3(sched_setscheduler, ...)`

#### sched_getscheduler系统调用
`kernel/sched/core.c::SYSCALL_DEFINE1(sched_getscheduler)`

#### sched_yield系统调用
`kernel/sched/core.c::SYSCALL_DEFINE0(sched_yield)`

