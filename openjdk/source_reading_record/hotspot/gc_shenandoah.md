## Shenandoah 实现
本文主要描述分代`Shenandoah`的实现，其中也包含了单代的内容。
相关代码还没并入主线，目前代码在`https://github.com/openjdk/shenandoah`。


### 初始化
整体流程和`gc_jvm.md 初始化基本流程`差不多，具体内容在`ShenandoahArguments`和`ShenandoahHeap`。**特定GC内容**如下：

`ShenandoahArguments::conservative_max_heap_alignment`:
设置最大堆对齐信息为32M（`1<<16`）。

`ShenandoahArguments::initialize`:
- 使用大页则把`MaxHeapSize`进行大页对齐
- 设置使用NUMA `UseNUMA`
- 设置`GCPauseIntervalMillis`
- 设置并发GC线程数`ConcGCThreads`
- 设置并行GC线程数`ParallelGCThreads`
- 设置`UseDynamicNumberOfGCThreads`为`false`，`Shenandoah`不支持动态数量的GC线程
- 设置使用技术循环安全点 `UseCountedLoopSafepoints`
- 参数`ShenandoahIUBarrier`和`ShenandoahGCMode=generational`不能同时存在
- 设置日记时间buffer的大小 `LogEventsBufferEntries`
- 如果`InitialHeapSize`等于`MaxHeapSize`，则设置`ShenandoahUncommit`为`false`
- 如果`ClassUnloading`为`false`，设置`ClassUnloadingWithConcurrentMark`为`false``
- 设置TLAB的分配平均权重`TLABAllocationWeight`为`90`

`ShenandoahArguments::initialize_alignments`:
- 初始化卡表相关信息: 一个卡的大小（一般为512B）、移位数 `CardTable::initialize_card_size`
  - 初始化块偏移量表信息（和卡表信息有重复）
  - 初始化`ObjectStartArray`信息（和卡表信息有重复）
- 设置区域大小信息 `ShenandoahHeapRegion::setup_sizes`
  - 设置最小堆区域大小`ShenandoahMinRegionSize`为`256K`
  - 如果是分代模式，则对齐最大堆到`GCCardSizeInBytes * os::vm_page_size`
  - 判断`ShenandoahRegionSize`、`ShenandoahMinRegionSize`、`ShenandoahMaxRegionSize`是否满足条件
  - 设置区域大小`region_size`并对齐到一个页的大小
  - 设置区域大小相关信息。`ShenandoahHeapRegion`的各个静态变量
    - 区域大小信息
    - 区域数量信息
    - 大对象阈值（默认为一个区域）
    - 最大的TLAB大小（默认为一个区域）
- 初始化对齐信息
  - `空间对齐SpaceAlignment` = 256K
  - `堆对齐大小HeapAlignment` = 256K

`GCArguments::initialize_heap_flags_and_sizes`:S
检测和设置堆的`初始值、最大值、最小值`，保证关系正确和对齐。

`GCArguments::initialize_size_info`:
`Shenandoah`没有重写该方法，直接用`GCArguments`的方法。没内容。

`ShenandoahArguments::create_heap`:
- 如果设置分代，创建的堆为`ShenandoahGenerationalHeap`。
- 如果没有设置分代，创建的堆为`ShenandoahHeap`。
- `ShenandoahGenerationalHeap`继承了`ShenandoahHeap`，没有太多自定义的操作。
- `ShenandoahHeap`的构造函数初始化很多内容。 // TODO 用到再看

`Universe::initialize_heap -> ShenandoahHeap::initialize`:
- 设置堆的`初始值、最大值、最小值`，前面设置的是全局变量，这里是设置`ShenandoahHeap`的静态变量。
- 设置分代的启发式内容 `ShenandoahHeap::initialize_heuristics_generations`
  - 根据`ShenandoahGCMode`设置GC模式，如果是`generational`，则`ShenandoahHeap::_gc_mode`为`ShenandoahGenerationalMode`
  - 设置barrier相关的参数，是参数不是`BarrierSet`。`ShenandoahMode::initialize_flags`、`ShenandoahGenerationalMode::initialize_flags`
  - 新建分代相关的类 `ShenandoahYoungGeneration`、`ShenandoahOldGeneration`、`ShenandoahGlobalGeneration`
    - 注意`ShenandoahOldGeneration`的最大堆大小在这里被设置为0。其实后面会调用`ShenandoahGeneration::increase_capacity/decrease_capacity`来调整大小。
- 跟操作系统申请保留一个连续的区域 `Universe::reserve_heap`
- 新建`ShenandoahBarrierSet`，设置到静态变量`BarrierSet::_barrier_set`。
  - `ShenandoahBarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/shenandoah/`里面**
  - `ShenandoahBarrierSetC1` **在`/hotspot/share/gc/shenandoah/c1`里面**
  - `ShenandoahBarrierSetC2` **在`/hotspot/share/gc/shenandoah/c2`里面**
  - `ShenandoahBarrierSet`的构造函数会新建并初始化卡表信息`ShenandoahCardTable`。
  - 卡表初始化 `ShenandoahCardTable::initialize`内容如下:
    - 注意有2个卡表，分别负责写和读
    - 计算每个卡表大小（页对齐）、记得要`+1`。（1:512，一个卡一个字节byte，表示512byte的堆）
    - 申请保留空间
    - 计算卡表相关地址，注意`_byte_map`是真正的基地址，`_byte_map_base`是假设堆从`0`开始的基地址
- 如果是分代shenandoah，则新建记忆集相关信息 `ShenandoahDirectCardMarkRememberedSet`、`ShenandoahScanRemembered`
- 新建并发GC的WorkerThreads线程池
- 新建并行GC的WorkerThreads线程池
- 新建用于记录标记信息的bitmap、aux_bitmap（每个bitmap大小 = 堆大小 / 指针大小（4或8）* 2，也就是1:32，32分之一。zgc是1:64）
- 新建用于标记操作的`ShenandoahMarkingContext`
- 新建用于记忆集操作的`ShenandoahCollectionSet`
- 新建`ShenandoahFreeSet`
- // TODO 剩下的未认真看

`init_globals -> gc_barrier_stubs_init`:
- 初始化`BarrierSet`的`ShenandoahBarrierSet`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


### 堆内存分配
整体流程和`gc_jvm.md 堆内存分配基本流程`差不多，具体内容在`ShenandoahHeap`、`ShenandoahYoungGeneration`、``和``。**特定GC内容**如下：


分配新的TLAB `ShenandoahHeap::allocate_new_tlab`:
调用`ShenandoahAllocRequest::for_tlab`来构建分配请求`ShenandoahAllocRequest`，然后把`ShenandoahAllocRequest`传给方法`ShenandoahHeap::allocate_memory`完成分配操作。`ShenandoahHeap::allocate_memory`的内容如下:
// TODO


在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab -> ShenandoahHeap::mem_allocate`:
和`分配新的TLAB`一样，也是调用`ShenandoahHeap::allocate_memory`进行操作，只是提交的`ShenandoahAllocRequest`不同。`ShenandoahAllocRequest`具体不同在于:
- 分配大小不同
- 分配类型不同 `ShenandoahAllocRequest::Type`
- 分配的代不同 `ShenandoahAffiliation`


### 垃圾收集

#### 新生代垃圾收集（young gc）
// TODO


#### 老年代垃圾收集（full gc）
// TODO


### 其他内容
- Shenandoah的引用处理很有问题。详见`ShenandoahReferenceProcessor::set_soft_reference_policy`和它的`caller`

