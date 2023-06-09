## Parallel GC 实现
### 初始化
整体流程和`gc_jvm.md 初始化基本流程`差不多，具体内容在`GenArguments`、`ParallelArguments`和`ParallelScavengeHeap`。**特定GC内容**如下：

`GenArguments::conservative_max_heap_alignment`**这里和`Serial GC`一样**:
设置最大堆对齐信息，一般为`1<<16`。ARM32位则是`1<<17`。

`ParallelArguments::initialize`：
- 调用`GCArguments::initialize`
- Parallel GC 特定的内容
  - 计算并行`Worker`线程数 `ParallelGCThreads`
  - 设置其他参数（用到再看）

`ParallelArguments::initialize_alignments`：
- 初始化卡表相关信息（和`Serial GC`一样调用`CardTable::initialize_card_size`）: 一个卡的大小（一般为`512B`）、移位数
  - 初始化块偏移量表信息（和卡表信息有重复）
  - 初始化`ObjectStartArray`信息（和卡表信息有重复）
- 初始化对齐信息
  - `空间对齐SpaceAlignment、分代对齐GenAlignment` = 64 * K * 8 = 2^19 B = 0.5M
  - `堆对齐大小HeapAlignment` = `一个卡大小` * `一个操作系统页大小` = 512 * 4K = 2^21 B = 2M

`ParallelArguments::initialize_heap_flags_and_sizes`：
- 调用`ParallelArguments::initialize_heap_flags_and_sizes_one_pass`
  - 调用`GenArguments::initialize_heap_flags_and_sizes`，和Serial GC一样，见`gc_serial.md`
  - 调整`MinSurvivorRatio`和`InitialSurvivorRatio`
- 计算对齐信息，如果比之前计算的`GenAlignment`大，则：
  - 重新设置`GenAlignment、SpaceAlignment`
  - 再次调用`ParallelArguments::initialize_heap_flags_and_sizes_one_pass`

`GenArguments::initialize_size_info`（这里和Serial GC一样）：
- 人体工学地（ergonomically）设置堆参数。（用到再看）

`ParallelArguments::create_heap`：
- 创建的堆为`ParallelScavengeHeap`

`Universe::initialize_heap -> ParallelScavengeHeap::initialize`:
- 跟操作系统申请保留一个连续的区域
- 在刚刚申请的连续区域中划分新生代、老年代区域，也就是设置对应的边界值。（注意和Serial GC不同，这里低地址是老年代，高地址是新生代）
- 创建卡表`PSCardTable`（Card table），卡表是记忆集（Remembered Set）的一种实现方式。这里的卡表是`point-out`记忆集，表示该卡有指针指向新生代。
- 卡表初始化 `CardTable::initialize`。**这里和`Serial GC`一样**
  - 计算卡表大小（页对齐）、记得要`+1`
  - 申请保留空间
  - 计算卡表相关地址，注意`_byte_map`是真正的基地址，`_byte_map_base`是假设堆从`0`开始的基地址
- 新建`CardTableBarrierSet`，设置到静态变量`BarrierSet::_barrier_set`。**这里和`Serial GC`一样**
  - `CardTableBarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/shared/`里面**
  - `CardTableBarrierSetC1` **在`/hotspot/share/gc/shared/c1`里面**
  - `CardTableBarrierSetC2` **在`/hotspot/share/gc/shared/c2`里面**
- 新建`GC Worker`线程 `WorkerThreads::initialize_workers`
  - 如果`UseDynamicNumberOfGCThreads`为真，则只新建1个线程（剩下的线程后面GC的时候，在`WorkerThreads::set_active_workers`创建），否则新建`ParallelGCThreads`个线程
  - 新建`WorkerThread`，并启动 `WorkerThreads::create_worker -> os::create_thread、os::start_thread`
  - 把新建的线程放到`WorkerThreads::_workers`
- 初始化新生代、老年代的具体信息（很多内容）
  - 新生代，新建`PSYoungGen`。主要是`eden`、`survivor`区的各种设置、各个计数器等
  - 老年代，新建`PSOldGen`。很多，用到再看。
- 初始化自适应大小策略`PSAdaptiveSizePolicy`

`init_globals -> gc_barrier_stubs_init`**这里和`Serial GC`一样**:
- 初始化`BarrierSet`的`CardTableBarrierSetAssembler`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


### 堆内存分配
整体流程和`gc_jvm.md 堆内存分配基本流程`差不多，具体内容在`ParallelScavengeHeap`、`PSYoungGen`、`PSOldGen`。**特定GC内容**如下：

分配新的TLAB `ParallelScavengeHeap::allocate_new_tlab`:
实现在`ParallelScavengeHeap::allocate_new_tlab -> PSYoungGen::allocate`。
在`新生代eden区`分配TLAB，注意这里和`Serial GC`有很大不同，这里不会从`from区`或者`老年代`分配TLAB，也不会进行垃圾收集操作。

在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab -> ParallelScavengeHeap::mem_allocate`:
- 先尝试从`新生代eden区`分配（这一步和分配TLAB一样） `PSYoungGen::allocate`
- 如果上面分配不成功，则获取锁、获取垃圾收集次数
- 再次尝试从`新生代eden区`分配
- 如果上面分配不成功，则判断`分配大小size`是否过大 `ParallelScavengeHeap::should_alloc_in_eden`或者 正在GC `GCLocker::is_active_and_needs_gc` 或者 `0 < _death_march_count < 64`，则调用`ParallelScavengeHeap::allocate_old_gen_and_record`在老年代分配
- 如果上面分配不成功，则新建`VM_ParallelGCFailedAllocation`，并提交给`VMThread`
- 等待`VMThread`**执行垃圾收集操作**，注意操作最后会执行分配，分配结果放在`VM_ParallelGCFailedAllocation::_result`里面（详细收集过程见下文）
- 如果GC后，分配还是不成功，则回到第一步`从新生代eden区分配`继续重复执行这些步骤，直到分配成功（正常返回）或者超过`gc_overhead_limit_exceeded`（放回空指针，之后会报`Out of memory exception`）。


### 垃圾收集
- Parallel GC有关的`VMOp`（`VMThread的操作`）// TODO
  - `VM_ParallelGCFailedAllocation` 堆对象分配失败触发GC
  - `VM_CollectForMetadataAllocation` 元空间分配失败触发GC
  - `VM_GC_HeapInspection` 堆侦探剖析造成GC
  - `VM_ParallelGCSystemGC` 被`System.gc`调用

相关方法:
- `PSScavenge::invoke_no_policy`: 完成一次`Young GC`
- `PSParallelCompact::invoke_no_policy`: 完成一次`Full GC`
- `PSScavenge::invoke`: 先调用`PSScavenge::invoke_no_policy`完成一次`Young GC`，再根据具体情况看是否需要调用`PSParallelCompact::invoke_no_policy`完成一次`Full GC`
- `PSParallelCompact::invoke`: 调用`PSParallelCompact::invoke_no_policy`完成一次`Full GC`

`VM_ParallelGCSystemGC`调用链:
`ParallelScavengeHeap::collect`（这一步在java线程运行，后面的在vm线程） ->
`VM_ParallelGCSystemGC::doit` ->
  `PSParallelCompact::invoke` -> `PSParallelCompact::invoke_no_policy`
  或 `ParallelScavengeHeap::invoke_scavenge` -> `PSScavenge::invoke` -> `PSScavenge::invoke_no_policy 和 PSParallelCompact::invoke_no_policy`

`VM_ParallelGCFailedAllocation`调用链:
`ParallelScavengeHeap::mem_allocate`（这一步在java线程运行，后面的在vm线程） ->
`VM_ParallelGCFailedAllocation::doit` ->
`ParallelScavengeHeap::failed_mem_allocate` ->
  `PSScavenge::invoke` -> `PSScavenge::invoke_no_policy 和 PSParallelCompact::invoke_no_policy`
  和 `ParallelScavengeHeap::do_full_collection` -> `PSParallelCompact::invoke` -> `PSParallelCompact::invoke_no_policy`


#### 新生代垃圾收集（young gc）
`vm线程`调用链:
处理根: `PSScavenge::invoke_no_policy` -> `WorkerThreads::run_task` -> `WorkerTaskDispatcher::coordinator_distribute_task` -> 等待`Worker线程`完成

`vm线程`调用`WorkerTaskDispatcher::coordinator_distribute_task`设置`ScavengeRootsTask`到`WorkerTaskDispatcher::_task`中，并使用信号量唤醒`worker线程`，之后阻塞，直到`worker线程`完成所有操作，之后`worker线程`唤醒`vm线程`。

`worker线程`调用链: `thread_native_entry` -> `Thread::call_run` -> `WorkerThread::run` -> `WorkerTaskDispatcher::worker_run_task`

`worker线程`调用`ScavengeRootsTask::work`具体过程:
- 每种根都要进行下面操作（操作差不多，之后主要看具体根类型怎么并行地运行）:
  - 判断`根、对象的字段等`是否指向新生代，是则把该字段（注意这里是老年代的字段指针）封装成`ScannerTask`，放到`PSPromotionManager::_claimed_stack_depth`。如果是对象数组，则把数组中的每一个对象都封装成`ScannerTask`（这里和Full GC不同，Full GC会把数组整块保存，整块处理）。
  - 调用`PSPromotionManager::drain_stacks_depth`，从`PSPromotionManager::_claimed_stack_depth`中获取`ScannerTask`并运行 `PSPromotionManager::process_popped_location_depth -> PSPromotionManager::copy_to_survivor_space`）
    - 把对象拷贝到survivor区或者老年代（根据`gc年龄`、`to`区域是否能容纳该对象 决定）。
    - 把新地址放在旧位置的markword中，即修改旧位置的`mardword`为`|新地址|11|`
    - 如果不是晋升到老年代，则gc年龄`+1`（gc年龄在新位置的`markword`中）。
    - 对于已经移动的对象（`mardword`早就为`|新地址|11|`），则无需上面操作，按照下一步修改对象指针就可以了。
    - 修改对象指针为新的值
  - 调用`PSPromotionManager::drain_stacks -> PSPromotionManager::drain_stacks_depth`继续处理`PSPromotionManager::_claimed_stack_depth`的`ScannerTask`
  - 注意: `PSPromotionManager::copy_to_survivor_space`会调用`PSPromotionManager::push_contents`递归地提交`ScannerTask`任务。

- 遍历卡表，**每个`worker线程`只处理自己的部分`名为stripe`**。 `PSCardTable::scavenge_contents_parallel -> PSCardTable::scan_objects_in_range`
  - `PSCardTable::scavenge_contents_parallel`前面有一大段关于地址范围的操作
  - 找到对应范围后，调用`PSCardTable::scan_objects_in_range`进行上文所写的操作。
- 遍历 类加载器 和`CodeCache`，**先到达的2个`worker线程`分别遍历这2种类型**
  - 遍历类加载器`ClassLoaderData::_handles`，代码在`PSScavengeCLDClosure::do_cld`和`PSScavengeFromCLDClosure::do_oop`
  - 遍历`CodeCache`，代码在`MarkingCodeBlobClosure::do_code_blob`和`PSPromoteRootsClosure::do_oop_work`
- 遍历各个线程，**每个`worker线程`每次遍历一个线程，直到所有线程被遍历**。代码在`PSThreadRootsTaskClosure::do_thread`和`MarkingCodeBlobClosure::do_code_blob`和`PSScavengeRootsClosure/PSRootsClosure::do_oop_work`
- 遍历`OopStarageSet`，**使用`ParState/BasicParState`来控制并行操作**。`BasicParState::iterate`调用`BasicParState::claim_next_segment`来获取`OopStarage`的一段空间（几个块`Block`），然后逐个调用`Block::iterate`完成操作。最终操作的代码在`PSScavengeRootsClosure/PSRootsClosure::do_oop_work`
- 窃取工作。**`worker线程`最后空闲的时候，会调用``steal_work -> PSPromotionManager::steal_depth`获取其他`worker线程`的任务**
  - 每个`worker线程`有一个`PSPromotionManager`，里面有一个`PSScannerTasksQueue _claimed_stack_depth`存放任务给当前线程使用
  - 同时`PSScannerTasksQueueSet _stack_array_depth`汇总了所有线程的`PSScannerTasksQueue _claimed_stack_depth`，用于任务窃取。

后面处理引用`Reference类及其子类的对象`（详见`reference.md`）和各个弱`weak`的`OopStorage`、调整大小参数等。


#### 老年代垃圾收集（full gc）
`vm线程`调用链: `PSParallelCompact::invoke_no_policy` -> `PSParallelCompact::marking_phase 、adjust_roots、compact`-> `WorkerThreads::run_task` -> `WorkerTaskDispatcher::coordinator_distribute_task` -> 等待`Worker线程`完成

`vm线程`调用`PSParallelCompact::marking_phase`提交任务`MarkFromRootsTask`，进行标记工作。

`worker线程`调用`MarkFromRootsTask::work`**标记对象**（这里的根 比`Young GC`少了卡表），具体过程:
- 遍历类加载器`ClassLoaderData::_handles`。**每个`worker线程`调用`ClassLoaderData::oops_do`时，会根据`ClassLoaderData::_claim`判断是否处理该类加载器**。代码在`CLDToOopClosure::do_cld`和`PCMarkAndPushClosure::do_oop_nv -> ParCompactionManager::mark_and_push`
  - 标记对象 `PSParallelCompact::mark_obj`（注意，之前看的标记过程都是设置`markword`为`|新地址|11`，这里是使用2个`BitMap`存储标记信息） 
    - 处理2个`BitMap`，在`ParMarkBitMap::_beg_bits`设置对象开始位，在`ParMarkBitMap::_end_bits`设置对象结束位
    - 把**对象信息记录在`ParallelCompactData`**
  - 把对象放到任务队列`ParCompactionManager::_oop_stack`
  - 如果使用字符串去重功能`UseStringDeduplication`，则把对象放到任务队列`ParCompactionManager::_string_dedup_requests`
  - 把对象数组放到任务队列`ParCompactionManager::_objarray_stack`（注意: 每次只添加一段到队列中，完成一段之后，在添加下一段。很奇怪，感觉一起添加会好一点。）
  - 使用`ParCompactionManager::follow_marking_stacks`遍历2个栈`ParCompactionManager::_oop_stack/_objarray_stack`，循环标记对象。
- 遍历各个线程和`CodeCache`，**每个`worker线程`每次遍历一个线程，直到所有线程被遍历，注意和Young GC不同，这里还遍历了CodeCache**。代码在`PCAddThreadRootsMarkingTaskClosure::do_thread`和`PCMarkAndPushClosure::do_oop_nv`、`MarkingCodeBlobClosure::do_code_blob`
- 遍历`OopStarageSet`，和Young GC一样**使用`ParState/BasicParState`来控制并行操作**。代码在`PCMarkAndPushClosure::do_oop_nv`
- 窃取工作
  - 和`Young GC`一样，每个`worker线程`有一个`ParCompactionManager`，`ParCompactionManager`里面有`OopTaskQueue`和`ObjArrayTaskQueue`存放任务给当前线程使用
  - 同时`OopTaskQueueSet _stack_array_depth`和`ObjArrayTaskQueueSet`汇总了所有线程的任务，用于任务窃取。

`vm线程`调用`PSParallelCompact::marking_phase`提交任务`ParallelCompactRefProcProxyTask`处理引用`Reference类及其子类的对象`（详见`reference.md`）。

调用`WeakProcessor::weak_oops_do`处理各个弱`weak`的`OopStorage`

`vm线程`调用`PSParallelCompact::summary_phase`处理一些汇总信息，为后面阶段做准备。
- 主要是处理标记阶段的对象信息`ParallelCompactData`。
- 至少要记录每个region和每个block迁移后的地址，为之后精确计算每个对象的新地址做准备
- // TODO

`worker线程`调用`PSAdjustTask::work`**调整根的指针**，具体过程:
- 整体代码在`PCAdjustPointerClosure`和`PSParallelCompact::adjust_pointer`
- 和上文一样遍历根，但是这里不递归处理堆中对象字段。这里不再一一列举根
- 计算对象新地址 `ParallelCompactData::calc_new_pointer`
- 更新根的对象指针

`vm线程`给之后操作划分任务
- 调用`PSParallelCompact::prepare_region_draining_tasks`，把所有需要处理的区域`region`放到`ParCompactionManager`的一个`RegionTaskQueue _region_stack`中，给`worker线程`调用。
- 调用`PSParallelCompact::compact -> PSParallelCompact::enqueue_dense_prefix_tasks`把`稠密的区域`切割成若干任务`UpdateDensePrefixTask`放到`TaskQueue`中，`TaskQueue`再放到`UpdateDensePrefixAndCompactionTask`中，给`worker线程`调用。

`worker线程`调用`UpdateDensePrefixAndCompactionTask::work`**调整指针和迁移对象**，具体过程:
- 调用`TaskQueue::try_claim`获取刚刚`vm线程`设置的任务`UpdateDensePrefixTask`
- 调用`PSParallelCompact::update_and_deadwood_in_dense_prefix`运行刚刚获取的任务（也就是处理`稠密的区域`）
  - 遍历任务对应的空间，判断对象是否被标记
  - 如果对象被标记，说明存活，调用`UpdateOnlyClosure::do_addr -> ParCompactionManager::update_contents`，最终使用`PCAdjustPointerClosure::do_oop_nv -> SParallelCompact::adjust_pointer`来调整指针（这里调整和上文根的调整差不多）
  - 如果对象没被标记，说明死亡，调用`FillClosure`填充对应空间 // 未仔细看，用到再看
- 调用`compaction_with_stealing_work`，处理所有区域
  - `ParCompactionManager::drain_region_stacks`不断从`ParCompactionManager::_region_stack`中获取`region`
  - 使用`PSParallelCompact::fill_region`、`MoveAndUpdateClosure`、`PCAdjustPointerClosure`等进行处理，其中`MoveAndUpdateClosure::do_addr -> Copy::aligned_conjoint_words`负责拷贝对象到新地址
- 窃取工作 上文已写，这里略过

后面调整大小参数等。


`Parallel GC`和`Serial GC`的`Full GC`比较：
`Serial GC`先**从根出发递归**遍历来标记对象，再遍历**整个堆**来计算准确的新地址，再遍历**根（只是根，没递归）和整个堆**来调整地址（更新指针），最后遍历**整个堆**移动对象到新地址。
`Parallel GC`先**从根出发递归并行**遍历来标记对象，再整体计算块`Block`的新地址（不精确计算），再**从根出发并行**计算准确的新地址并更新指针，再整体划分处理堆的任务，再**并行遍历整个堆**计算准确的新地址并更新指针并且移动对象到新地址。

### 可以修改的内容
- young GC 扫描类加载器，要并行化。类似Full GC
- 对象数组添加到任务队列是否可以一次性添加
