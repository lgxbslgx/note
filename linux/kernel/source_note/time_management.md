## 时间管理
《Linux Kernel Development》
  - 第11章 Timers and Time Management
《Linux内核源代码情景分析》第3章中断、异常和系统调用 3.7时钟中断 有少量内容
《Professional Linux Kernel Architecture》
  - 第15章 Time Management
《Understanding the Linux Kernel》
  - 第6章 Timing Measurements


### 表示时间的信息
实时时钟 `real-time clock (RTC)`
- 硬件有一个设备来跟踪时间、记录时间，由电池供电，关机也会运行
  - 这个时间应该是从1970年1月1日00:00:000，到当前经过的秒数
- 系统启动的时候，会从硬件获取该时间，也称为wall time。
  - 一些书说时间放在`struct timespec xtime`变量中，但是现在主线代码已经没有`xtime`这个变量了。
  - 现在时间信息在`kernel/time/timekeeping.c::tk_core`，具体应该是`tk_core -> struct timekeeper	timekeeper -> u64 xtime_sec`

系统计时器 `system timer`
- 计时器中断频率（tick rate） `include/asm-generic/param.h::include/uapi/asm-generic/param.h::HZ`。
  - `HZ`表示1秒的计时器中断次数
  - 在x86，`HZ`为`100`，表示1秒中断100次，即10毫秒中断一次。
- 计时器中断次数（ticks） `include/linux/jiffies.h::jiffies/jiffies_64`
  - `jiffies/jiffies_64`的存储位置在链接的时候确定，详见`vmlinux.lds`
- `jiffies_64 / HZ`就是开机到现在经过的时间（单位为秒）。注意是**除法**不是**相乘**，因为`HZ`是频率不是时间


### 计时器中断处理函数的操作
关于中断的信息详见`interrupt_exception_system_call.md`，中断处理函数为`arch/x86/kernel/time.c::timer_interrupt -> kernel/time/tick-common.c::tick_handle_periodic -> kernel/time/tick-common.c::tick_periodic`。详细操作如下：
- 进行计时操作。`kernel/time/timekeeping.c::do_timer`
  - 把`jiffies_64`递增1
  - 更新`Load averages`。`kernel/sched/loadavg.c::calc_global_load`（加载平衡？不懂）
- 更新实时时间`Wall time`。`kernel/time/timekeeping.c::update_wall_time`
- 很多时间更新操作。`kernel/time/timer.c::update_process_times`
  - **计算系统和用户使用的CPU时间**。`kernel/sched/cputime.c::account_process_tick`
    - 判断进入计时器中断前，CPU处于内核状态还是用户状态，把对应的计数器加上一个tick的时间，即加10ms
    - 很明显这个计算不是很准确，因为这10ms很可能换了状态，不是操作系统或者用户自己独享的。
  - **处理过期的计时任务，其实是执行到期的计时任务**。`kernel/time/timer.c::run_local_timers`
    - 计时任务相关函数: `add_timer`、`del_timer`、`del_timer_sync`、`mod_timer`。
  - **看情况设置`need_resched`，就是如果目前的进程运行太久了，通知调度器需要调度其他进程**。`kernel/rcu/tree.c::rcu_sched_clock_irq`
  - 减少当前运行进程的时间片，平衡每个处理器的运行队列。`kernel/sched/core.c::scheduler_tick`


### 推迟执行任务的方法
`计时器中断处理`有一步骤是执行到期的计时任务，如果不想使用`计时器中断处理`，又想推迟执行一些任务，则可以使用下面方法：
- 推迟时间很短，则使用函数`ndelay`、`udelay`、`mdelay`。
- 直接一个空循环，等待你需要的时间。`while (time_before(jiffies, delay)) ;`（如果推迟的时间很长，不建议这个方法）
- 还是循环等待你需要的时间，不过循环里面的内容是让出CPU（让出CPU对应的函数是`cond_resched`，即重新调度）。
- 长时间的推迟，则使用函数`schedule_timeout`（该函数里面使用了计时器中断处理）。
- 让进程睡眠对应时间

