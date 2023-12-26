## 单代 ZGC 实现
目录`/hotspot/share/gc/x`存放了单代ZGC的代码。
分代ZGC的代码在`/hotspot/share/gc/z`中，分代ZGC的总结放在文档`gc_gen_zgc.md`。
注意`x`目录和`z`目录有很多相同的代码，只是名字开头由`x/X`改成了`z/Z`。
应该是为了以后删除方便，等`分代ZGC`稳定之后，直接删除整个`x`目录以及公共代码（比如`ZSharedArguments`）即可。


### 初始化
整体流程和`gc_jvm.md 初始化基本流程`差不多，具体内容在`ZSharedArguments`、`XArguments`、`XCollectedHeap`。
**特定GC内容**如下：

`ZSharedArguments::conservative_max_heap_alignment`:
ZGC没使用，直接返回`0`。

`ZSharedArguments::initialize`:
- 调用`GCArguments::initialize`
- 调用单代ZGC的内容 `XArguments::initialize`
  - 检测、设置标记栈最大值
  - 设置使用`NUMA`
  - 设置碎片最大比例 `ZFragmentationLimit`
  - 设置并行线程数`ParallelGCThreads`为CPU数量的`60%`
  - 设置并发线程数`ConcGCThreads`为CPU数量的`25%`或者`12.5%`
  - 检测大页大小 `LargePageSizeInBytes`
  - 设置分配激增容忍比例 `ZAllocationSpikeTolerance`
  - 设置使用技术循环安全点 `UseCountedLoopSafepoints`
  - 设置不使用压缩指针 `UseCompressedOops`
  - 设置一些验证参数

`ZSharedArguments::initialize_alignments -> XArguments::initialize_alignments`:
  - 设置`SpaceAlignment`和`HeapAlignment`为2M

`ZSharedArguments::initialize_heap_flags_and_sizes`:
- 调用`GCArguments::initialize_heap_flags_and_sizes`。检测堆大小（初始值、最大值、最小值）关系是否正确、是否对齐，根据这三个大小，互相调整对应的值。
- 调用单代ZGC方法`XArguments::initialize_heap_flags_and_sizes`。方法为空，什么都不做。

`GCArguments::initialize_size_info`:
ZGC没有重写该方法，直接用`GCArguments`的方法。没内容。

`ZSharedArguments::create_heap -> XArguments::create_heap`:
创建的堆为`XCollectedHeap`。创建`XCollectedHeap`时，执行它的构造函数的时候进行大量的初始化工作。

- 执行父类`CollectedHeap`的构造函数
- 创建`SoftRefPolicy _soft_ref_policy`。（当前没有被使用，见`JDK-8309619`）
- 创建`XBarrierSet _barrier_set`。
  - `XBarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/x/`里面**
  - `XBarrierSetC1` **在`/hotspot/share/gc/x/c1`里面**
  - `XBarrierSetC2` **在`/hotspot/share/gc/x/c2`里面**
  - `XBarrierSetNMethod` **在`/hotspot/share/gc/x`里面**
  - `XBarrierSetStackChunk` **在`/hotspot/share/gc/x`里面**
- 创建`XInitialize`，它的构造函数调用很多初始化函数（用到再看）
  - `XAddress::initialize`、`XNUMA::initialize`、`XCPU::initialize`、`XStatValue::initialize`
  - `XThreadLocalAllocBuffer::initialize`、`XTracer::initialize`、`XLargePages::initialize`
  - `XHeuristics::set_medium_page_size`、`XBarrierSet::set_barrier_set`、`XInitialize::pd_initialize`
  - 其中`XAddress::initialize`初始化地址（指针）内容。（地址偏移量内容`offset`、指针元数据内容`metadata`）
    - 地址位数量 `XAddressOffsetBits`为`42-44`
    - 地址位掩码 `XAddressOffsetMask`为`|后面全0|前面42到44个1|`
    - 地址最大值 `XAddressOffsetMax`为`2^42-44`，2的42-44次方
    - 元数据偏移量 `XAddressMetadataShift`为`42-44`
    - 元数据掩码 `XAddressMetadataMask`为`|后面全0|1111|前面42-44个0|`
    - 各个标记位信息 `|后面全0|XAddressMetadataFinalizable|XAddressMetadataRemapped|XAddressMetadataMarked1|XAddressMetadataMarked0|前面42-44个0|`
    - 当前标记位 `XAddressMetadataMarked`为`XAddressMetadataMarked1`或`XAddressMetadataMarked0`
    - 好地址掩码 `XAddressGoodMask`为`XAddressMetadataMarked0`、`XAddressMetadataMarked1`或`XAddressMetadataRemapped`。好地址掩码只有一位为`1`。
    - 坏地址掩码 `XAddressBadMask`为`XAddressGoodMask ^ XAddressMetadataMask`。坏地址掩码有`4-1=3`位为`1`，除了好地址掩码那一位。
    - 注意栈水平线`XStackWatermark::epoch_id`的值为`XAddressBadMask`的高32位，如果`XAddressBadMask`修改了，说明要重置水平线，重新处理栈。
    - 弱的坏地址掩码 `XAddressWeakBadMask`为`(XAddressGoodMask | XAddressMetadataRemapped | XAddressMetadataFinalizable) ^ XAddressMetadataMask`。处于`mark`阶段时，弱的坏地址掩码有1位（其中一个标记位）为`1`。处于`relocate`阶段时，弱的坏地址掩码有2位（2个标记位）为`1`。
- 新建`XHeap`，管理堆的信息，放入静态变量`XHeap::_heap`。
  - 新建`XWorkers`。里面的`XWorkers::WorkerThreads`会新建独立的多个`Worker`线程。
  - 新建`XObjectAllocator`，负责给Java线程分配对象和TLAB
    - 没有显式的分配TLAB的方法，都是使用`XObjectAllocator::alloc_object`
  - 新建页分配器`XPageAllocator`，负责分配页`page`。
    - 新建`XVirtualMemoryManager`管理虚拟内存，大小一般为`MaxHeapSize * 16 * 3`，注意这里有3份虚拟内存，每份大小为`MaxHeapSize * 16`。
    - 新建`XPhysicalMemoryManager`管理物理内存。实际上是管理一个内存文件，大小为`MaxHeapSize`。`XPhysicalMemory`的段开始地址实际是文件偏移量。
    - 页分配要先在应用层记录内存分配信息，再把内存分配信息提交给操作系统
      - 应用层记录内存分配信息: 使用`XVirtualMemoryManager::alloc`分配虚拟内存，使用`XPhysicalMemoryManager::alloc`分配物理内存（或者使用另一个页的物理内存`XPageAllocator::alloc_page_create`）。
      - 内存分配信息提交给操作系统: 使用`XPhysicalMemoryManager::commit`提交物理内存，使用`XPhysicalMemoryManager::map`映射虚拟内存到物理内存（因为物理内存有3份，这里也要`map`3次）
    - 新建`XUnmapper`线程。其它线程合并页的时候提交不需要的页到`XUnmapper::_queue`（`XPageAllocator::alloc_page_create`），`XUnmapper`线程负责`unmap`和清除`destroy`这些页。（注意这里不需要`uncommit`，因为物理内存要给新合成的页使用）
    - 新建`XUncommitter`线程。`XUncommitter`线程从`PageCache`中获取空闲很久的页，`unmap`、`uncommit`、清除`destroy`这些页。注意这里需要`uncommit`，因为这些页是无用的，被cache起来的。
  - 新建页表`XPageTable`，负责映射地址到其页`page`。一个哈系表，`key`为地址的高位（去掉前21位），`value`为包含该地址的页。（`XPageCache`则是管理未被使用的页。）
  - 新建转发表`XForwardingTable`，记录迁移对象的位置信息（用于relocate、remap）
  - 新建`XMark`，负责标记操作
  - 新建`XReferenceProcessor`，负责引用处理
  - 新建`XWeakRootsProcessor`，负责弱根处理
  - 新建`XRelocate`、`XRelocationSet`，负责对象迁移
  - 新建`XUnload`，负责类卸载处理
  - 新建`XServiceability`，`Serviceability`相关内容。
- 新建`XDriver`
  - 新建线程，负责接受、运行`GC`请求。
  - `XDirector`和`mutator`线程使用`XDriver::collect -> XMessagePort::send_*`方法发送`GC`请求。
  - `XDriver`自己的线程使用`XMessagePort::receive`接受`GC`请求。
  - 注意: 虽然发送、接受、运行`GC`请求的代码都在`XDriver`类，但是它们是被不同线程运行。
- 新建`XDirector`
  - 新建线程，负责定时（每10毫秒）获取采样数据，根据采样数据来判断是否触发GC，最后调整GC。
  - 注意这里的采样数据和`XStat`的不同。
  - 使用`XDriver::collect`发送GC请求给`XDriver`。
- 新建`XStat`。新建对应的线程，负责定时（每1秒）采样和打印数据
- 新建`XRuntimeWorkers`，新建多个`Worker`线程。

`Universe::initialize_heap -> XCollectedHeap::initialize`:
大量工作已经在`XCollectedHeap`的构造函数中。这里的工作很少。
- 判断`XHeap`是否初始化成功。即查询字段`XHeap::_initialized`。
- 计算验证数据 `_verify_oop_mask`和`_verify_oop_bits`。

`init_globals -> gc_barrier_stubs_init`:
初始化`BarrierSet`的`XBarrierSetAssembler`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


### 堆内存分配
整体流程和`gc_jvm.md 堆内存分配基本流程`差不多，具体内容在`XCollectedHeap`、`XHeap`。**特定GC内容**如下：

- 小页为2M，可以存放的对象最大为`2M / 8 = 256K`，也就是对象范围在`(0, 256K]`。
- 中页`XPageSizeMedium`为`MaxHeapSize * 0.03125`，并且在`2M - 32M`之间。可以存放的对象最大为`2M - 32M / 8 = 256K - 4M`，也就是对象范围在`(256K, 256K - 4M]`。如果`MaxHeapSize`为64M以下时，`XPageSizeMedium = MaxHeapSize * 0.03125 = 256K`，中页就完全没用了。其他情况都有用。
- 大页没有固定大小，根据大对象（`256K - 4M`以上）来定。这里类似于G1的大对象（H）区域。对象范围在`4M`以上。

分配新的TLAB `XCollectedHeap::allocate_new_tlab`:
调用`XHeap::alloc_tlab -> XObjectAllocator::alloc_object`负责具体的分配。
- 判断是否是小对象`(0, 256K]`，是则调用`XObjectAllocator::alloc_small_object`进行分配
  - 获取当前CPU共享的小页的地址 `XObjectAllocator::_shared_small_page::addr`
  - 调用`XObjectAllocator::alloc_object_in_shared_page`进行分配
    - 在对应的页上分配对象，原子递增指针`XPage::_top`即可（类似`G1`的在`堆区域HeapRegion`分配）`XPage::alloc_object_atomic`
    - 如果上一步不成功，则**调用`XObjectAllocator::alloc_page`分配新的页（类似`G1`获取新的`堆区域HeapRegion`，详见下文）**
    - 在新的页上分配对象，直接修改指针`XPage::_top`即可（不需要原子修改，因为该页还没放到共享位置）。 `XPage::alloc_object`
    - 把新的页放到对应共享页的地址中，原子操作并不断重试（因为可能有其他线程已经放了新的页）放置共享页失败时:
      - 如果之前的共享页**为空**，则继续重新设置共享页
      - 如果之前的共享页**不为空**，这时候要在新的共享页上原子地分配对象，并把自己申请的页取消 `XObjectAllocator::undo_alloc_page`
- 判断是否是中对象`(256K, 256K - 4M]`，是则调用`XObjectAllocator::alloc_medium_object`进行分配
  - 获取共享中页（所有CPU共享）的地址`XObjectAllocator::_shared_medium_page`
  - 和小对象一样，也是调用`XObjectAllocator::alloc_object_in_shared_page`进行分配，只是传入的页地址、页类型不一样
- 判断是否是大对象`大于 256K - 4M`，是则调用`XObjectAllocator::alloc_large_object`进行分配
  - 没有共享大页，因为大页都是使用的时候才分配
  - 和上文分配页一样，调用`XObjectAllocator::alloc_page`分配页，只是传入的页类型和大小不同。
  - 在新建的页中分配对象（大对象总是分配新的页进行分配，类似G1的大对象总是分配新的连续`堆区域HeapRegion`）

在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab -> XCollectedHeap::mem_allocate`:
调用`XHeap::alloc_object -> XObjectAllocator::alloc_object`进行分配，具体操作和上文分配`TLAB`一样，只是传入的大小不同。


分配新的页具体过程（类似`G1`获取新的`堆区域HeapRegion`）:
调用`XObjectAllocator::alloc_page -> XHeap::alloc_page -> XPageAllocator::alloc_page`
- 调用`XPageAllocator::alloc_page_or_stall`完成分配或挂起
  - 先调用`XPageAllocator::alloc_page_common -> XPageAllocator::alloc_page_common_inner`完成分配
    - **从页缓存`XPageAllocator::_cache`中获取页，获取成功则加入`XPageAllocation::pages`中。`XPageCache::alloc_page`（这一步可能会把较大的页切成较小的页，详见下文）。**
    - 从页缓存获取不成功，则调用`XPageAllocator::increase_capacity`递增堆空间，原子地修改`XPageAllocator::_capacity`。
    - 如果递增的值还不满足要分配的大小，则调用`XPageCache::flush_for_allocation -> XPageCache::flush`，清除、刷新（`flush`）缓存页
      - 虽然说是清除缓存页，其实更像是合并缓存页。
      - 按`大页`、`中页`、`小页`的顺序进行`flush`
      - 已经清除的缓存页大小总和 >= 要分配的大小 就可以返回。也就是说`flush_for_allocation`不一定清除所有的缓存页。
      - `已经清除的缓存页大小总和`不一定刚好**等于**`要分配的大小`，如果是**大于**，剩下的部分则分离出来，作为一个新页放回到页缓存。`XPage::split`、`XPageCache::free_page`
  - 使用`XPageAllocator:increase_used`递增已经使用的大小。原子递增`XPageAllocator::_used`。
  - 如果前面分配不成功，则判断是否应该等待（`stall`），Java线程一般都要等，GC线程一般不等。
  - 如果需要等待，则把对应的`XPageAllocation`放到`XPageAllocator::_stalled`中
  - 然后调用`XPageAllocator::alloc_page_stall -> XCollectedHeap::collect -> XDriver::collect -> XMessagePort::send_async`发送异步`GC`请求。然后暂停线程，等待`GC`完成`。
  - GC完成后，GC线程会调用`XPageAllocator::free_pages -> XPageAllocator::satisfy_stalled`为每个阻塞的`Java线程`分配内存，并唤醒对应的`Java线程`，直到内存用完或者没有阻塞的线程。
    - GC线程和Java线程一样，都是调用`XPageAllocator::alloc_page_common`完成分配操作
    - GC线程调用`XPageAllocation::satisfy -> XFuture::set`唤醒Java线程。
- 上一步分配成功后，调用`XPageAllocator::alloc_page_finalize`做分配最后的工作
  - 前面分配的时候，如果`XPageAllocation::pages`只设置了一个页，则直接使用。`XPageAllocator::is_alloc_satisfied`
  - 如果`XPageAllocation::pages`设置了多个页或0个页
    - 调用`XPageAllocator::alloc_page_create`把多个页汇总成一个页或者新建一个页
    - 提交`commit`新页的内存，`map`内存，然后返回
    - 如果`commit`失败，则清除`commit`不成功的内存
- 如果前面还是失败，则调用`XPageAllocator::alloc_page_failed`
  - 获取、释放`XPageAllocation::pages`的所有页（放到`PageCache`）
  - 像GC线程一样，调用`ZPageAllocator::satisfy_stalled`为每个阻塞的`Java线程`分配内存，并唤醒对应的`Java线程`，直到内存用完或者没有阻塞的线程。（因为上一步释放了内存，类似GC了。如果释放的内存容量大于其他线程请求的内存容量，则可以唤醒并运行其他线程）
  - 重新回到`alloc_page_or_stall`重新进行分配
- 成功则递增计数、重置页、提交事件等
- 把页加入页表`XHeap::_page_table`中
- 原子递增已经使用的大小`XObjectAllocator::_used`。


从页缓存`XPageAllocator::XPageCache _cache`中获取/分配页的具体内容（`XPageCache::alloc_page`）:
- 根据页的大小进行分配
  - 如果是小页，遍历`XPageCache::_small`进行获取 `XPageCache::alloc_small_page`
    - 先从当前NUMA节点获取
    - 再从远程NUMA节点获取（遍历其他NUMA节点）
  - 如果是中页，遍历`XPageCache::_medium`进行获取
  - 如果是大页，遍历`XPageCache::_large`进行获取
- 分配不成功，则调用`XPageCache::alloc_oversized_page`从大页或中页获取较大的页
  - 先从大页缓存中获取。`XPageCache::alloc_oversized_large_page`
  - 上一步失败，再从中页缓存中获取。`XPageCache::alloc_oversized_medium_page`
- 如果从大页或中页获取较大的页成功，则调用`XPage::split`把页分成2部分。
  - 需要的部分用来返回
  - 不需要的部分则调用`XPageCache::free_page`放入缓存


### 垃圾收集
`Java线程`或者`XDirector`线程 使用方法`XDriver::collect`，通过`XMessagePort::send_sync/send_async`发送GC请求给`XDriver`线程。

`Java线程`发送GC请求的一个调用栈
```shell
XDriver::collect xDriver.cpp:223
XCollectedHeap::collect xCollectedHeap.cpp:187
XPageAllocator::alloc_page_stall xPageAllocator.cpp:459
XPageAllocator::alloc_page_or_stall xPageAllocator.cpp:509
XPageAllocator::alloc_page xPageAllocator.cpp:668
XHeap::alloc_page xHeap.cpp:175
XObjectAllocator::alloc_page xObjectAllocator.cpp:72
XObjectAllocator::alloc_large_object xObjectAllocator.cpp:142
XObjectAllocator::alloc_object xObjectAllocator.cpp:168
XObjectAllocator::alloc_object xObjectAllocator.cpp:174
XHeap::alloc_object xHeap.inline.hpp:67
XCollectedHeap::mem_allocate xCollectedHeap.cpp:167
MemAllocator::mem_allocate_outside_tlab memAllocator.cpp:241
MemAllocator::mem_allocate_slow memAllocator.cpp:349
MemAllocator::mem_allocate memAllocator.cpp:361
MemAllocator::allocate memAllocator.cpp:368
XCollectedHeap::array_allocate xCollectedHeap.cpp:162
TypeArrayKlass::allocate_common typeArrayKlass.cpp:94
TypeArrayKlass::allocate typeArrayKlass.hpp:68
oopFactory::new_typeArray oopFactory.cpp:93
OptoRuntime::new_array_C runtime.cpp:267
```

`XDirector线程`发送GC请求的一个调用栈
```shell
XDriver::collect xDriver.cpp:223
XDirector::run_service xDirector.cpp:398
ConcurrentGCThread::run concurrentGCThread.cpp:48
Thread::call_run thread.cpp:220
thread_native_entry os_linux.cpp:789
start_thread 0x00007f06b12f36db
clone 0x00007f06b0e1861f
```

`XDriver线程`执行垃圾收集的调用栈
```shell
XDriver::gc xDriver.cpp:445
XDriver::run_service xDriver.cpp:493
ConcurrentGCThread::run concurrentGCThread.cpp:48
Thread::call_run thread.cpp:220
thread_native_entry os_linux.cpp:789
start_thread 0x00007f06b12f36db
clone 0x00007f06b0e1861f
```

#### 垃圾收集具体流程

**标记开始**（只是设置一些信息，**这一步没有标记根**） `XDriver::pause_mark_start -> XDriver::pause`
`XDriver`提交任务`VM_XMarkStart`给`VMThread`线程。`VMThread`线程调用`VM_XMarkStart::do_operation -> XHeap::mark_start`进行操作:
- 如果有分配等待`stalled`（`XPageAllocator::_nstalled != 0`），则使用`XHeap::set_soft_reference_policy`设置需要清理软引用。
- 反转一些常量到标记阶段状态 `XHeap::flip_to_marked -> XAddress::flip_to_marked`
  - 反转标记位 `XAddressMetadataMarked`为`XAddressMetadataMarked1`或`XAddressMetadataMarked0`
  - **反转好地址掩码 `XAddressGoodMask`为`XAddressMetadataMarked0`、`XAddressMetadataMarked1`。好地址掩码只有一位为`1`。**
  - 坏地址掩码 `XAddressBadMask`为`XAddressGoodMask ^ XAddressMetadataMask`。坏地址掩码有`3`位为`1`，除了好地址掩码那一位。**隐式地设置了`XStackWatermark::epoch_id`。**
  - 弱的坏地址掩码 `XAddressWeakBadMask`为`(XAddressGoodMask | XAddressMetadataRemapped | XAddressMetadataFinalizable) ^ XAddressMetadataMask`。这时处于`mark`阶段，弱的坏地址掩码有1位（其中一个标记位）为`1`。
- 撤销对象分配器`XObjectAllocator`共享的页（这些页用于分配TLAB或者对象） `XObjectAllocator::retire_pages`
- 记录、递增或者重置一些计数信息 `XPageAllocator::reset_statistics`、`XReferenceProcessor::reset_statistics`
- 设置阶段`XGlobalPhase`为`XPhaseMark`
- 重置标记相关信息 `XMark::start`
  - 递增GC全局序列号`XGlobalSeqNum`
  - 递增`CodeCache::_gc_epoch`，`_gc_epoch`为奇数表示正在标记，为偶数表示不在标记阶段
  - 重置标记计数、设置工作线程数、设置Stripe数
- 记录标记开始时的一些计数信息 `XStatHeap::set_at_mark_start`

**并发标记** `XDriver::concurrent_mark -> XHeap::mark -> XMark::mark` 
- **并发标记根** `XDriver`提交任务`XMarkRootsTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`XMarkRootsTask::work`进行标记（最终调用`XMarkOopClosure::do_oop -> XBarrier::mark_barrier_on_oop_field`完成标记操作，**标记具体操作见下文`标记操作详细流程`，这里只列出整体流程**）`XMarkRootsTask::work -> XRootsIterator::apply`
  - 标记`OopStorage`指向的对象（遍历所有的OOP块）
    - 每个Worker线程每次认领`未遍历的OOP块数量 / Worker线程数`个块（并且限制到1-10个块，就是每次最少1个块，最大不能超过10个块）
    - 调用链 `XParallelApply::apply -> XStrongOopStorageSetIterator::apply -> OopStorageSetStrongParState::oops_do`
    - 其它相关的类`XMarkOopClosure`
  - 标记`类加载器数据`指向的对象（遍历`ClassLoaderData`里面的字段`ChunkedHandleList _handles`）
    - 每个Worker线程每次认领一个类加载器
    - 调用链 `XParallelApply:apply -> XStrongCLDsIterator::apply -> ClassLoaderDataGraph::always_strong_cld_do`
    - 其它相关的类`XMarkOopClosure`、`XMarkCLDClosure`、`ClaimingCLDToOopClosure`、`CLDToOopClosure`
  - 标记`Java线程栈`指向的对象
    - 每个Worker线程每次认领一个线程，调用`StackWatermarkSet::finish_processing`处理栈。
    - 调用链 `XParallelApply::apply -> XJavaThreadsIterator::apply -> XMarkThreadClosure::do_thread`
    - 其它相关的类`XMarkThreadClosure`、`StackWatermarkSet::finish_processing`（详见文档`stack_watermark.md`）
  - 标记`nmethod`指向的对象（`ClassUnloading`为假时才需要这一步）
    - 每个Worker线程每次获取16个`XNMethodTableEntry`
    - 调用链 `XParallelApply::apply -> XNMethodsIterator::apply -> XNMethod::nmethods_do -> XNMethodTable::nmethods_do -> XNMethodTableIteration::nmethods_do`
    - 其它相关的类`XMarkOopClosure`、`XNMethod`、`XMarkNMethodClosure`
- **把线程本地的标记栈发布到全局栈列表中** `XMarkRootsTask::work -> XMark::flush_and_free -> XMarkThreadLocalStacks::flush`
- **并发标记堆** `XDriver`提交任务`XMarkTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`XMarkTask::work`递归标记整个堆 `XMarkTask::work -> XMark::work`
  - 获取每个Worker线程需要处理的全局栈列表 `XMarkStripeSet::stripe_for_worker`
  - 获取当前线程的本地标记栈 ` XThreadLocalData::stacks`
  - 不断标记 `XMark::work_without_timeout/work_with_timeout`
    - 从`本地标记栈`中获取对象并标记（`本地标记栈`处理完成后，再从`获取的栈列表`获取栈到本地） `XMark::drain`
      - 获取对象 `XMarkThreadLocalStacks::pop`
      - **如果对象在入栈之前没标记（比如Java线程就不会标记，只入栈），这里就标记对象** `XMark::mark_and_follow -> XPage::mark_object`
      - 递增当前页的活跃对象（大小）数量，先缓存在`XMarkCache`中，之后再写回到`XPage::XLiveMap::_live_objects/_live_bytes`。 `XMarkCache::inc_live -> XMarkCacheEntry::evict`
      - **处理刚刚标记的对象的字段（修正地址、往本地栈添加对象）** `XMark::mark_and_follow -> follow_array_object/follow_object --> XMarkBarrierOopClosure::do_oop -> XBarrier::mark_barrier_on_oop_field`
    - 从本地和全局其他栈列表中窃取标记栈，回到上一步进行处理 `XMark::try_steal`
    - 发布Java线程的标记栈到全局，然后回到前面第一步进行处理。使用了线程握手，详见`handshake.md`。 `XMark::try_proactive_flush -> XMark::try_flush`
    - 标记终止 `XMark::try_terminate`
  - 再次把线程本地的标记栈发布到全局栈列表中 `XMarkThreadLocalStacks::flush`
  - 释放线程本地的标记栈

**`XBarrier::mark_barrier_on_oop_field`标记操作详细流程（remap、标记、往本地栈添加对象、修正地址）:**
- 获取OOP
- 如果是`finalizable`可达
  - 判断是否为已经标记或空地址`XAddress::is_good_or_null`，是则直接返回。
  - **标记对象，详见下文** `XBarrier::mark_barrier_on_finalizable_oop_slow_path -> XBarrier::mark`
  - 修正地址 `XBarrier::self_heal`
- 如果是正常的强可达
  - 把`OOP`类型转换成无符号长整型`typedef unsigned long int	uintptr_t`
  - 判断是否是好地址`XAddress::is_good`，即非坏、非空
    - 非坏`XAddress::is_bad` `value & XAddressBadMask`也就是4个元数据位只能有一个对应的`mark`位为真
    - 非空`XAddress::is_null` `value == 0`也就是非0
  - 如果是好地址，则直接**标记对象，详见下文** `XBarrier::mark_barrier_on_oop_slow_path -> XBarrier::mark`
  - 如果不是好地址，则要标记和修正地址
    - 再次判断是否为好地址或空地址`XAddress::is_good_or_null`，是则直接返回。因为刚刚是坏的，现在好的，说明其他线程已经处理了。
    - **标记对象，详见下文** `XBarrier::mark_barrier_on_oop_slow_path -> XBarrier::mark`
    - 修正地址 `XBarrier::self_heal`

**`XBarrier::mark`详细步骤（remap、标记、往本地栈添加对象）:**
- 如果地址已经标记`XAddress::is_marked`，则直接获取好地址`XAddress::good`
- 如果地址已经remapped`XAddress::is_remapped`，则直接获取好地址
- 如果地址没有remap，则调用`XBarrier::remap -> XHeap::remap_object`获取remap后的好地址（详见remap阶段）
- 调用`XHeap::mark_object -> XMark::mark_object`标记对象（GC线程会直接标记，Java线程只把地址放到栈中）
  - 获取地址所在的页`XPageTable::get`
  - 判断该页是否用于标记阶段分配对象`_seqnum == XGlobalSeqNum`，是则无需处理，因为新分配的对象都默认为已标记
  - 调用`XPage::mark_object -> XLiveMap::set`标记对象。
    - 如果本次GC第一次标记，重置`XLiveMap`的相关数据。
    - 如果本次GC第一次标志该段，则要设置该段为活跃并重置该段bitmap的数据`XLiveMap::reset_segment`。
    - 最后标记该对象`XBitMap::par_set_bit_pair`。如果是强可达则置为`11`，`finalizable`可达置为`01`。
  - **把对象放到线程本地的栈中`XMarkThreadLocalStacks::push`，线程本地的栈满了则把该栈放到全局的栈列表中`XMarkStripe::publish_stack`**
- 如果是`finalizable`可达，则在刚刚的好地址基础上，设置`Finalizable`位
- 返回好地址


**标记结束** `XDriver::pause_mark_end -> XDriver::pause` 
`XDriver`提交任务`VM_XMarkEnd`给`VMThread`线程。`VMThread`线程调用`VM_XMarkEnd::do_operation -> XHeap::mark_end`进行操作:
- 终止标记 `XMark::end -> XMark::try_end`
  - **遍历所有线程，把线程本地的标记栈发布到全局栈列表中**  `XMark::flush -> Threads::threads_do`
  - 如果上一步发布还有栈发布出来，说明标记阶段未能结束，调用`XMark::try_complete`进行标记。
    - `VMThread`线程提交任务`XMarkTask`给`WorkerThread`线程，进行标记操作（具体内容和并发标记一样）
    - 注意这一步是STW的，所以`XMarkTask`有一个超时限制`200us`
  - 更新一些数据
- 设置阶段为`XPhaseMarkCompleted`
- 更新一些数据（这里会停止获取引用`XResurrection::block`，也就是使用`Reference::add`方法不会新增`强可达对象`了）

**继续并发标记** `XDriver::concurrent_mark_continue`
如果上一步`标记结束`没有在有限时间内处理所有标记栈，则会在这里调用`XHeap::mark`继续进行并发标记。其操作和上文`并发标记`一样，除了不用遍历根。这一步完成后，再回到`标记结束`进行处理，直到标记完成。


标记结束后，**并发**进行下面操作:
- 清理一些标记相关的数据和内存 `XDriver::concurrent_mark_free -> XHeap::mark_free -> XMark::free`
- **处理非强引用，详见`reference.md`。**`XDriver::concurrent_process_non_strong_references -> XHeap::process_non_strong_references`
- 清理、重置forwarding表和relocation集合 `XDriver::concurrent_reset_relocation_set -> XHeap::reset_relocation_set`
- 选择relocation集合 `XDriver::concurrent_select_relocation_set -> XHeap::select_relocation_set`
  - 遍历每个页，把页的信息加入到`XRelocationSetSelector`中
    - 如果是标记阶段新分配的页则跳过 `XPage::is_relocatable`
    - 如果页中有活跃对象`XPage::is_marked`，并且**垃圾数超过限制页大小的1/4则注册该页** `XRelocationSetSelector::register_live_page -> XRelocationSetSelectorGroup::register_live_page`
    - 如果页中没有活跃对象则先注册空页 `XRelocationSetSelector::register_empty_page`。如果空页数量查过64个，则批量清除空页 `XHeap::free_empty_pages`。
  - 清除所有空页 `XHeap::free_empty_pages`
  - 选择迁移集合 `XRelocationSetSelector::select -> XRelocationSetSelectorGroup::select`
    - 按活跃对象的数量把注册的页从小到大排序（按区间排序，不是严格的每个页从小到大）`XRelocationSetSelectorGroup::semi_sort`
    - 选择迁移集合（确保堆中碎片不超过25%`ZFragmentationLimit`）
  - 根据选择的迁移集合创建对应的`XForwarding`信息 `XRelocationSet::install`
    - 每个需要迁移的页对应一个`XForwarding`，放在`XRelocationSet::_forwardings`
    - 每个`XForwarding`有一个`XForwardingEntry`数组，每个`XForwardingEntry`条目是一个对象的转移信息
  - 把上一步创建的信息加入`XForwardingTable`哈系表 `XForwardingTable::insert`
    - 一个堆只有一个表，放在`XHeap:_forwarding_table`，`key`为`地址`，`value`为`XForwarding`
    - 也就是表中同一个页的对象地址指向同一个页的`XForwarding`，再从`XForwarding`中获取具体的地址
  - 更新一些数据


**迁移开始** `XDriver::pause_relocate_start -> XDriver::pause`
`XDriver`提交任务`VM_XRelocateStart`给`VMThread`线程。`VMThread`线程调用`VM_XRelocateStart::do_operation -> XHeap::relocate_start`进行操作:
- 反转一些常量到迁移阶段状态 `XHeap::flip_to_remapped -> XAddress::flip_to_remapped`
  - **反转好地址掩码 `XAddressGoodMask`为`XAddressMetadataRemapped`。好地址掩码只有一位为`1`。**
  - 坏地址掩码 `XAddressBadMask`为`XAddressGoodMask ^ XAddressMetadataMask`。坏地址掩码有`3`位为`1`，除了好地址掩码那一位。**隐式地设置了`XStackWatermark::epoch_id`。**
  - 弱的坏地址掩码 `XAddressWeakBadMask`为`(XAddressGoodMask | XAddressMetadataRemapped | XAddressMetadataFinalizable) ^ XAddressMetadataMask`。这时处于`relocation`阶段，弱的坏地址掩码有2位（2个标记位）为`1`。
- 设置阶段`XGlobalPhase`为`XPhaseRelocate`
- 记录迁移开始时的一些计数信息 `XStatHeap::set_at_relocate_start`


**并发迁移** `XDriver::concurrent_relocate -> XHeap::relocate -> XRelocate::relocate` 
`XDriver`提交任务`XRelocateTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`XRelocateTask::work`迁移对象。
`XRelocateTask::work`遍历`XRelocationSet::_forwardings`的每一项（一项对应一页）（**`XRelocationSetParallelIterator`确保各个并发worker线程不会重复获取一个页**），迁移页中所有存活对象`XRelocateClosure::do_forwarding -> XForwarding::object_iterate ---> XRelocateClosure::do_object`。下面是`XRelocateClosure::do_object`的具体操作:
- 调用`XRelocateClosure::relocate_object`迁移对象
  - 在`XForwarding`信息中查看当前对象是否已经被迁移,是则直接返回 `xRelocate.cpp::forwarding_find`
  - 获取对象大小 `XUtils::object_size`
  - 在页中分配对象，详见上文`堆内存分配` `XRelocateSmallAllocator/XRelocateMediumAllocator::alloc_object -> XPage::alloc_object`
  - 把对象从旧地址复制到新地址 `XUtils::object_copy_disjoint`
  - 把新地址信息放到`XForwarding`中 `xRelocate.cpp::forwarding_insert`
    - 如果地址信息存放失败，说明另一个线程已经迁移并处理了该对象，这时候要回收刚刚分配的内存 `XRelocateSmallAllocator/XRelocateMediumAllocator::undo_alloc_object`
    - 中页是共享的，如果其他线程已经在这个页上分配对象，`_top`指针已经改变，这时候已经不能回收刚刚分配的内存，所以只能直接返回，这时候页中多了一个垃圾对象
    - 新地址信息存放失败，使用别的线程存放的新地址
    - **注意: 这里新地址信息存放失败，使用别的线程存放的新地址这种情况也算迁移成功**
- 如果迁移不成功，说明页中空间不够，分配新的页之后再回到上一步分配对象
  - 分配一个新的页 `XRelocateSmallAllocator/XRelocateMediumAllocator::alloc_target_page`
    - 如果是小页，则直接调用`xRelocate.cpp::alloc_page -> XHeap::alloc_page`分配
    - 如果是中页，则要看共享的页`XRelocateMediumAllocator::_shared`是否可用，可用则返回共享页，不可用则像小页一样分配页
    - 如果分配页不成功，说明堆中空间不足，则使用当前的页`in-place`放置对象
  - 如果新页分配成功，则重新回到上一步迁移对象
  - 如果新页分配不成功，说明要使用当前页
    - 认领当前页，不让其他线程访问 `XForwarding::claim_page`
    - 重置当前页的序号`_seqnum`和页顶部地址`_top`
    - 设置`XForwarding::_in_place`为真


