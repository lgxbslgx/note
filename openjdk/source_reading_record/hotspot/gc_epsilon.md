
### Epsilon GC 实现
#### 初始化
整体流程和`gc.md 初始化基本流程`差不多，具体内容在`EpsilonArguments`和`EpsilonHeap`。**特定GC内容**如下：

`EpsilonArguments::initialize_alignments`:
- 初始化对齐信息 `堆对齐大小`=`一个操作系统页大小`

`EpsilonArguments::create_heap`:
- 创建的堆为`EpsilonHeap`

`Universe::initialize_heap -> EpsilonHeap::initialize`:
- 计算一些`EpsilonHeap`特有的字段（TLAB、monitor等相关内容）
- 新建`EpsilonBarrierSet`，设置到静态变量`BarrierSet::_barrier_set`。
  - `BarrierSetAssembler` **放在`/hotspot/cpu/CPU_NAME/gc/shared/`里面**
  - `BarrierSetC1` **在`/hotspot/share/gc/shared/c1`里面**
  - `BarrierSetC2` **在`/hotspot/share/gc/shared/c2`里面**

`gc_barrier_stubs_init`:
- 初始化`BarrierSet`的`BarrierSetAssembler`，即调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


#### 堆内存分配
整体流程和`gc.md 堆内存分配基本流程`差不多，具体内容在`EpsilonHeap`。**特定GC内容**如下：

新建（叫分配也行）新的TLAB `CollectedHeap::allocate_new_tlab`，实现在`EpsilonHeap::allocate_new_tlab`:
- 如果参数设置了`弹性调节TLAB大小`（`EpsilonElasticTLAB`，默认为`true`），则调节TLAB大小
- 确定TLAB的大小在最小值、最大值之间，确定对齐
- 分配TLAB `EpsilonHeap::allocate_work`
  - 尝试分配，就是简单地增大`其ContiguousSpace`里面的`_top`的值。 `ContiguousSpace::par_allocate`
  - 如果上一步分配失败，则加锁，再次尝试分配（再次调用`ContiguousSpace::par_allocate`）
  - 如果上一步分配也失败，则拓展堆空间，重新执行这3步
  - 记录（更新）相关信息，打印相关信息，返回
- 设置相关信息并返回

在TLAB外分配，调用链为 `MemAllocator::mem_allocate_outside_tlab -> EpsilonHeap::mem_allocate -> EpsilonHeap::allocate_work`。和`新建（叫分配也行）新的TLAB`一样，都是调用`EpsilonHeap::allocate_work`，只是`分配的大小`不同。

#### 垃圾收集
Epsilon GC 无垃圾收集。`EpsilonHeap::collect`和`EpsilonHeap::do_full_collection`都是记录和打印GC信息，没有真正的收集。

