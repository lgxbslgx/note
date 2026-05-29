# 常用性能分析命令

## 系统级别

- top：实时查看CPU、内存、进程负载
- vmstat：查看CPU、内存、swap、IO的瞬时（间隔）统计
- iostat：查看磁盘IO吞吐量、响应时间、利用率
- sar：收集并报告系统活动历史数据（CPU、内存、I/O、网络等），适合事后分析。
- pidstat：
- mpstat：
- cpustat：
- netstat：查看网络连接、socket 统计、网络队列等，辅助排查网络瓶颈。
- nicstat：

## 进程级别

- perf：Linux内核自带的性能分析工具，基于PMU（Performance Monitoring Unit）、tracepoint、kprobe、eBPF等机制（统计CPU周期落在哪段代码）。
- Intel VTune Profiler / AMD uProf：硬件计数器精细分析（CPI、缓存命中率、分支预测）。Intel平台深度优化。
- gprof：插桩/采样的传统方案，GCC项目，精度一般，有侵入性。
- oprofile：早期内核级采样器，已被 perf 取代。
- strace：跟踪进程的系统调用和信号处理函数。
- ltrace：追踪进程的库函数调用。
- eBPF：内核级动态追踪框架。
- DTrace：

## Java相关性能工具

- jps：查看所有Java进程
- jstack：查看Java进程的线程栈信息
- jmap：查看Java进程的堆内存信息
- jstat：查看Java进程的统计信息
- async-profiler：Java现代性能分析核心工具。基于AsyncGetCallTrace，生成CPU/alloc/锁争用的火焰图，生产友好
- JFR（Java Flight Recorder）：
- JMC（Java Mission Control）：
- VisualVM：
- JProfiler：
- Eclipse MAT (Memory Analyzer Tool)：

## 性能诊断流程

1. 使用系统级别命令查看系统整体情况，确定瓶颈位置：CPU\内存\磁盘\网络
2. 使用进程级别命令查看进程情况，定位到具体进程和热点函数
3. 查看对应热点进程和函数，分析性能问题，优化热点代码
4. 重复测试，验证优化效果
