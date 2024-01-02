## JVM GC的资料（书、论文、视频等）
注意: 论文一般都是描述最开始的算法，当前代码实现可能已经有改变。所以论文作为顶层设计来参考，最终以当前的代码为准。


### GC综述相关内容
- 书《The Garbage Collection Handbook - The Art of Automatic Memory Management》 （必看）
- 书《Garbage Collection - Algorithms for Automatic Dynamic Memory Management》
- 书《深入理解Java虚拟机 - JVM高级特征与最佳实践》- “自动内存管理”部分


### SerialGC
// TODO


### ParallelGC
// TODO


### CMS
// TODO


### G1
注意: OpenJDK主线代码改了G1很多内容，如果对照论文和书去看主线代码，可能会有点混乱，不懂的地方要多搜一下`issue tracker`，看最新改变的内容。

- 论文[Garbage-First Garbage Collection](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/1029873.1029879)
- 书《JVM G1源码分析与调试》


### ZGC
- 论文[The pauseless GC algorithm](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/1064979.1064988)
- 论文[C4: The Continuously Concurrent Compacting Collector](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/1993478.1993491)
- 论文[Deep Dive into ZGC: A Modern Garbage Collector in OpenJDK](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/3538532)（必看）
- 书《新一代垃圾回收器 - zgc设计与实现》
- 视频[Generational ZGC and Beyond](https://www.youtube.com/watch?v=YyXjC68l8mw)


### Shenandoah
- 论文[Shenandoah: An open-source concurrent compacting garbage collector for OpenJDK](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/2972206.2972210)


### 弱引用处理
- 论文[Deep Dive into ZGC: A Modern Garbage Collector in OpenJDK](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/3538532) Section 4、5
- 论文[Reference Object Processing in On-The-Fly Garbage Collection](https://sci-hub.ru/https://dl.acm.org/doi/abs/10.1145/2775049.2602991)

