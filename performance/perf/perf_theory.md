# perf理论

## 术语

- 计数(statistics/count)：统计事件发生的次数
  - 例子：`perf stat`
  - 例子：`perf stat sleep 5`
  - 例子：`"perf stat -p `pgrep -nx dockerd`"`
- 采样剖析(sample)：收集一系列调用事件的细节信息
  - 例子：`perf top`
  - 例子：`perf record -a -g -F 999 -- sleep 20`
- 追踪(trace)：追踪每一个事件的细节
  - 例子：`perf ftrace`
  - 例子：`perf probe`

## 事件触发

- 软件事件(Software events)
  - CPU时钟事件（定时器）
  - 上下文切换事件
  - 缺页异常事件
  - 其他事件
- 硬件事件（Hardware events）
  - 缓存不命中
  - 分支预测失败
  - 其他事件
- 内核追踪点(Kernel Tracepoints)
  - block：块设备I/O
  - ext4：文件系统操作
  - kmem：内核内存分配
  - random：内核随机数生成器
  - sched：CPU调度程序事件
  - syscalls：系统调用进入和退出
  - 其他事件
- USDT(User-Level Statically Defined Tracing)
  - TODO
- Dynamic Tracing
  - TODO

## 设计原理

### 硬件

性能计数器（performance counters）统计缓存不命中、分支预取失败等事件。

### 操作系统

Linux性能计数器子系统（Linux Performance Counter subsystem）提供了抽象接口，用于获取性能计数器数据，并提供了事件能力。

## 参考链接

- [初初见你-性能分析工具perf](https://zhuanlan.zhihu.com/p/620862106)
- [源头活水-perf events介绍](https://zhuanlan.zhihu.com/p/621747483)
- [初入源码-从perf文档开始](https://zhuanlan.zhihu.com/p/622956899)
