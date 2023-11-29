## G1GC 实现
### 初始化
整体流程和`gc_jvm.md 初始化基本流程`差不多，具体内容在`G1Arguments`和`G1CollectedHeap`。**特定GC内容**如下：

`G1Arguments::conservative_max_heap_alignment`:
设置最大堆对齐信息为`最大区域`大小。调用方法`HeapRegion::max_region_size`，为`512M`。

`G1Arguments::initialize`：
- 调用`GCArguments::initialize`
- G1 特定的内容
  - 计算并行`Worker`线程数 `ParallelGCThreads`
  - 计算`Refinement`线程数 `G1ConcRefinementThreads`
  - 计算并发线程数 `ConcGCThreads`
  - 设置其他参数（用到再看）
  - 调用`G1Arguments::initialize_mark_stack_size`设置标记栈大小`MarkStackSize`
  - 调用`G1Arguments::initialize_verification_types`设置验证类型
  - 设置其他参数（用到再看）

`G1Arguments::initialize_alignments`：
- 初始化卡表相关信息（和`Serial GC`一样调用`CardTable::initialize_card_size`）: 一个卡的大小（一般为`512B`）、移位数
  - 初始化块偏移量表信息（和卡表信息有重复）
  - 初始化`ObjectStartArray`信息（和卡表信息有重复）
- 调用`HeapRegion::setup_heap_region_size`设置堆区域大小`G1HeapRegionSize`相关信息
  - 计算`heap region`大小为 最大堆大小`MaxHeapSize` 除以 区域数(2048)，并且在`1M`到`32M`之间
  - 对齐并设置相关信息
- 初始化对齐信息
  - `空间对齐SpaceAlignment` = 堆区域大小`G1HeapRegionSize`
  - `堆对齐大小HeapAlignment`，在`G1Arguments::calculate_heap_alignment`
- 初始化卡集相关信息 `G1Arguments::initialize_card_set_configuration`（用到再看）

`G1Arguments::initialize_heap_flags_and_sizes`：
调用`GCArguments::initialize_heap_flags_and_sizes`，检测堆大小（初始值、最大值、最小值）关系是否正确、是否对齐，根据这三个大小，互相调整对应的值

`G1Arguments::initialize_size_info`：
调用`GCArguments::initialize_size_info`，只是输出日记。

`G1Arguments::create_heap`：
- 创建的堆为`G1CollectedHeap`

`Universe::initialize_heap -> G1CollectedHeap::initialize`:
- 跟操作系统申请保留一个连续的区域
- 创建卡表`G1CardTable`（Card table）， 放在字段`_card_table`。卡表是记忆集（Remembered Set）的一种实现方式。
  - G1在合并记忆集的时候，使用卡表记录汇总信息。这里是`point-out`记忆集。
- 新建`G1BarrierSet`，设置到静态变量`BarrierSet::_barrier_set`。初始化`G1BarrierSet`
  - `G1BarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/g1/`里面**
    - 读前没有barrier
    - 读后的barrier把对象加到SATB相关队列（Thread::GCThreadLocalData _gc_data::SATBMarkQueue _satb_mark_queue）（注意如果不是并发标记阶段，则直接跳过）
    - 写前的barrier和读后的一样
    - 写后的barrier把对象加入DCQ相关队列（注意如果不是并发标记阶段，也需要加入DCQ，因为DCQ是为了之后修改记忆集）
  - `G1BarrierSetC1` **在`/hotspot/share/gc/g1/c1`里面**
  - `G1BarrierSetC2` **在`/hotspot/share/gc/g1/c2`里面**
- 创建多个`G1RegionToSpaceMapper`，放到`HeapRegionManager`中。
- 卡表初始化 `G1CardTable::initialize`。
  - `申请保留空间`相关内容已经在`G1RegionToSpaceMapper`中。
  - 计算卡表相关地址，注意`_byte_map`是真正的基地址，`_byte_map_base`是假设堆从`0`开始的基地址
- 初始化` G1FromCardCache`（调用方法`G1FromCardCache::initialize`）
- 新建`G1RemSet`、`HeapRegionRemSet`并初始化
  - 这里是`point-in`记忆集。表示`其他区域`有指针指向`该区域`。
  - 每个`HeapRegion`有一个`HeapRegionRemSet __rem_set`，包含`其他卡`指向`该区域`的信息。
  - 每个`HeapRegionRemSet`有一个`G1CardSet _card_set`存储具体的信息
  - 每个`G1CardSet`有一个`G1CardSetHashTable* _table`使用哈系表存储指向`该区域`的**所有区域**
  - `G1CardSetHashTable`的每一项entry叫`G1CardSetHashTableValue`，表示指向`该区域`的**一个区域**的信息
  - `G1CardSetHashTableValue`里面的`_region_idx`是区域index，`_num_occupied`表示卡card数量，`ContainerPtr`表示对应区域的数据结构
  - `ContainerPtr`有5种类型，详见`G1CardSet`的静态字段、方法`add_card、acquire_container、add_to_container、coarsen_container`等。
    - `G1CardSetInlinePtr`在一个64位里面存3-5个卡index，每个index为11-16位
    - `G1CardSetArray`在一个数组里面存大约12个卡index，每个index为16位。数组元素数量由`G1RemSetArrayOfCardsEntries`决定。
    - `G1CardSetBitMap`一个bitmap。bit数量等于 最大卡数 除以 Howl桶数量
    - `G1CardSetHowl`一个4个元素的桶（数组）。Howl桶数量由`G1RemSetHowlNumBuckets`决定。
    - `FullCardSet` 最大卡数（区域大小1M-32M 除以 卡大小512B）
    - 递增规则`G1CardSetInlinePtr` --超过3-5个--> `G1CardSetArray` --超过12个--> `G1CardSetHowl`或者`G1CardSetBitMap`（在Howl中才会变成`G1CardSetBitMap`） --`G1CardSetHowl`超过最大卡数的90%--> `FullCardSet`
    - 注意在不出bug的情况下，`G1CardSetBitMap`是不会`overflow`的
- 新建`块偏移表 G1BlockOffsetTable`并初始化
- 初始化`G1HeapRegionAttrBiasedMappedArray`
- 新建`Worker`线程 `WorkerThreads::initialize_workers`
    - 如果`UseDynamicNumberOfGCThreads`为真，则只新建1个线程（剩下的线程后面GC的时候，在`WorkerThreads::set_active_workers`创建），否则新建`ParallelGCThreads`个线程
    - 新建`WorkerThread`，并启动 `WorkerThreads::create_worker -> os::create_thread、os::start_thread`
    - 把新建的线程放到`WorkerThreads::_workers`
- 新建`G1ConcurrentMark`，里面会创建`G1ConcurrentMarkThread`线程和`Worker`线程`WorkerThreads`
- 初始化`G1Policy`
- 新建`G1ConcurrentRefine`并初始化，里面会创建`G1ConcurrentRefineThread`线程
- 创建`G1ServiceThread`线程和任务`G1PeriodicGCTask`、`G1MonotonicArenaFreeMemoryTask`
- 初始化分配区域`G1AllocRegion`
- 创建`G1MonitoringSupport`
- 初始化`G1CollectionSet`
- 初始化`G1YoungGCEvacFailureInjector`

`init_globals -> gc_barrier_stubs_init`**这里和`Serial GC`一样**:
- 初始化`BarrierSet`的`G1BarrierSetAssembler`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


### 堆内存分配
整体流程和`gc_jvm.md 堆内存分配基本流程`差不多，具体内容在`G1CollectedHeap`、``和``。**特定GC内容**如下：

分配新的TLAB `G1CollectedHeap::allocate_new_tlab`，实现在`G1CollectedHeap::attempt_allocation`:
- 快速分配 `G1Allocator::attempt_allocation`
  - 从之前保留的堆区域`MutatorAllocRegion::_retained_alloc_region`中分配（避免堆区域里面空间浪费）。 `MutatorAllocRegion::attempt_retained_allocation`
    - 原子地递增堆区域的`top`指针。`HeapRegion::par_allocate -> HeapRegion::par_allocate_impl`
  - 从当前堆区域`G1AllocRegion::_alloc_region`中分配。 `G1AllocRegion::attempt_allocation`
    - 原子地递增堆区域的`top`指针。`HeapRegion::par_allocate -> HeapRegion::par_allocate_impl`
- 慢速分配 `G1CollectedHeap::attempt_allocation_slow`
  - **获取锁**
  - 获取新的堆区域在分配 `G1Allocator::attempt_allocation_locked -> G1AllocRegion::attempt_allocation_locked`
    - 现在当前堆区域分配。和前面`快速分配的第2步一样`一样。`G1AllocRegion::attempt_allocation`
    - 在新的堆区域中分配 `G1AllocRegion::attempt_allocation_using_new_region`
      - 当前堆区域退休 `MutatorAllocRegion::retire`
      - 获取新的堆区域，获取不成功则**拓展空间**则获取，注意传入的参数`force`为`false`。 `G1AllocRegion::new_alloc_region_and_allocate -> MutatorAllocRegion::allocate_new_region -> G1CollectedHeap::new_mutator_alloc_region -> G1CollectedHeap::new_region`
      - 在新的堆区域分配，直接设置`top`指针即可（不用原子操作，因为已经获取锁了） `G1AllocRegion::allocate`
      - 更新当前堆区域为新的堆区域
  - **拓展空间**，再获取新的堆区域，再分配。和上一步很像，传入的参数`force`为`true`。`G1Allocator::attempt_allocation_force -> G1AllocRegion::new_alloc_region_and_allocate`
  - **释放锁**
  - 垃圾收集 `G1CollectedHeap::do_collection_pause`
    - 新建`VM_G1CollectForAllocation`，提交给`VMThread`
    - 等待`VMThread`完成`VM_G1CollectForAllocation`
    - **GC成功**，无论分配是否成功，都直接返回（分配成功，则返回对应地址，分配不成功则返回`nullptr`）。GC不成功，则下一步继续。
- 如果上面分配失败，则继续调用回到`快速分配 G1Allocator::attempt_allocation`，循环运行。
  - 一般只循环`4`次，用`GCLockerRetryAllocationCount`设置。
  - `GCLockerRetryAllocationCount`默认是`2`,但是根据代码来看，是重复`4`次。
    - 从`0`开始计算，所以在`GCLockerRetryAllocationCount`基础上加`1`
    - 在`for`循环最后而不是循环开始位置比较`GCLockerRetryAllocationCount`，所以要再加`1`


在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab -> G1CollectedHeap::mem_allocate`:
- 如果是大对象（size大于区域的一半），调用`G1CollectedHeap::attempt_allocation_humongous`进行分配。和`分配新的TLAB`的`G1CollectedHeap::attempt_allocation、G1CollectedHeap::attempt_allocation_slow`很像，区别如下所示
  - `G1Allocator::attempt_allocation_locked -> G1AllocRegion::attempt_allocation_locked`变成了`G1CollectedHeap::humongous_obj_allocate -> HeapRegionManager::allocate_humongous`（具体内容用到再看）
  - 没有调用`G1Allocator::attempt_allocation_force -> G1AllocRegion::new_alloc_region_and_allocate`
- 如果不是大对象，调用`G1CollectedHeap::attempt_allocation`进行分配。和`分配新的TLAB`一样。详见上文。


### 垃圾收集
- G1 GC有关的`VMOp`（`VMThread的操作`）// （不完整）TODO
  - `VM_CollectForMetadataAllocation` 元空间分配失败触发GC
  - `VM_GC_HeapInspection` 堆侦探剖析造成GC
  - `VM_G1CollectForAllocation` 堆对象分配失败触发GC
  - `VM_G1CollectFull` 被`System.gc`调用
  - `VM_G1TryInitiateConcMark` 开始并发标记

除了普通GC接口`collect`、`do_full_collection`、`collect_as_vm_thread`外，还有下面方法:
- `do_collection_pause_at_safepoint`: 被`VM_G1TryInitiateConcMark`和`VM_G1CollectForAllocation`调用，进行`Young GC`，可选的并发收集

- `try_collect_concurrently`: 开始并发收集

- `try_collect_fullgc`： 调用`do_full_collection`完成Full GC
- `upgrade_to_full_collection`： 调用`do_full_collection`完成Full GC
- `satisfy_failed_allocation`和`satisfy_failed_allocation_helper`： 被`VM_G1CollectForAllocation`调用，会调用`do_full_collection`完成Full GC

- `do_collection_pause`: 分配不成功则调用此方法，之后调用`VM_G1CollectForAllocation`进行收集
  - 先调用`do_collection_pause_at_safepoint`进行Young GC
  - 再调用`satisfy_failed_allocation`或`upgrade_to_full_collection`进行Full GC

- `collect -> G1CollectedHeap::try_collect`: 根据具体的原因，调用上面列出的不同的收集方法


#### 新生代垃圾收集（young gc）
用户`Java线程`一个调用链:
```shell
VMThread::execute vmThread.cpp:555
G1CollectedHeap::do_collection_pause g1CollectedHeap.cpp:2373
G1CollectedHeap::attempt_allocation_slow g1CollectedHeap.cpp:456
G1CollectedHeap::attempt_allocation g1CollectedHeap.cpp:642
G1CollectedHeap::allocate_new_tlab g1CollectedHeap.cpp:388
MemAllocator::mem_allocate_inside_tlab_slow memAllocator.cpp:305
MemAllocator::mem_allocate_slow memAllocator.cpp:342
MemAllocator::mem_allocate memAllocator.cpp:360
MemAllocator::allocate memAllocator.cpp:367
CollectedHeap::obj_allocate collectedHeap.inline.hpp:36
InstanceKlass::allocate_instance instanceKlass.cpp:1434
Runtime1::new_instance c1_Runtime1.cpp:365
```

`VMThread`的一个调用链为:
```shell
G1YoungCollector::collect g1YoungCollector.cpp:1011
G1CollectedHeap::do_collection_pause_at_safepoint_helper g1CollectedHeap.cpp:2576
G1CollectedHeap::do_collection_pause_at_safepoint g1CollectedHeap.cpp:2498
VM_G1CollectForAllocation::doit g1VMOperations.cpp:142
```

`WorkerThread`做一些前置工作（都是`VMThread`提交给`WorkerThread`处理，下文不再重复），主要是撤销所有线程的`TLAB`和处理所有线程的`DirtyCardQueue`:
代码在`G1PreEvacuateCollectionSetBatchTask`和`G1BatchedTask`，`G1PreEvacuateCollectionSetBatchTask::work`。

`G1BatchedTask`实现了一个批处理模型，使用`add_serial_task`和`add_parallel_task`添加任务线性任务和并行任务，
如果是线性任务则每个线程处理一个线性任务，认领任务需要比较`G1BatchedTask::_num_serial_tasks_done`和`G1BatchedTask::_serial_tasks的长度`。
如果是并行任务，则需要任务自己处理并行的情况，Parallel GC一般使用分片或者`类加载器、线程`的`claim`位来获取具体任务，
G1的`G1JavaThreadsListClaimer`实现了一个批量获取具体线程的方式。

`VMThread`线程做一些前置工作 `G1YoungCollector::pre_evacuate_collection_set`
- 调用`G1YoungCollector::calculate_collection_set -> G1CollectionSet::finalize_initial_collection_set`选择需要的GC集合`CollectionSet`
- 调用`ReferenceProcessor::start_discovery`选择标记正在发现引用、设置引用发现策略
- 调用`G1EvacFailureRegions::pre_collection`设置撤离`evacate`失败对应的数据结构
- 调用`G1CollectedHeap::gc_prologue`递增收集计数
- 调用`G1Allocator::init_gc_alloc_regions`初始化要移动到的区域（survivor和老年代的一些区域）
- // TODO 其他操作

`WorkerThread`执行合并记忆集工作:
代码在`G1MergeHeapRootsTask`、`G1MergeCardSetClosure`等。
遍历所有区域的记忆集，进行下面操作:
- 把全局卡表的对应位置置为`dirty`。`G1MergeCardSetClosure::do_card_range -> G1CardTable::mark_range_dirty`
- 设置`G1RemSetScanState::_region_scan_chunks`对应的块为`dirty`。`G1MergeCardSetClosure::do_card_range -> G1MergeCardSetClosure::set_chunk_range_dirty`
- 把需要遍历的区域放到`G1RemSetScanState::_next_dirty_regions`。`remember_if_interesting`
因为有时候，很多区域被同一个区域引用，所以需要合并，减少后续扫描的操作时间。详见[JDK-8213108](https://bugs.openjdk.org/browse/JDK-8213108)

具体的收集操作:
`VMThread`调用栈:
`G1YoungCollector::collect -> G1YoungCollector::evacuate_initial_collection_set -> run_task_timed(G1EvacuateRegionsTask)`

下文扫描的每个`Oop`指针都要进行的操作:
代码在`G1ParCopyClosure`、
- 判断`Oop`是否在收集集合`CollectionSet`（也就是是否应该处理）
  - 如果不是，则处理大对象、可选集、对象标记（需要并发标记时）等情况。
    - 如果是大对象，则标记它为存活`live`
    - 如果是可选集对应的地址，则加入`G1ParScanThreadState::_oops_into_optional_regions`，后面再次遍历。
      - 代码见: `G1ParCopyClosure::do_oop_work -> G1ParScanThreadState::remember_root_into_optional_region`
    - 如果是并发标记，则标记非`CollectionSet`的对象
      - 代码在`G1ParCopyClosure::do_oop_work -> G1ParCopyHelper::mark_object -> G1ConcurrentMark::mark_in_bitmap`
      - 在`G1ConcurrentMark::G1CMBitMap _mark_bitmap`设置对应的`bit`位为`1` `MarkBitMap::par_mark`
      - 增加活跃对象总数量 `G1ConcurrentMark::add_to_livenes`
  - 如果是，判断对象是否被标记
    - 如果已被标记`|新地址指针|11`，则修改指针即可
    - 如果未被标记，则调用`G1ParScanThreadState::copy_to_survivor_space`复制可达对象到新的区域（根据本来是old还是new、GC年龄选择区域）
      - 复制前先分配空间
        - 注意这里先使用的是每个GC线程的分配缓存（`Per-thread local allocate buffer`, 缩写`PLAB`）
        - 整体分配过程和上文的对象分配很像，先在`PLAB`分配，再在分配新的`PLAB`进行分配，不行则直接分配。
      - 复制对象 `Copy::aligned_disjoint_words`
      - 设置旧地址的markword为`|新地址指针|11`
      - 递增GC年龄和对应的数量
      - 如果是对象数组，则添加对应的`ScannerTask(PartialArrayScanTask)`到任务队列`G1ParScanThreadState::G1ScannerTasksQueue _task_queue`。
      - 如果是字符串，则添加对象到`_string_dedup_requests`，为了之后字符串去重。
      - 递归遍历该对象的`Oop`字段，每个字段添加对应的`ScannerTask`到`G1ParScanThreadState`

`WorkerThread`具体收集操作：
代码在`G1EvacuateRegionsTask`、`G1EvacuateRegionsBaseTask`、`G1RootProcessor`
- 扫描根 `G1EvacuateRegionsBaseTask::work -> G1EvacuateRegionsTask::scan_roots`
  - 扫描平常的根 `G1RootProcessor::evacuate_roots`
    - 扫描Java相关的根，线程及CodeCache、类加载器。`G1RootProcessor::process_java_roots`
    - 扫描虚拟机相关的根`OopStorageSet`。`G1RootProcessor::process_vm_roots`
    - 扫描并发标记发现的引用。
  - 扫描前面合并的记忆集。`G1RemSet::scan_heap_roots`
    - 遍历所有区域 `G1RemSetScanState::_next_dirty_regions`
      - 在一个区域中，获取对应的dirty卡开始和结束位置 （使用全局卡表）`G1CardTableChunkClaimer::has_next`
      - 根据上一步的dirty卡的范围，构建`ChunkScanner`进行具体的扫描操作
  - 扫描上2个步骤产生的，`递增`的`CollectionSet`的**间接引用**和`menthods`。
    - `G1RemSet::scan_collection_set_regions`
    - 具体集合在`G1CollectionSet::_collection_set_regions`，开始下标为`_inc_part_start`
    - 最开始的扫描（也就是说，不是可选的收集集合`_optional_old_regions`）则是扫描整个`_collection_set_regions`
- 递归复制（也叫`撤离`）对象 `G1EvacuateRegionsBaseTask::work -> G1EvacuateRegionsTask::evacuate_live_objects -> G1ParEvacuateFollowersClosure::do_void`
  - 处理队列`G1ParScanThreadState::_task_queue`里面的对象
    - 代码在`G1ParScanThreadState::trim_queue -> G1ParScanThreadState::trim_queue_to_threshold`
    - 注意处理过程中`G1ParCopyClosure`也会不断往队列中加任务
  - 窃取其他`WorkerThread`线程的工作
    - 和Parallel GC差不多

`VMThread`进行GC后的操作:
`G1YoungCollector::post_evacuate_collection_set`:
- 处理引用`G1YoungCollector::process_discovered_references`，详见`reference.md`
- 处理弱根，只计数。`WeakProcessor::weak_oops_do`（并行处理）
- 其他 // TODO


#### 混合收集（mixed gc)
整体流程:
- `Young GC`前或者其他时机（见下文），会判断是否需要并发标记
- 进行`Young GC`
- 一次`Young GC`完成后，使用这次`Young GC`的信息作为初始标记，进行并发标记
- 并发标记完成（期间可能有多次`Young GC`）
- 下一次需要GC的时候，则进行`Mixed GC`
内容和`young GC`差不多，只是`G1CollectionSet::finalize_initial_collection_set`选择的收集集合`CollectionSet`多了老年代的区域。
加了并发标记的阶段，下文主要说并发标记。

并发标记的时机（不完整）：
- 分配失败
  - `do_collection_pause_at_safepoint`将要`Young GC`前，会先调用`G1Policy::decide_on_concurrent_start_pause`决定是否需要并发标记
    - 调用`G1Policy::initiate_conc_mark`设置`_in_concurrent_start_gc`为`true`，`young GC`会进行一些特殊处理，比如标记老年代的对象
    - `G1Policy::decide_on_concurrent_start_pause`是否并发标记主要由`G1CollectorState::_initiate_conc_mark_if_possible`决定
  - 如果需要，则在`Young GC`后，调用`G1CollectedHeap::start_concurrent_cycle`开启并发标记
- 调用`try_collect -> try_collect_concurrently`时
  - 即`G1CollectedHeap::should_do_concurrent_full_gc`返回`true`时。注意这里可能进行`Mixed GC`或者`Full GC`
  - `try_collect_concurrently`会调用`VM_G1TryInitiateConcMark`执行并发标记
    - `VM_G1TryInitiateConcMark::doit`会调用`G1CollectedHeap::do_collection_pause_at_safepoint`执行`Mixed GC`（这里和第一点`分配失败`的情况一样了）
    - 如果`do_collection_pause_at_safepoint`不成功，`VM_G1TryInitiateConcMark::doit`会调用`G1CollectedHeap::upgrade_to_full_collection`执行`Full GC`
- 元空间分配失败是，`VM_CollectForMetadataAllocation::doit`也是最终调用`G1CollectedHeap::do_collection_pause_at_safepoint`执行并发标记

会设置`G1CollectorState::_initiate_conc_mark_if_possible`的地方
- `G1CollectedHeap::attempt_allocation_at_safepoint`在有大对象时，会设置它为`true`（它指`initiate_conc_mark_if_possible`）
- `G1Policy::record_full_collection_end`，即`Full GC`后，会设置它（`G1Policy::need_to_start_conc_mark`）
- `G1CollectedHeap::try_collect_concurrently`会调用`G1Policy::force_concurrent_start_if_outside_cycle`设置它为`true`
- `G1CollectedHeap::start_concurrent_gc_for_metadata_allocation`调用`G1Policy::force_concurrent_start_if_outside_cycle`设置它为`true`
- 还有很多。。

注意:
`STW`的工作也就是提交给`VMThread`的工作。`VMThread`也会提交任务给`WorkerThread`进行并行操作。
并发的工作在`G1 Main Marker`线程进行，对应`G1ConcurrentMarkThread`线程。
`G1ConcurrentMarkThread`也会提交任务给自己的`WorkerThread`进行并行操作（这时就是`并发 + 并行`的了）。
区别是`G1ConcurrentMarkThread`不用进入安全点，`VMThread`需要进入安全点。

并发标记流程 `G1ConcurrentMarkThread::run_service -> G1ConcurrentMarkThread::concurrent_mark_cycle_do`:
- 初始标记，就是`Young GC`里面的标记
  - `Young GC`在遍历到不是自己的`CollectionSet`的对象时，会设置`G1ConcurrentMark::_mark_bitmap`的对应`bit`位（标记对象）。代码见上文。
  - `Young GC`在复制（撤离）对象的时候，会分配`OldGCAllocRegion`和`SurvivorGCAllocRegion`（都是`G1GCAllocRegion`的子类），并复制对象到这些区域
    - 在这些区域退休`retire`的时候（即不使用这些区域分配对象时，可以理解成区域已满），会把区域放到`G1ConcurrentMark::_root_regions`
    - 代码在`G1GCAllocRegion::retire_region -> G1CollectedHeap::retire_gc_alloc_region`

- 扫描根（并发）`G1ConcurrentMarkThread::phase_scan_root_regions -> G1ConcurrentMark::scan_root_regions`
  - 这里的根也就是`Young GC`新分配的区域`G1ConcurrentMark::_root_regions`
  - `G1ConcurrentMarkThread`提交任务`G1CMRootRegionScanTask`给`WorkerThread`线程并行运行。`G1CMRootRegionScanTask::work`
    - 在`G1ConcurrentMark::_root_regions`中不断获取区域，对获取到的区域进行处理 `G1ConcurrentMark::scan_root_region`
    - 对区域的每个对象执行`G1RootRegionScanClosure::do_oop_work`操作
    - 主要是使用`G1ConcurrentMark::mark_in_bitmap`标记对象（和`Young GC`的处理非`CollectionSet`对象的操作一样）。
      - 在`G1ConcurrentMark::G1CMBitMap _mark_bitmap`设置对应的`bit`位为`1` `MarkBitMap::par_mark`。
      - 增加活跃对象总数量 `G1ConcurrentMark::add_to_livenes`
  - 注意，根扫描阶段，不能进行`Young GC`
    - 代码在`G1YoungCollector/G1ConcurrentMark::wait_for_root_region_scanning`和`G1CMRootMemRegions::scan_finished`

- 启动并发标记 `G1ConcurrentMarkThread::phase_mark_loop`
  - 并发标记（并发）`G1ConcurrentMarkThread::subphase_mark_from_roots -> G1ConcurrentMark::mark_from_roots`
    - 前面已经标记了从根出发的对象（根出发的新生代所有对象、根直接引用的老年代对象），这里需要处理`SATB`和递归遍历已经标记的对象。
    - `G1ConcurrentMarkThread`提交任务`G1CMConcurrentMarkingTask`给`WorkerThread`线程并行运行。`G1CMConcurrentMarkingTask::work -> G1CMTask::do_marking_step`
      - 预测本次标记花费的时间
      - 处理SATB队列（`G1BarrierSet::_satb_mark_queue_set`包含了所有线程提交的SATB队列） `G1CMTask::drain_satb_buffers`
        - 遍历每个队列和其中的每个对象。代码在`G1CMSATBBufferClosure::do_buffer -> do_entry -> G1CMTask::make_reference_grey`
        - 标记对象和计数 `G1ConcurrentMark::mark_in_bitmap`，如果之前已经标记过，则直接返回，不用进行后续操作。
        - 如果是原子类型数组`is_typeArray`，则直接处理该对象的字段。 `G1CMTask::process_grey_task_entry` **递归标记对象的字段指向的对象**
        - 如果是其他类型，则把对象任务放到`G1CMTask::G1CMTaskQueue* _task_queue`或者`G1CMMarkStack _global_mark_stack`中。后续再扫描其字段。
      - 处理本地的任务队列`G1CMTaskQueue* _task_queue` `G1CMTask::drain_local_queue`
        - 获取任务并处理 `G1CMTask::scan_task_entry -> G1CMTask::process_grey_task_entry` **递归标记对象的字段指向的对象**
        - 只处理一部分，留下固定数量的任务在队列上，由参数`GCDrainStackTargetSize`决定或者`最大数量/3`
      - 处理全局的任务队列`G1CMMarkStack _global_mark_stack`
        - 先从全局队列中获取任务到本地的任务队列
        - 再调用`G1CMTask::drain_local_queue`进行处理
      - （循环开始）如果是大对象区域并且被标记，则直接调用`G1CMBitMapClosure::do_addr`进行处理
        - 处理对象 `G1CMTask::process_grey_task_entry`
        - 处理本地和全局的任务队列
      - 如果是普通区域，则遍历区域`G1CMBitMap::iterate`，对每个标记对象调用`G1CMBitMapClosure::do_addr`进行处理（内容和前面一样）
      - 再次处理本地和全局的任务队列
      - 认领一个新的区域 `G1ConcurrentMark::claim_region`
      - 设置区域相关的值，比如`_curr_region`和`_finger` `G1CMTask::setup_for_region`
      - 认领成功则跳到前面（循环开始）继续运行
      - 再次处理本地和全局的任务队列，注意这时候要全部处理
      - 调用`G1ConcurrentMark::try_stealing`窃取其他线程的任务
      - 其他，不重要
  - 预清理引用，和正常清理`refenrece.md`有差异（并发，可选，参数`G1UseReferencePrecleaning`控制）`G1ConcurrentMarkThread::subphase_preclean`
    - 代码在`G1ConcurrentMarkThread::subphase_preclean -> G1ConcurrentMark::preclean -> ReferenceProcessor::preclean_discovered_references`
    - 把`已处理的引用`和`还存活的引用`从`引用队列`中删除，为了减少之后正常清理的工作
  - 再标记（STW）`G1ConcurrentMarkThread::subphase_remark（G1ConcurrentMarkThread线程）`
    - `VMThread`线程调用`VM_G1PauseRemark::work -> G1ConcurrentMark::remark`
    - `VMThread`线程调用`G1ConcurrentMark::finalize_marking`提交任务`G1CMRemarkTask`给`WorkerThread`
    - `WorkerThread`调用`G1CMRemarkTask::work`进行处理
      - 调用`G1RemarkThreadsClosure::do_thread`把所有线程自己的`SATB`队列加到全局的集合`G1BarrierSet::_satb_mark_queue_set`中
      - 调用`G1CMTask::do_marking_step`进行标记，和上文`并发标记`一样
    - 处理引用，详见`refenrece.md` `G1ConcurrentMark::weak_refs_work -> ReferenceProcessor::process_discovered_references`
    - // TODO 其他工作，用到再看
  - 是否需要下一轮并发标记，需要则回到`启动并发标记`重新运行 `G1ConcurrentMarkThread::mark_loop_needs_restart -> G1ConcurrentMark::has_overflown`

- 重建记忆集、清洗死对象（并发）`G1ConcurrentMarkThread::phase_rebuild_and_scrub -> G1ConcurrentMark::rebuild_and_scrub`
  - 代码在`G1ConcurrentRebuildAndScrub`、`G1RebuildRSAndScrubTask`
  - // TODO 用到再看

- 清理（STW）`G1ConcurrentMarkThread::phase_cleanup`
  - `VMThread`线程调用`VM_G1PauseCleanup::work -> G1ConcurrentMark::cleanup`
  - `G1Policy::record_concurrent_mark_cleanup_end -> G1CollectionSetChooser::build`会计算可以给`Mixed GC`收集的区域
    - `G1BuildCandidateRegionsTask`、`G1BuildCandidateRegionsClosure`会判断区域是否需要收集，并加入数组`G1BuildCandidateRegionsTask_result`
    - `G1BuildCandidateRegionsTask::sort_and_prune_into`会排序候选区域数组并选择前面几个区域
    - `G1CollectionSetCandidates::set_candidates_from_marking`会把选择的区域放到`G1CollectionSetCandidates::_marking_regions`在后面使用
  - `G1Policy::record_concurrent_mark_cleanup_end -> G1Policy::next_gc_should_be_mixed`判断刚刚是否有区域被选择，有则设置`G1CollectorState::_in_young_gc_before_mixed`为`true`
  - `G1CollectorState::_in_young_gc_before_mixed`为`true`
  - // TODO 用到再看
- 其他清理工作（并发）

`Young GC`结束的时候，`G1Policy::record_young_collection_end`会调用`G1CollectorState::young_gc_pause_type`，
根据`G1CollectorState::_in_young_gc_before_mixed`获取`G1GCPauseType`，如果`G1GCPauseType`是`LastYoungGC`，
则设置`_in_young_gc_before_mixed`和`_in_young_only_phase`为`false`。 下一次GC时，
`G1CollectionSet::finalize_initial_collection_set -> finalize_old_part`会调用`in_mixed_phase`判断是否是`Mixed GC`。
如果是`Mixed GC`，则调用`G1Policy::select_candidates_from_marking`从`G1CollectionSetCandidates::_marking_regions`选取区域。


#### 老年代垃圾收集（full gc）
GC时机: 一般是多次其他GC后，复制（撤离）失败或者分配还不成功，则进行`Full GC`。

代码在 `VM_G1CollectFull`、`G1CollectedHeap::do_full_collection`、`G1FullCollector::collect`等。
下文如果没特别说明，代码在`VMThread`线程运行。

思想和`Serial GC`的`Full GC`差不多，只不过G1是并行运行。并行重用了`G1 Young GC`的一些基础代码。

- 标记对象 `G1FullCollector::phase1_mark_live_objects`
  - `VMThread`线程提交任务`G1FullGCMarkTask`给`WorkerThread`线程
  - `WorkerThread`线程调用`G1FullGCMarkTask::work -> G1RootProcessor::process_strong_roots`进行标记。代码在`StrongRootsClosures`
    - 和`Young GC`一样，使用`G1RootProcessor::process_java_roots`和`G1RootProcessor::process_vm_roots`处理根，只不过传入的`closure`不一样
  - 引用处理，详见`reference.md` `ReferenceProcessor::process_discovered_references`
  - // TODO 其他操作
- 计算新地址 `G1FullCollector::phase2_prepare_compaction`
  - 选择需要压缩的区域放到`G1FullGCCompactionPoint::_compaction_regions` `G1FullCollector::phase2a_determine_worklists`
  - 并行计算新地址 `G1FullCollector::phase2b_forward_oops`
    - `VMThread`线程提交任务`G1FullGCPrepareTask`给`WorkerThread`线程
    - `WorkerThread`线程 并行计算新地址
  - 线性计算新地址 `G1FullCollector::phase2c_prepare_serial_compaction`
  - 计算大对象新地址 `G1FullCollector::phase2d_prepare_humongous_compaction`
- 调整指针到新地址 `G1FullCollector::phase3_adjust_pointers`
  - `VMThread`线程提交任务`G1FullGCAdjustTask`给`WorkerThread`线程
  - `WorkerThread`线程 并行调整地址
- 移动对象到新地址 `G1FullCollector::phase4_do_compaction`
  - `VMThread`线程提交任务`G1FullGCCompactTask`给`WorkerThread`线程
  - `WorkerThread`线程 并行移动对象
  - 线性移动剩下的对象 `G1FullGCCompactTask::serial_compaction`
  - 线性移动大对象 `G1FullGCCompactTask::humongous_compaction`

