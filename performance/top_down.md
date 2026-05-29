# Top-Down性能分析方法

## 思路

在CPU执行的各个时间阶段，不断划分阶段，再选择（聚焦）性能瓶颈的阶段。不断缩小范围，直到选择到最需要优化的阶段和组件。

## 基础概念

### 性能监视计数器（Performance Monitor Counter，PMC）

CPU有很多性能监视信号，负责监视处理器中各种各样的事件（如下所示）。

- Cache缺失（Cache Miss）
- TLB缺失（TLB Miss）
- 分支预测错误（Branch misprediction）
- 指令发射（issue）
- 指令退休（retire）
- 其他事件

### 性能监视单元（Performance Monitor Unit，PMU）

性能监视单元由下面的部件组成。

- 多个性能监视计数器（PMC）
- 配置寄存器：为PMC选择需要计数的监控信号、计数的模式、过滤器等
- 计数寄存器：存储PMC计数的结果
- 其他

## 参考链接

- [Top-Down性能分析方法（原理篇）：揭秘代码运行瓶颈](https://zhuanlan.zhihu.com/p/643738310)
- [Intel Top-down方法学综述](https://zhuanlan.zhihu.com/p/638160179)
- [《A Top-Down Method for Performance Analysis and Counters Architecture》阅读笔记](https://andrewei1316.github.io/2020/12/20/top-down-performance-analysis/)
- Ahmad Yasin, A Top-Down Method for Performance Analysis and Counters Architecture
- Ahmad Yasin, Top-down Microarchitecture Analysis through Linux perf and toplev tools
- Ahmad Yasin, Performance Analysis in Out-of-Order Cores
