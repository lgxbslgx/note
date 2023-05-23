### Serial GC 实现
#### 初始化
整体流程和`gc.md 初始化基本流程`差不多，具体内容在`GenArguments`、`SerialArguments`和`SerialHeap`。**特定GC内容**如下：

`GenArguments::initialize_alignments`：
- 初始化卡表相关信息: 一个卡的大小（一般为512B）、移位数 `CardTable::initialize_card_size`
  - 初始化块偏移量表信息（和卡表信息有重复）
  - 初始化`ObjectStartArray`信息（和卡表信息有重复）
- 初始化对齐信息 `堆对齐大小`=`一个卡大小`乘以`一个操作系统页大小`

`GenArguments::initialize_heap_flags_and_sizes`：
- 检测和设置`新生代、老年代`的`初始值、最大值、最小值`，也要保证关系正确和对齐

`GenArguments::initialize_size_info`：
- 人体工学地（ergonomically）设置堆参数

`SerialArguments::create_heap`：
- 创建的堆为`SerialHeap`

`Universe::initialize_heap -> GenCollectedHeap::initialize`:
- 在刚刚申请的连续区域中划分新生代、老年代区域，也就是设置对应的边界值
- 创建卡表（Card table），卡表是记忆集（Remembered Set， RSet）的一种实现方式。代码里面的注释和命名会混用这2个名字。
- 卡表初始化 `CardTable::initialize`
  - 计算卡表大小（页对齐）、记得要`+1`
  - 申请保留空间
  - 计算卡表相关地址，注意`_byte_map`是真正的基地址，`_byte_map_base`是假设堆从`0`开始的基地址
- 新建`CardTableBarrierSet`，设置到静态变量`BarrierSet::_barrier_set`。
  - `CardTableBarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/shared/`里面**
  - `CardTableBarrierSetC1` **在`/hotspot/share/gc/shared/c1`里面**
  - `CardTableBarrierSetC2` **在`/hotspot/share/gc/shared/c2`里面**
- 初始化新生代、老年代的具体信息（很多内容）
  - 新生代，新建`DefNewGeneration`。主要是`eden`、`survivor`区的各种设置、各个计数器等
  - 老年代，新建`TenuredGeneration`。很多，用到再看。

`gc_barrier_stubs_init`:
- 初始化`BarrierSet`的`CardTableBarrierSetAssembler`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


#### 堆内存分配
整体流程和`gc.md 堆内存分配基本流程`差不多，具体内容在`GenCollectedHeap`、`DefNewGeneration`、`TenuredGeneration`和`SerialHeap`。**特定GC内容**如下：

新建（叫分配也行）新的TLAB `CollectedHeap::allocate_new_tlab`，实现在`GenCollectedHeap::allocate_new_tlab -> GenCollectedHeap::mem_allocate_work`:
- 先尝试在`新生代`的`eden区`分配（就是简单地增大`其ContiguousSpace`里面的`_top`的值） `DefNewGeneration::par_allocate`
- `新生代`的`eden区`分配不成功时（主要是因为空间不足），尝试在`新生代`的`from区`和`老年代`分配 `GenCollectedHeap::attempt_allocation`
  - `新生代`的`from区`分配对应的方法: `DefNewGeneration::allocate -> DefNewGeneration::allocate_from_space`
  - `老年代`分配对应的方法: `TenuredGeneration::allocate`
- 上面再不成功，则尝试拓展（增大）堆内存并重新分配 `GenCollectedHeap::expand_heap_and_allocate`
  - 注意这里是先拓展老年代，再拓展新生代
  - Serial GC的**新生代在这里不会expand**，详见方法`DefNewGeneration::expand_and_allocate`。
- 上面再不成功，则执行垃圾收集操作，如下所示
  - 新建`VM_GenCollectForAllocation`，并提交给`VMThread`
  - 等待`VMThread`执行垃圾收集操作，注意操作最后会执行分配，分配结果放在`VM_CollectForAllocation::_result`里面（详细收集过程见下文），收集操作调用链: `VM_GenCollectForAllocation::doit -> GenCollectedHeap::satisfy_failed_allocation`
    - **执行垃圾收集** **`GenCollectedHeap::do_collection`**
      - 先执行新生代的垃圾收集（young gc） `GenCollectedHeap::collect_generation(_young_gen`
	  - 分配不成功则执行老年代的垃圾收集（full gc）**注意老年代不能分配TLAB，不过可以分配对象** `GenCollectedHeap::collect_generation(_old_gen`
      - 计算老年代、新生代的新大小，这里会**expand堆内存** `DefNewGeneration::compute_new_size -> DefNewGeneration::expand`
    - 再次尝试分配 `GenCollectedHeap::attempt_allocation`
    - 上面再不成功，则尝试拓展（增大）堆内存并重新分配 `GenCollectedHeap::expand_heap_and_allocate`
      - 注意这里是先拓展老年代，再拓展新生代
      - Serial GC的**新生代在这里不会expand**，详见方法`DefNewGeneration::expand_and_allocate`
	- 上面再不成功，则**再次执行垃圾收集操作**，操作和前面一样
	- 再次尝试分配 `GenCollectedHeap::attempt_allocation`
    - 返回`VM_CollectForAllocation::_result`

上面流程可以简化为: `attemp(eden, from, old) -> expand -> attemp -> gc(young -> full) -> attemp -> expand -> attemp -> gc -> attemp`

在TLAB外分配，调用链为 `MemAllocator::mem_allocate_outside_tlab -> GenCollectedHeap::mem_allocate -> GenCollectedHeap::allocate_work`。和`新建（叫分配也行）新的TLAB`一样，都是调用`GenCollectedHeap::allocate_work`，只是`分配的大小`不同。


#### 垃圾收集
- Serial GC有关的`VMOp`（`VMThread的操作`）
  - `VM_GenCollectForAllocation` `VM_CollectForAllocation` 堆对象分配失败触发GC
  - `VM_CollectForMetadataAllocation` 元空间分配失败触发GC
  - `VM_GC_HeapInspection` 堆侦探剖析造成GC
  - `VM_GenCollectFull` 这里不是full GC，错误命名了

`GenCollectedHeap`除了普通GC接口`collect`、`do_full_collection`、`collect_as_vm_thread`外，还有下面分代接口:
- `collect_generation` 根据传入的分代对象（`Generation`及其子类），调用方法`Generation::collect`收集该代垃圾
- `do_collection` 根据传入的参数，判断是否该收集某个代的垃圾，之后调用`collect_generation`完成操作

调用链:
- `GenCollectedHeap::collect` -> `VM_GenCollectFull::doit` -> `GenCollectedHeap::do_full_collection` -> `GenCollectedHeap::do_collection` -> `GenCollectedHeap::collect_generation`
- `GenCollectedHeap::mem_allocate_work` -> `VM_GenCollectForAllocation::doit` -> `GenCollectedHeap::satisfy_failed_allocation` -> `GenCollectedHeap::do_collection` -> `GenCollectedHeap::collect_generation`

##### 新生代垃圾收集（young gc）
调用链: `GenCollectedHeap::collect_generation(_young_gen, ...)` -> `DefNewGeneration::collect -> SerialHeap::young_process_roots`。具体操作在`RootScanClosure、OldGenScanClosure、RootScanClosure、ScavengeHelper等`。

先遍历所有根，进行下面操作（`根`的具体类型看下文`full gc`）
- 拷贝可达的对象到`to区域`或者`老年代（晋升promote）`（根据`gc年龄`、`to`区域是否能容纳该对象 决定）。
- 如果不是晋升到老年代，则gc年龄`+1`。
- 修改旧位置的`mardword`为|新地址|11|，代码在`DefNewGeneration::copy_to_survivor_space`。
- 对于已经移动的对象（`mardword`早就为|新地址|11|），则无需上面操作，按照下一步修改对象指针就可以了。
- 修改对象指针为新的值，直接修改对象指针就行，代码在`ScavengeHelper::try_scavenge`。

然后遍历刚刚放在`to`区域、老年代的对象，修改里面的字段对应的对象指针，并且递归执行拷贝操作（操作和上面一样）。`FastEvacuateFollowersClosure::do_void`


##### 老年代垃圾收集（full gc）
调用链: `GenCollectedHeap::collect_generation(_old_gen, ...)` -> `TenuredGeneration::collect` -> `GenMarkSweep::invoke_at_safepoint`。整体流程主要在`GenMarkSweep`中，注意不是`标记-清除`算法，是`标记-压缩`算法，这里错误命名了。

- 标记存活对象 `GenMarkSweep::mark_sweep_phase1`
获取`oop`当前的`markword`，设置`oop`的`markword`为`全0|11|`，如果刚刚获取的`markword`是未锁（`***|01|`）且未计算hash值，则不用保存。否则把刚刚获取的`markword`保存在`MarkSweep::_preserved_marks/_preserved_overflow_stack`中。 
  - 处理根 `GenCollectedHeap::process_roots`。
    - 所有**类加载器**的对象handle，把对象放到`MarkSweep::_marking_stack`（注意这里没有接着遍历这些对象）。 `ClassLoaderDataGraph::roots_cld_do -> CLDToOopClosure::do_cld -> ClassLoaderData::oops_do -> ChunkedHandleList::oops_do`
	- 线程`Thread/JavaThread等`的`oop`相关字段(`Thread::_pending_exception`、`JavaThread::_vm_result/_exception_oop/_jvmci_reserved_oop0/_jvmti_deferred_updates/_jvmti_thread_state/_cont_entry/_lock_stack`等)，线程的handle(`Thread::_handle_area`、`JavaThread::_active_handles/_monitor_chunks/`等)，线程的栈（以栈帧的方式遍历）。 `Threads::oops_do -> Thread::oops_do -> JavaThread::oops_do_no_frames/oops_do_frames`
	- 各个strong的`OopStorage`，存放在`OopStorageSet::_storages`
	- `CodeCache`、`nmethods`
  - 处理各种弱引用`Reference类及其子类的对象`
  - 各个weak的`OopStorage`
  - 卸载类、卸载`nmethods`

- 计算对象新地址 `GenMarkSweep::mark_sweep_phase2`
遍历堆上的所有对象（注意不是遍历`已经标记的存活对象`，也不是像前面一样重新`遍历根`），如果对象需要移动（`对象当前地址`不等于`移动后的地址`），则把移动后的地址放在对象头。之前的`markword`为`全0|11|`，现在变成了`新位置的指针|11|`。如果对象不需要移动，则把`markword`改为`全0|01|`（这步很奇怪）。
注意: Full GC时，新生代的所有对象都会移动到老年代，不管GC年龄。
`Generation::prepare_for_compaction -> ContiguousSpace::prepare_for_compaction -> ContiguousSpace::forward`

- 调整对象指针 `GenMarkSweep::mark_sweep_phase3`
像`标记存活对象`一样，修改对应对象的指针。根据当前指针找到对象，获取对象的`markword`为`新位置的指针|11|`，去掉`11`，把`新位置的指针`存到当前指针位置。如果`markword`为`全0|01|`，则表示对象不需要移动，也就不用修改对象指针。
代码路径和`标记存活对象`差不多，只不过传入的`Closure`不同。`GenMarkSweep::mark_sweep_phase3 -> GenCollectedHeap::process_roots 遍历所有根 、GenCollectedHeap::generation_iterate 修改堆中字段`。
和`标记存活对象`不同的是，`GenCollectedHeap::process_roots`没有沿着根继续搜索，也就是堆中字段的对象指针还没修改。
注意这里多了一个根: `标记存活对象`阶段产生的`MarkSweep::_preserved_marks/_preserved_overflow_stack`。
`GenCollectedHeap::generation_iterate`才修改堆中字段的对象指针。

- 移动对象到新地址 `GenMarkSweep::mark_sweep_phase4`
移动对象到第2步`计算对象新地址`计算的位置。
代码路径上一步`调整对象指针`差不多，只不过传入的`Closure`不同。`GenMarkSweep::mark_sweep_phase3 -> GenCollectedHeap::generation_iterate`。

- 恢复`markword`、其他清除操作
`标记存活对象`阶段会把一些对象的`markword`保存起来放在`MarkSweep::_preserved_marks/_preserved_overflow_stack`，这里恢复。


#### 需要修改（重构）的内容
- VM_GenCollectFull的名称
- do_collection的`full`参数
