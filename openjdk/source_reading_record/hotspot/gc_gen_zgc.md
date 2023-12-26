## 分代 ZGC 实现
目录`/hotspot/share/gc/z`存放了分代ZGC的代码。
之前无分代的ZGC被移到了`/hotspot/share/gc/x`目录。无分代ZGC的总结放在文档`gc_zgc.md`。
注意`x`目录和`z`目录有很多相同的代码，只是名字开头由`z/Z`改成了`x/X`。
应该是为了以后删除方便，等`分代ZGC`稳定之后，直接删除整个`x`目录以及公共代码（比如`ZSharedArguments`）即可。


### 初始化
整体流程和`gc_jvm.md 初始化基本流程`差不多，具体内容在`ZSharedArguments`、`ZArguments`、`ZCollectedHeap`。
**特定GC内容**如下：

`ZSharedArguments::conservative_max_heap_alignment`:
ZGC没使用，直接返回`0`。

`ZSharedArguments::initialize`:
- 调用`GCArguments::initialize`
- 调用分代ZGC的内容 `ZArguments::initialize`
  - 设置标记栈最大值
  - 设置使用`NUMA`
  - 设置各个线程数（注意这里计算规则和其他GC不一样）
    - 设置并行线程数`ParallelGCThreads`为CPU数量的`60%`
    - 设置并发线程数`ConcGCThreads`为CPU数量的`25%`
    - 设置老年代和新生代的并发线程数`ZYoungGCThreads`和`ZOldGCThreads`
  - 设置运行GC的间隔时间。 `ZCollectionInterval`
  - 设置碎片最大比例 `ZFragmentationLimit`
  - 设置退休年龄相关参数
  - 检测大页大小 `LargePageSizeInBytes`
  - 设置使用技术循环安全点 `UseCountedLoopSafepoints`
  - 设置不使用压缩指针 `UseCompressedOops`
  - 设置一些验证参数

`ZSharedArguments::initialize_alignments -> ZArguments::initialize_alignments`:
  - 设置`SpaceAlignment`和`HeapAlignment`为2M

`ZSharedArguments::initialize_heap_flags_and_sizes`:
- 调用`GCArguments::initialize_heap_flags_and_sizes`。检测堆大小（初始值、最大值、最小值）关系是否正确、是否对齐，根据这三个大小，互相调整对应的值。
- 调用分代ZGC的方法`ZArguments::initialize_heap_flags_and_sizes`。设置`SoftMaxHeapSize`。

`GCArguments::initialize_size_info`:
ZGC没有重写该方法，直接用`GCArguments`的方法。没内容。

`ZSharedArguments::create_heap -> ZArguments::create_heap`:
创建的堆为`ZCollectedHeap`。创建`ZCollectedHeap`时，执行它的构造函数的时候进行大量的初始化工作。

- 执行父类`CollectedHeap`的构造函数
- 创建`SoftRefPolicy _soft_ref_policy`。（当前没有被使用，见`JDK-8309619`）
- 创建`ZBarrierSet _barrier_set`。
  - `ZBarrierSetAssembler` **在`/hotspot/cpu/CPU_NAME/gc/z/`里面**
  - `ZBarrierSetC1` **在`/hotspot/share/gc/z/c1`里面**
  - `ZBarrierSetC2` **在`/hotspot/share/gc/z/c2`里面**
  - `ZBarrierSetNMethod` **在`/hotspot/share/gc/z`里面**
  - `ZBarrierSetStackChunk` **在`/hotspot/share/gc/z`里面**
- 创建`ZInitialize`，它的构造函数调用很多初始化函数
  - `ZGlobalsPointers::initialize`、`ZNUMA::initialize`、`ZCPU::initialize`、`ZStatValue::initialize`
  - `ZThreadLocalAllocBuffer::initialize`、`ZTracer::initialize`、`ZLargePages::initialize`
  - `ZHeuristics::set_medium_page_size`、`ZBarrierSet::set_barrier_set`、`ZJNICritical::initialize`
  - `ZDriver::initialize`、`ZGCIdPrinter::initialize`、`ZInitialize::pd_initialize`
  - 其中`ZGlobalsPointers::initialize`初始化地址（指针）内容。（地址偏移量用`ZOffset`表示，无着色的地址用`ZAddress`表示，它比地址偏移量`ZOffset`多了一个`ZAddressHeapBase`。着色指针用`ZPointer`表示。`）
    - 地址偏移量位数 `ZAddressOffsetBits`为`42-44`
    - 地址偏移量掩码 `ZAddressOffsetMask`为`|后面全0|前面42到44个1|`（注意这里是无着色地址，着色指针的地址偏移量是放在后面的）
    - 地址偏移量最大值 `ZAddressOffsetMax`为`2^42-44`，2的42-44次方
    - 堆开始地址 `ZAddressHeapBaseShift`为`42-44`，`ZAddressHeapBase`为`2^42-44`，2的42-44次方

    - 新生代remap位掩码 `ZPointerRemappedYoungMask`为`ZPointerRemapped10 | ZPointerRemapped00`，位为`0101`，表示新生代不在relocate阶段。`ZPointerRemappedYoungMask`只能为`0101`或者`1010`
    - 老年代remap位掩码 `ZPointerRemappedOldMask`为`ZPointerRemapped01 | ZPointerRemapped00`，为`0011`，表示老年代不在relocate阶段。`ZPointerRemappedOldMask`只能为`0011`或者`1100`
    - 新生代当前标记位 `ZPointerMarkedYoung`为`ZPointerMarkedYoung0`
    - 老年代当前标记位 `ZPointerMarkedOld`为`ZPointerMarkedOld0`
    - finalizable位 `ZPointerFinalizable`为`ZPointerFinalizable0`。finalizable位只和老年代收集相关，因为老年代才处理弱引用？
    - 记忆集位 `ZPointerRemembered`为`ZPointerRemembered0`。
    - `remap`位 `ZPointerRemapped`为`ZPointerRemappedOldMask & ZPointerRemappedYoungMask`，为`0001`，表示新生代和老年代都不在relocate阶段。`ZPointerRemapped`的值只能为`0001`、`0010`、`0100`、`1000`。
    - `load barrier`的好地址掩码 `ZPointerLoadGoodMask`为`ZPointerRemapped`，为`0001`。`ZPointerLoadGoodMask`的值只能为`0001`、`0010`、`0100`、`1000`。
    - `mark barrier`的好地址掩码 `ZPointerMarkGoodMask`为`ZPointerLoadGoodMask | ZPointerMarkedYoung | ZPointerMarkedOld`，为`|0001|01|01|`。
    - `store barrier`的好地址掩码 `ZPointerStoreGoodMask`为`ZPointerMarkGoodMask | ZPointerRemembered`，为`|0001|01|01|01`。
    - `load barrier`的坏地址掩码 `ZPointerLoadBadMask`为`ZPointerLoadGoodMask ^ ZPointerLoadMetadataMask`，为`0001`。`ZPointerLoadBadMask`的值只能为`1110`、`1101`、`1011`、`0111`。
    - `mark barrier`的坏地址掩码 `ZPointerMarkBadMask`为`ZPointerMarkGoodMask ^ ZPointerMarkMetadataMask`，为`|1110|10|10|10|`。
    - `store barrier`的坏地址掩码 `ZPointerStoreBadMask`为`ZPointerStoreGoodMask ^ ZPointerStoreMetadataMask`，为`|1110|10|10|10`。
    - 向量相关的掩码（和数组、向量操作有关，未看）
    - `load barrier`应该平移的位数 `ZPointerLoadShift`为`13`。`ZPointerLoadShift`由`ZPointerLoadGoodMask`的值（`1`所在的位置）决定。
    - **还有一个隐式设置，设置`ZStackWatermark::epoch_id`，即`ZPointerStoreGoodMaskLowOrderBitsAddr`，为`ZPointerStoreGoodMask`的低32位，如果`ZPointerStoreGoodMask`修改了，说明要重置水平线，重新处理栈。注意这里是低32位，单代ZGC是高32位，因为分代ZGC的元数据信息放在低位，而单代ZGC的元数据信息放在高位。**
- 新建`ZHeap`，管理堆的信息，放入静态变量`ZHeap::_heap`。
  - 新建页分配器`ZPageAllocator`，负责分配页`page`。
    - 新建`ZVirtualMemoryManager`管理虚拟内存，大小一般为`MaxHeapSize * 16`并且在`4T-16T`范围内。
    - 新建`ZPhysicalMemoryManager`管理物理内存。实际上是管理一个内存文件，大小为`MaxHeapSize`。`ZPhysicalMemory`的段开始地址实际是文件偏移量。
    - 页分配要先在应用层记录内存分配信息，再把内存分配信息提交给操作系统
      - 应用层记录内存分配信息: 使用`ZVirtualMemoryManager::alloc`分配虚拟内存，使用`ZPhysicalMemoryManager::alloc`分配物理内存（或者使用另一个页的物理内存`ZPageAllocator::alloc_page_create`）。
      - 内存分配信息提交给操作系统: 使用`ZPhysicalMemoryManager::commit`提交物理内存，使用`ZPhysicalMemoryManager::map`映射虚拟内存到物理内存
    - 新建`ZUnmapper`线程。其它线程合并页的时候提交不需要的页到`ZUnmapper::_queue`（`ZPageAllocator::alloc_page_create`），`ZUnmapper`线程负责`unmap`和清除`destroy`这些页。注意这里不需要`uncommit`，因为物理内存要给新合成的页使用。
    - 新建`ZUncommitter`线程。`ZUncommitter`线程从`PageCache`中获取空闲很久的页，`unmap`、`uncommit`、清除`destroy`这些页。注意这里需要`uncommit`，因为这些页是无用的，被cache起来的。
  - 新建页表`ZPageTable`，负责映射地址到其页`page`。一个哈系表，`key`为地址的高位（去掉前21位），`value`为包含该地址的页。（`ZPageCache`则是管理未被使用的页。）
  - 新建`ZAllocatorEden`，负责给Java线程分配对象和TLAB
    - 里面的`ZObjectAllocator`负责具体工作，都是使用`XObjectAllocator::alloc_object`进行分配
    - 放在静态变量`ZAllocator::_eden`
  - 新建`ZAllocatorForRelocation`，负责给GC线程迁移对象时分配页`page`，也给Java线程迁移对象时分配对象。GC线程会每次获取一个页给自己用，避免使用`ZAllocatorForRelocation`共享的页，而Java线程则是使用共享的页。因为GC线程迁移阶段就是迁移操作，不断需要内存，使用自己的页可以加快速度。而Java线程大部分是正常业务工作，所以使用共享页即可。
    - 里面的`ZObjectAllocator`负责具体工作，使用`XObjectAllocator::alloc_object_for_relocation`和`ZObjectAllocator::alloc_page_for_relocation`进行分配
    - 放在静态变量`ZAllocator::_relocation`数组中，数组有15个元素（根据新生代最大年龄确定元素个数）
  - 新建`ZServiceability`，`Serviceability`相关内容。
  - 新建`ZGenerationOld`，`Full GC`相关操作。
    - 里面的`ZWorkers::WorkerThreads`会新建独立的多个`Worker`线程。
  - 新建`ZGenerationYoung`，`Young GC`相关操作。
    - 里面的`ZWorkers::WorkerThreads`会新建独立的多个`Worker`线程。
    - 里面的`ZRemembered _remembered`为全局记忆集，记录指向新生代的老年代页。是`point-out`记忆集
      - 感记录了所有老年代页，再在页自己的`ZRememberedSet`记录具体的指向新生代的地址。
      - `ZRemembered`的`FoundOld`有2个`BitMap`。一个`旧BitMap`给GC遍历时使用，一个`新BitMap`给GC或者Java线程修改。
      - 每个`BitMap`比例为`2^21:1`，一个`byte`表示一个小页`2M`。如果内存为4T（256G * 16），则一个`BitMap`为`2M`。
      - `标记开始`阶段使用`ZRemembered::flip`反转`新BitMap`和`旧BitMap`。（修改`ZRemembered::_current`）
    - 每个老年代的页`Zpage`都有一个`ZRememberedSet`，是局部`point-out`记忆集，记录该老年代页哪些地址指向新生代的页
      - `ZRememberedSet`也有2个`BitMap`。一个`旧BitMap`给GC遍历时使用，一个`新BitMap`给GC或者Java线程修改。
      - 因为每个页大小都是可变的，这里`BitMap`大小也可变。`BitMap`大小为`页大小 / 指针大小（4或8）`。`一个bit`表示`8个byte`（64份之一，和其他GC的卡表差不多）。
      - `标记开始`阶段使用`ZRememberedSet::flip`反转`新BitMap`和`旧BitMap`。（修改`ZRemembered::_current`）
- 新建`ZDriverMinor`，放到静态变量`ZDriver::_minor`。
  - 新建了对应的线程，负责接受并运行`Young GC`请求。
  - `ZDirector`和`mutator`线程使用`ZDriverMinor::collect -> ZDriverPort::send_*`方法发送`Young GC`请求。
  - `ZDriverMinor`自己的线程使用`ZDriverPort::receive`接受`Young GC`请求。
  - 注意: 虽然发送、接受、运行`Young GC`请求的代码都在`ZDriverMinor`类，但是它们是被不同线程运行。
- 新建`ZDriverMajor`，放到静态变量`ZDriver::_major`。
  - 新建了对应的线程，负责接受并运行`Full GC`请求。
  - `ZDirector`和`mutator`线程使用`ZDriverMajor::collect -> ZDriverPort::send_*`方法发送`Full GC`请求。
  - `ZDriverMajor`自己的线程使用`ZDriverPort::receive`接受`Full GC`请求。
  - 注意: 虽然发送、接受、运行`Full GC`请求的代码都在`ZDriverMajor`类，但是它们是被不同线程运行。
- 新建`ZDirector`，放到静态变量`ZDirector::_director`。
  - 新建了对应的线程，负责定时（每10毫秒）获取采样数据，根据采样数据来判断是否触发GC，如果触发GC，是`Young GC`还是`Full GC`。最后调整GC。
  - 采样数据主要有`分配速率、堆的整体信息、新生代和老年代堆的信息、上一次垃圾回收的信息、当前真正进行的垃圾回收信息`。
  - 注意这里的采样数据和`ZStat`的不同。
  - 使用`ZDriverMinor`或`ZDriverMajor`的`ZDriverPort::send_sync/send_async`发送GC请求给`ZDriverMinor`或`ZDriverMajor`。
- 新建`ZStat`
  - 新建`ZStat`线程，负责定时（每1秒）采样和打印数据。
  - 每个`ZStatSampler`有`CPU数`个`ZStatSamplerData`。每个`ZStatCounter`在`ZStatSampler`的基础上再加上`CPU数`个`ZStatCounterData`。
    - 每次有相应操作的时候，对应的`ZStatCounter::ZStatCounterData`计数都会加一。
    - 之后`ZStat`线程会调用`ZStatCounter::sample_and_reset`把所有CPU的计数相加，放到`ZStatSampler::ZStatSamplerData`中。
    - 然后再调用`ZStatSampler::collect_and_reset`把刚刚相加的计数再汇总（如果是非计数，则直接获取或收集）并返回。
    - 最后调用`ZStatSamplerHistory::add`把汇总信息放入对应的`ZStatSamplerHistory::ZStatSamplerHistoryInterval`中。
- 新建`ZRuntimeWorkers`，里面是一个`WorkerThreads`，即多个`Worker`线程。

`Universe::initialize_heap -> ZCollectedHeap::initialize`:
大量工作已经在`ZCollectedHeap`的构造函数中。这里的工作很少。
- 判断`ZHeap`是否初始化成功。即查询字段`ZHeap::_initialized`。
- 直接设置验证数据 `Universe::set_verify_data`。

`init_globals -> gc_barrier_stubs_init`:
初始化`BarrierSet`的`ZBarrierSetAssembler`，还是调用`BarrierSetAssembler::barrier_stubs_init`，这里操作为空。


### 堆内存分配
整体流程和`gc_jvm.md 堆内存分配基本流程`差不多，具体内容在`ZCollectedHeap`、`ZHeap`、`ZAllocatorEden`和`ZPageAllocator`。**特定GC内容**如下：

- 小页为2M，可以存放的对象最大为`2M / 8 = 256K`，也就是对象范围在`(0, 256K]`。
- 中页`ZPageSizeMedium`为`MaxHeapSize * 0.03125`，并且在`2M - 32M`之间。可以存放的对象最大为`2M - 32M / 8 = 256K - 4M`，也就是对象范围在`(256K, 256K - 4M]`。如果`MaxHeapSize`为64M以下时，`ZPageSizeMedium = MaxHeapSize * 0.03125 = 256K`，中页就完全没用了。其他情况都有用。
- 大页没有固定大小，根据大对象（`256K - 4M`以上）来定。这里类似于G1的大对象（H）区域。对象范围在`4M`以上。

分配新的TLAB `ZCollectedHeap::allocate_new_tlab`:
调用`ZAllocatorEden::alloc_tlab -> ZObjectAllocator::alloc_object`负责具体的分配。
- 判断是否是小对象`(0, 256K]`，是则调用`ZObjectAllocator::alloc_small_object`进行分配
  - 获取当前CPU共享的小页的地址 `ZObjectAllocator::_shared_small_page::addr`
  - 调用`ZObjectAllocator::alloc_object_in_shared_page`进行分配
    - 在对应的页上分配对象，原子递增指针`ZPage::_top`即可（类似`G1`的在`堆区域HeapRegion`分配）`ZPage::alloc_object_atomic`
    - 如果上一步不成功，则**调用`ZObjectAllocator::alloc_page`分配新的页（类似`G1`获取新的`堆区域HeapRegion`，详见下文）**
    - 在新的页上分配对象，直接修改指针`ZPage::_top`即可（不需要原子修改，因为该页还没放到共享位置）。 `ZPage::alloc_object`
    - 把新的页放到对应共享页的地址中，原子操作并不断重试（因为可能有其他线程已经放了新的页）。放置共享页失败时:
      - 如果之前的共享页**为空**，则继续重新设置共享页
      - 如果之前的共享页**不为空**，这时候要在新的共享页上原子地分配对象，并把自己申请的页取消 `ZObjectAllocator::undo_alloc_page`
- 判断是否是中对象`(256K, 256K - 4M]`，是则调用`ZObjectAllocator::alloc_medium_object`进行分配
  - 获取共享中页（所有CPU共享）的地址`ZObjectAllocator::_shared_medium_page`
  - 和小对象一样，也是调用`ZObjectAllocator::alloc_object_in_shared_page`进行分配，只是传入的页地址、页类型不一样
- 判断是否是大对象`大于 256K - 4M`，是则调用`ZObjectAllocator::alloc_large_object`进行分配
  - 没有共享大页，因为大页都是使用的时候才分配
  - 和上文分配页一样，**调用`ZObjectAllocator::alloc_page`分配页，只是传入的页类型和大小不同。**
  - 在新建的页中分配对象（大对象总是分配新的页进行分配，类似G1的大对象总是分配新的连续`堆区域HeapRegion`）

在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab -> ZCollectedHeap::mem_allocate`:
调用`ZAllocatorEden::alloc_object -> ZObjectAllocator::alloc_object`进行分配，具体操作和上文分配`TLAB`一样，只是传入的大小不同。


分配新的页具体过程（类似`G1`获取新的`堆区域HeapRegion`）:
调用`ZObjectAllocator::alloc_page -> ZHeap::alloc_page -> ZPageAllocator::alloc_page`
- 调用`alloc_page_or_stall`完成分配或挂起
  - 先调用`alloc_page_common- > alloc_page_common_inner`完成分配
    - **从页缓存`ZPageAllocator::_cache`中获取页，获取成功则加入`ZPageAllocation::pages`中。`ZPageCache::alloc_page`（这一步可能会把较大的页切成较小的页，详见下文）**
    - 从页缓存获取不成功，则调用`ZPageAllocator::increase_capacity`递增堆空间，原子地修改`ZPageAllocator::_capacity`。
    - 如果递增的值还不满足要分配的大小，则调用`ZPageCache::flush_for_allocation -> ZPageCache::flush`，清除、刷新（`flush`）缓存页
      - 虽然说是清除缓存页，其实更像是合并缓存页。
      - 按`大页`、`中页`、`小页`的顺序进行`flush`
      - 已经清除的缓存页大小总和 >= 要分配的大小 就可以返回。也就是说`flush_for_allocation`不一定清除所有的缓存页。
      - `已经清除的缓存页大小总和`不一定刚好**等于**`要分配的大小`，如果是**大于**，剩下的部分则分离出来，作为一个新页放回到页缓存。`ZPage::split`、`ZPageCache::free_page`
    - 使用`ZPageAllocator:increase_used`递增已经使用的大小。原子递增`ZPageAllocator::_used`。
  - 如果前面分配不成功，则判断是否应该等待（`stall`），Java线程一般都要等，GC线程一般不等。
  - 如果需要等待，则把对应的`ZPageAllocation`放到`ZPageAllocator::_stalled`中
  - 然后调用`ZPageAllocator::alloc_page_stall -> ZDriverMinor::collect -> ZDriverPort::send_async`发送`Young GC`请求。然后暂停线程，等待`GC`完成`。
  - GC完成后，GC线程会调用`ZPageAllocator::free_pages -> satisfy_stalled`给每个阻塞的`Java线程`分配内存，并唤醒对应的`Java线程`，直到内存用完或者没有阻塞的线程。
    - GC线程和Java线程一样，都是调用`ZPageAllocator::alloc_page_common`完成分配操作
    - GC线程调用`ZPageAllocation::satisfy -> ZFuture::set`唤醒Java线程。
- 调用`ZPageAllocator::alloc_page_finalize`做分配最后的工作
  - 前面分配的时候，如果`ZPageAllocation::pages`只设置了一个页，则直接使用。`ZPageAllocator::is_alloc_satisfied`
  - 如果`ZPageAllocation::pages`设置了多个页或0个页
    - 调用`ZPageAllocator::alloc_page_create`把多个页汇总成一个页或者新建一个页
    - 提交`commit`新页的内存，`map`内存，然后返回
    - 如果`commit`失败，则清除`commit`不成功的内存，清理对应的页
- 如果前面还是失败，则调用`ZPageAllocator::free_pages_alloc_failed`
  - 获取、释放`ZPageAllocation::pages`的所有页
  - 像GC线程一样，调用`ZPageAllocator::satisfy_stalled`为每个阻塞的`Java线程`分配内存，并唤醒对应的`Java线程`，直到内存用完或者没有阻塞的线程。（因为上一步释放了内存，类似GC了。如果释放的内存容量大于其他线程请求的内存容量，则可以唤醒并运行其他线程）
  - 重新回到`alloc_page_or_stall`重新进行分配
- 成功则递增叶计数（分代）、重置页、提交事件等
- 把页加入页表`ZHeap::_page_table`中
- 递增已经使用的大小。原子递增`ZObjectAllocator::_used`。


从页缓存`ZPageAllocator::ZPageCache _cache`中获取/分配页的具体内容（`ZPageCache::alloc_page`）:
- 根据页的大小进行分配
  - 如果是小页，遍历`ZPageCache::_small`进行获取 `ZPageCache::alloc_small_page`
    - 先从当前NUMA节点获取
    - 再从远程NUMA节点获取（遍历其他NUMA节点）
  - 如果是中页，遍历`ZPageCache::_medium`进行获取
  - 如果是大页，遍历`ZPageCache::_large`进行获取
- 分配不成功，则调用`ZPageCache::alloc_oversized_page`从大页或中页获取较大的页
  - 先从大页缓存中获取。`ZPageCache::alloc_oversized_large_page`
  - 上一步失败，再从中页缓存中获取。`ZPageCache::alloc_oversized_medium_page`
- 如果从大页或中页获取较大的页成功，则调用`ZPage::split`把页分成2部分。
  - 需要的部分用来返回
  - 不需要的部分则调用`ZPageCache::free_page`放入缓存


### 垃圾收集
`Java线程`或者`ZDirector线程`使用方法`ZDriverMajor::collect`或`ZDriverMinor::collect`，
通过`ZDriverPort::send_sync/send_async`发送GC请求给`ZDriverMinor`或`ZDriverMajor`线程。

`Java线程`一个调用栈
```shellZDriverPort::send_async zDriverPort.cpp:129
ZDriverMinor::collect zDriver.cpp:147
ZPageAllocator::alloc_page_stall zPageAllocator.cpp:530
ZPageAllocator::alloc_page_or_stall zPageAllocator.cpp:572
ZPageAllocator::alloc_page zPageAllocator.cpp:710
ZHeap::alloc_page zHeap.cpp:227
ZObjectAllocator::alloc_page zObjectAllocator.cpp:60
ZObjectAllocator::alloc_object_in_shared_page zObjectAllocator.cpp:94
ZObjectAllocator::alloc_medium_object zObjectAllocator.cpp:144
ZObjectAllocator::alloc_object zObjectAllocator.cpp:157
ZObjectAllocator::alloc_object zObjectAllocator.cpp:166
ZAllocatorEden::alloc_object zAllocator.inline.hpp:50
ZCollectedHeap::mem_allocate zCollectedHeap.cpp:162
MemAllocator::mem_allocate_outside_tlab memAllocator.cpp:241
MemAllocator::mem_allocate_slow memAllocator.cpp:349
MemAllocator::mem_allocate memAllocator.cpp:361
MemAllocator::allocate memAllocator.cpp:368
ZCollectedHeap::array_allocate zCollectedHeap.cpp:157
InstanceKlass::allocate_objArray instanceKlass.cpp:1483
oopFactory::new_objArray oopFactory.cpp:122
Runtime1::new_object_array c1_Runtime1.cpp:404
```

`ZDirector`线程调用栈
```shell
ZDriverPort::send_async zDriverPort.cpp:129
ZDriverMinor::collect zDriver.cpp:147
start_minor_gc zDirector.cpp:805
start_gc zDirector.cpp:822
ZDirector::run_thread zDirector.cpp:908
ZThread::run_service zThread.cpp:29
ConcurrentGCThread::run concurrentGCThread.cpp:48
Thread::call_run thread.cpp:220
thread_native_entry os_linux.cpp:789
start_thread 0x00007f588bdfe6db
clone 0x00007f588b92361f
```

`ZDriverMinor`线程调用栈
```shell
ZGenerationYoung::collect zGeneration.cpp:522
ZDriverMinor::gc zDriver.cpp:191
ZDriverMinor::run_thread zDriver.cpp:213
ZThread::run_service zThread.cpp:29
ConcurrentGCThread::run concurrentGCThread.cpp:48
Thread::call_run thread.cpp:220
thread_native_entry os_linux.cpp:789
start_thread 0x00007f588bdfe6db
clone 0x00007f588b92361f
```

`ZDriverMajor`线程调用栈
```shell
ZGenerationOld::collect zGeneration.cpp:996
ZDriverMajor::collect_old zDriver.cpp:433
ZDriverMajor::gc zDriver.cpp:445
ZDriverMajor::run_thread zDriver.cpp:473
ZThread::run_service zThread.cpp:29
ConcurrentGCThread::run concurrentGCThread.cpp:48
Thread::call_run thread.cpp:220
thread_native_entry os_linux.cpp:789
start_thread 0x00007f588bdfe6db
clone 0x00007f588b92361f
```


#### 新生代垃圾收集（young gc）

**标记开始**（只是设置一些信息，**这一步没有标记根**） `ZGenerationYoung::pause_mark_start-> VM_ZMarkStartYoung::pause`
`ZDriverMinor`提交任务`VM_ZMarkStartYoung`给`VMThread`线程。`VMThread`线程调用`VM_ZMarkStartYoung::do_operation`进行操作:
- 递增垃圾收集计数`ZCollectedHeap::_total_collections` `ZCollectedHeap::increment_total_collections`
- 标记开始相关操作。 `ZGenerationYoung::mark_start`
  - 反转一些常量到标记阶段状态 `ZGenerationYoung::flip_mark_start -> ZGlobalsPointers::flip_young_mark_start`
    - 反转新生代标记位`ZPointerMarkedYoung`，为`ZPointerMarkedYoung0`或者`ZPointerMarkedYoung1`。**影响make barrier**
    - 反转新生代记忆集位`ZPointerRemembered`，为`ZPointerRemembered0`或者`ZPointerRemembered1`。**影响store barrier**
    - 设置`remap`位`ZPointerRemapped`为`ZPointerRemappedOldMask & ZPointerRemappedYoungMask`。
    - 设置`load barrier`的好地址掩码 `ZPointerLoadGoodMask`为`ZPointerRemapped`
    - 设置`mark barrier`的好地址掩码 `ZPointerMarkGoodMask`为`ZPointerLoadGoodMask | ZPointerMarkedYoung | ZPointerMarkedOld`。
    - 设置`store barrier`的好地址掩码 `ZPointerStoreGoodMask`为`ZPointerMarkGoodMask | ZPointerRemembered`。**隐式地设置了`ZStackWatermark::epoch_id`。**
    - 设置`load barrier`的坏地址掩码 `ZPointerLoadBadMask`为`ZPointerLoadGoodMask ^ ZPointerLoadMetadataMask`。
    - 设置`mark barrier`的坏地址掩码 `ZPointerMarkBadMask`为`ZPointerMarkGoodMask ^ ZPointerMarkMetadataMask`。
    - 设置`store barrier`的坏地址掩码 `ZPointerStoreBadMask`为`ZPointerStoreGoodMask ^ ZPointerStoreMetadataMask`。
    - 设置向量相关的掩码（和数组、向量操作有关，未看）
    - 设置`load barrier`应该平移的位数 `ZPointerLoadShift`。`ZPointerLoadShift`由`ZPointerLoadGoodMask`的值（`1`所在的位置）决定。
  - 调整一些barrier `ZGenerationYoung::flip_mark_start -> ZBarrierSetAssembler::patch_barriers` // TODO 不懂
  - 撤销新生代分配器`ZAllocatorEden`共享的页（这些页用于分配TLAB或者对象） `ZAllocator::retire_pages -> ZObjectAllocator::retire_pages`
  - 撤销14个重定向分配器`ZAllocatorForRelocation`共享的页（每个重定向分配器有自己的共享页） `ZAllocator::retire_pages -> ZObjectAllocator::retire_pages`
  - 重置一些计数信息 `ZGeneration::reset_statistics`
  - 递增垃圾收集计数（序列号） `ZGenerationYoung::_seqnum`
  - 设置阶段`ZGeneration::_phase`为`Phase::Mark`
  - 重置标记相关信息 `ZMark::start`。重置一些计数信息、设置工作线程数、设置Stripe数
  - 反转记忆集 `ZRemembered::flip`
    - 老年代页内部的记忆集`ZRememberedSet::_current` `ZRememberedSet::flip`
    - 全局的记忆集`ZRemembered::FoundOld::_current` `ZRemembered::flip_found_old_sets -> ZRemembered::FoundOld::flip`
  - 记录标记开始时的一些计数信息 `ZStatHeap::at_mark_start`

**并发标记** `ZGenerationYoung::concurrent_mark` 
**并发标记根（除了记忆集）`ZGenerationYoung::mark_roots -> ZMark::mark_young_roots`** `ZDriverMinor`提交任务`ZMarkYoungRootsTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZMarkYoungRootsTask::work`进行标记。
- 标记着色的根（强和弱的`OopStorage`、类加载器） `ZRootsIteratorAllColored::apply`（最终调用`ZMarkYoungOopClosure::do_oop -> ZBarrier::mark_young_good_barrier_on_oop_field -> ZBarrier::barrier`完成标记操作，**标记具体操作见下文`标记操作详细流程`，这里只列出整体流程。**）
  - 标记`OopStorage`指向的对象（遍历所有的OOP块）
    - 注意强和弱的`OopStorage`都要遍历，年轻代收集不处理弱引用，所以把弱`OopStorage`当作强`OopStorage`看待。
    - 每个Worker线程每次认领`未遍历的OOP块数量 / Worker线程数`个块（并且限制到1-10个块，就是每次最少1个块，最大不能超过10个块）
    - 调用链 `ZParallelApply::apply -> ZOopStorageSetIteratorStrong/ZOopStorageSetIteratorWeak::apply -> OopStorageSetStrongParState/OopStorageSetWeakParState::oops_do`
    - 其它相关的类`ZMarkYoungOopClosure`
  - 标记`类加载器数据`指向的对象（遍历`ClassLoaderData`里面的字段`ChunkedHandleList _handles`）
    - 每个Worker线程每次认领一个类加载器
    - 调用链 `ZParallelApply:apply -> ZCLDsIteratorAll::apply -> ClassLoaderDataGraph::cld_do`
    - 其它相关的类`ZMarkYoungOopClosure`、`ZMarkYoungCLDClosure`、`ClaimingCLDToOopClosure`、`CLDToOopClosure`
- 标记非着色的根（线程、`NMethod`）`ZRootsIteratorAllUncolored::apply` （最终调用`ZUncoloredRoot::process/ZUncoloredRoot::mark -> ZUncoloredRoot::barrier`完成标记操作，**和着色的根不同，非着色的根不需要判断是否为好地址和修正地址**）
  - 标记`Java线程栈`指向的对象
    - 每个Worker线程每次认领一个线程，调用`StackWatermarkSet::finish_processing`处理栈。
    - 调用链 `ZParallelApply::apply -> ZJavaThreadsIterator::apply -> ZMarkThreadClosure::do_thread`
    - 其它相关的类`ZUncoloredRoot`、`ZUncoloredRootClosure`、`ZStackWatermarkProcessOopClosure`、`StackWatermarkSet/ZStackWatermark::finish_processing`（详见文档`stack_watermark.md`）
  - 标记`nmethod`指向的对象
    - 每个Worker线程每次获取16个`ZNMethodTableEntry`
    - 调用链 `XParallelApply::apply -> ZNMethodsIteratorAll/ZNMethodsIteratorImpl::apply -> ZNMethod::nmethods_do -> ZNMethodTable::nmethods_do -> ZNMethodTableIteration::nmethods_do`
    - 其它相关的类`ZUncoloredRoot`、`ZUncoloredRootClosure`、`ZUncoloredRootMarkYoungOopClosure`、`ZMarkYoungNMethodClosure`、`XNMethod`
- **把线程本地的标记栈发布到全局栈列表中** `ZMarkYoungRootsTask::work -> ZHeap::mark_flush_and_free`
  - 发布年轻代标记栈 `ZGenerationYoung(ZGeneration)::mark_flush_and_free -> ZMark::flush_and_free`
  - 发布老年代标记栈 `ZGenerationOld(ZGeneration)::mark_flush_and_free -> ZMark::flush_and_free`
  - `ZMark::flush_and_free`除了发布标记栈。还会调用每个Java线程的`ZStoreBarrierBuffer::flush`处理线程的`Store barrier buffer`。它会标记Java线程`记录下来的旧对象`，如果记录的指针是老年代的，则要修改**对应页的记忆集**（全局记忆集记录了所有老年代页，所有不需要修改）。

**并发标记`记忆集`和堆 `ZGenerationYoung::mark_follow -> ZRemembered::scan_and_follow`** `ZDriverMinor`提交任务`ZRememberedScanMarkFollowTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZRememberedScanMarkFollowTask::work -> ZRememberedScanMarkFollowTask::work_inner`递归标记`记忆集`和堆。
- 标记上一步的根指向的对象 `ZRememberedScanMarkFollowTask::work_inner -> ZMark::follow_work_partial -> ZMark::follow_work **传入的partial为true**`
  - 获取每个Worker线程需要处理的`全局栈列表` `ZMarkStripeSet::stripe_for_worker`
  - 获取当前线程的本地标记栈 `XThreadLocalData::stacks`
  - 从`本地标记栈`中获取对象并标记（`本地标记栈`处理完成后，再从`获取的栈列表`获取栈到本地） `ZMark::drain`
    - 获取对象 `ZMarkThreadLocalStacks::pop`
    - **如果对象在入栈之前没标记（比如Java线程就不会标记，只入栈），这里就标记对象** `ZMark::mark_and_follow -> ZPage::mark_object 详情看下文`
    - 递增当前页的活跃对象（大小）数量，先缓存在`ZMarkCache`中，之后再写回到`ZPage::ZLiveMap::_live_objects/_live_bytes`。 `ZMarkCache::inc_live -> ZMarkCacheEntry::evict`
    - **处理刚刚标记的对象的字段（这里会不断往本地栈添加对象）** `ZMark::mark_and_follow -> follow_array_object/follow_object --> ZMarkBarrierFollowOopClosure::do_oop -> ZBarrier::mark_barrier_on_young_oop_field`
  - 从本地和全局其他栈列表中窃取标记栈，回到上一步进行处理 `ZMark::try_steal`
  - 注意这里没有调用`ZMark::try_proactive_flush`发布标记栈到全局，也不用循环回到第一步进行处理，也就是说这一步不需要完全标记整个堆，后面标记`记忆集`指向的对象后，还要再运行一次这个方法来完全标记整个堆。
- 标记记忆集指向的对象 `ZRememberedScanMarkFollowTask::work_inner`。遍历全局记忆集`ZRemembered`的`旧BitMap`（即遍历每个老年代页）`ZRemsetTableIterator`（`标记开始阶段`都会反转bitmap，所以这个`旧BitMap`就是当前最新的，除了并发处理时新增的内容。），每个页进行的操作如下:
  - 如果该页将要、正在、已经被`Full GC`迁移（有对应的`ZForwarding`信息） `ZRemembered::scan_forwarding`
    - 注意: **一般记忆集的信息在页的字段`ZPage::_remembered_set`中，而该页被老年代迁移后，旧的页的记忆集放到`ZForwarding::_relocated_remembered_fields_array`中。所以要根据老年代页的不同迁移状态遍历不同的内容。**
    - 当然，也可以等迁移完成后，遍历新页的记忆集，从而不使用字段``ZForwarding::_relocated_remembered_fields_array``，不过这样新生代要等待老年代。使用`ZForwarding::_relocated_remembered_fields_array`也就是拿空间换时间了。
    - **把该页的引用计数加1，引用计数增加成功说明该页没有被释放（该页将要被迁移、或者真正被迁移且`不在当前页in-place地迁移`）。`ZForwarding::retain_page`**
      - **把`ZForwarding::_relocated_remembered_fields_state`修改为`ZPublishState::reject`。** `relocated_remembered_fields_notify_concurrent_scan_of`
        - 也就是现在也还没释放，所以我们通知`Full GC`不要把记忆集的信息放到`ZForwarding::_relocated_remembered_fields_array`。
        - 如果`Full GC`已经把记忆集的信息放到`ZForwarding::_relocated_remembered_fields_array`（状态`_relocated_remembered_fields_state`为`ZPublishState::published`），只是还没释放页，则要调用`clear_and_deallocate`清除对应记忆集信息。
      - **获取该页所有记忆集的信息`ZPage::_remembered_set` `zRemembered::fill_containing`**
      - 把该页的引用计数减1。`ZForwarding::release_page`
      - **迁移该老年代页** `ZRemembered::oops_do_forwarded_via_containing`
        - 里面会**标记对象**和把对应指针放入新页的记忆集中。（`放入记忆集`操作可能重复了，为了复用代码`scan_field`）。`ZRemembered::scan_field`
    - **调用`ZForwarding::retain_page`递增引用计数失败，则说明该页 正在被迁移且`在当前页in-place地迁移` 或者已经被释放** `relocated_remembered_fields_notify_concurrent_scan_of`
      - 该页正在被迁移且`在当前页in-place地迁移`
        - 如果该页正在被迁移且`在当前页in-place地迁移`，则在`ZForwarding::retain_page -> ZRelocateQueue::add_and_wait`循环等待迁移完成。
        - `relocation线程`在使用`ZRelocateQueue::prune_and_claim`获取`ZForwarding`时，会判断队列中是否有已经完成的页（这些页是上一步`ZRelocateQueue::add_and_wait`添加的）。如果有完成的页，则唤醒等待的线程。
        - 注意前面`循环等待迁移完成`，即线程被唤醒之后，会再判断`自己要处理的页`是否迁移完成，未迁移完成则要再阻塞。
        - 迁移完成后，按照下面`已经被释放`的步骤进行操作
      - 该页已经被释放
        - **获取该页所有记忆集的信息 `ZForwarding::_relocated_remembered_fields_array`**
        - **标记对象**和把对应指针放入记忆集中（`放入记忆集`操作可能重复了，为了复用代码`scan_field`）。`ZRemembered::scan_field`
        - 把`ZForwarding::relocated_remembered_fields_apply_to_published`修改为`ZPublishState::accept`。
  - 如果该页没被`Full GC`处理（没有对应的`ZForwarding`信息、没有被上一步处理）
    - 在`ZForwarding::retain_page`中把页放到老年代的队列中 `ZGeneration::ZRelocateOld::ZRelocateQueue`中。
    - **标记该页记忆集的对象**和把对应指针放入新页的记忆集中（`放入记忆集`操作可能重复了，为了复用代码`scan_field`）。`ZRemembered::scan_page -> ZRemembered::scan_field`
- 标记堆中所有对象 `ZRememberedScanMarkFollowTask::work_inner -> ZMark::follow_work_complete -> ZMark::follow_work **传入的partial为false**`
  - 获取每个Worker线程需要处理的`全局栈列表` `ZMarkStripeSet::stripe_for_worker`
  - 获取当前线程的本地标记栈 `XThreadLocalData::stacks`
  - 从`本地标记栈`中获取对象并标记（`本地标记栈`处理完成后，再从`获取的栈列表`获取栈到本地） `ZMark::drain`
    - 获取对象 `ZMarkThreadLocalStacks::pop`
    - **如果对象在入栈之前没标记（比如Java线程就不会标记，只入栈），这里就标记对象** `ZMark::mark_and_follow -> ZPage::mark_object 详情看下文`
    - 递增当前页的活跃对象（大小）数量，先缓存在`ZMarkCache`中，之后再写回到`ZPage::ZLiveMap::_live_objects/_live_bytes`。 `ZMarkCache::inc_live -> ZMarkCacheEntry::evict`
    - **处理刚刚标记的对象的字段（这里会不断往本地栈添加对象）** `ZMark::mark_and_follow -> follow_array_object/follow_object --> ZMarkBarrierFollowOopClosure::do_oop -> ZBarrier::mark_barrier_on_young_oop_field`
  - 从本地和全局其他栈列表中窃取标记栈，回到上一步进行处理 `ZMark::try_steal`
  - 发布Java线程的标记栈到全局，然后回到前面第一步进行处理。使用了线程握手，详见`handshake.md`。 `ZMark::try_proactive_flush -> ZMark::try_flush`
  - 标记终止 `ZMark::try_terminate`
- **把线程本地的标记栈发布到全局栈列表中** `ZRememberedScanMarkFollowTask::work -> ZHeap::mark_flush_and_free`
  - 发布年轻代标记栈 `ZGenerationYoung(ZGeneration)::mark_flush_and_free -> ZMark::flush_and_free`
  - 发布老年代标记栈 `ZGenerationOld(ZGeneration)::mark_flush_and_free -> ZMark::flush_and_free`
  - `ZMark::flush_and_free`除了发布标记栈。还会调用每个Java线程的`ZStoreBarrierBuffer::flush`处理线程的`Store barrier buffer`。它会标记Java线程`记录下来的旧对象`，如果记录的指针是老年代的，则要修改**对应页的记忆集**（全局记忆集记录了所有老年代页，所有不需要修改）。


**并发标记堆（一般不需要运行，如果前面处理失败的话则运行）**
前面如果运行出错，则`ZDriverMinor`提交任务`ZMarkTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZMarkTask::work`递归标记整个堆。 `ZGenerationYoung::mark_follow -> ZRemembered::scan_and_follow -> ZMark::mark_follow`
- `ZMarkTask::work`和上文一样，也是调用`ZMark::follow_work_complete`完成工作。
- 注意这一步不需要遍历记忆集。


**`ZMarkYoungOopClosure::do_oop -> ZBarrier::mark_young_good_barrier_on_oop_field -> ZBarrier::barrier`标记操作详细流程（remap、标记、往本地栈添加对象、修正地址）:**
- 获取OOP
- 如果指针是好的（非空且已经`remap`和标记），则返回未着色的指针。`ZBarrier::is_mark_young_good_fast_path`
  - `remap位 & ZPointerLoadBadMask`为0
  - 指针不为空
  - `年轻代标记位 & ZPointerMarkedYoung`不为0
- 获取好地址 `ZBarrier::make_load_good -> ZBarrier::relocate_or_remap`
  - 当前是`mark`阶段，则`remap`对象，获取`remap`后的好地址即可（如果是`relocate`阶段，则先迁移`relocate`，再`remap`对象）
- **标记对象，详见下文** `ZBarrier::mark_young_slow_path -> ZBarrier::mark_if_young -> ZBarrier::mark_young -> ZGeneration::mark_object -> ZMark::mark_object`
- 修正地址 `ZBarrier::self_heal`

**`ZGeneration::mark_object -> ZMark::mark_object`详细步骤（标记、往本地栈添加对象）:**
- 调用`ZPage::mark_object`标记对象（GC线程会直接标记，Java线程只把地址放到栈中）
  - 获取地址所在的页 `ZPageTable::get`
  - 判断该页是否用于标记阶段分配对象，是则无需处理，因为新分配的对象都默认为已标记
  - 调用`ZPage::mark_object -> ZLiveMap::set`标记对象。
    - 如果本次GC第一次标记，重置`ZLiveMap`的相关数据。
    - 如果本次GC第一次标志该段，则要设置该段为活跃并重置该段bitmap的数据`ZLiveMap::reset_segment`。
    - 最后标记该对象`ZBitMap::par_set_bit_pair`。如果是强可达则置为`11`，`finalizable`可达置为`01`。
  - **把对象放到线程本地的栈中`ZMarkThreadLocalStacks::push`，线程本地的栈满了则把该栈放到全局的栈列表中`ZMarkStripe::publish_stack`**
- 返回好地址


**标记结束** `ZGenerationYoung::pause_mark_end -> VM_ZMarkEndYoung::pause` 
`ZDriverMinor`提交任务`VM_ZMarkEndYoung`给`VMThread`线程。`VMThread`线程调用`VM_ZMarkEndYoung::do_operation -> ZGenerationYoung::mark_end`进行操作:
- 终止标记 `ZMark::end -> ZMark::try_end`
  - **遍历所有非java线程，把线程本地的标记栈发布到全局栈列表中** `Threads::non_java_threads_do`
  - 更新一些数据
- 设置阶段`ZGeneration::_phase`为`Phase::MarkComplete`
- 更新一些数据

**继续并发标记** `ZGenerationYoung::concurrent_mark_continue -> ZGenerationYoung::mark_follow -> ZRemembered::scan_and_follow`
如果前面没有处理所有标记栈，则会在这里调用`ZRememberedScanMarkFollowTask::work`继续进行并发标记。其操作和上文`并发标记`一样。这一步完成后，再回到`标记结束`进行处理，直到标记完成。

标记结束后，**并发**进行下面操作 :
- 清理一些标记相关的数据和内存 `ZGenerationYoung::concurrent_mark_free -> ZGeneration::mark_free -> ZMark::free`
- 清理、重置forwarding表`ZGeneration::_forwarding_table`和relocation集合`ZGeneration::_relocation_set`。 `ZGenerationYoung::concurrent_reset_relocation_set -> ZGeneration::reset_relocation_set`
- 选择relocation集合 `ZGenerationYoung::concurrent_select_relocation_set -> ZGeneration::select_relocation_set`
  - 判断是否收集类型是否为`ZYoungType::major_full_preclean`，即是否晋升所有对象。（为了后面设置晋升年龄）
  - 遍历每个页，把页的信息加入到`ZRelocationSetSelector`中
    - 老年代的页会被`ZGenerationPagesIterator`略过 `ZGenerationPagesIterator::next`
    - 如果是`标记阶段新分配的页`（页的序列号等于年轻代的序列号） `ZPage::is_relocatable`
    - 如果页中有活跃对象`ZPage::is_marked`，并且**垃圾数超过限制页大小的1/4则注册该页** `ZRelocationSetSelector::register_live_page -> ZRelocationSetSelectorGroup::register_live_page`
    - 如果页中没有活跃对象则先注册空页 `ZRelocationSetSelector::register_empty_page`。如果空页数量查过64个，则批量清除空页 `ZGeneration::free_empty_pages`。
  - 清除所有空页 `ZGeneration::free_empty_pages`
  - 选择迁移集合 `ZRelocationSetSelector::select -> ZRelocationSetSelectorGroup::select`
    - 按活跃对象的数量把注册的页从小到大排序（按区间排序，不是严格的每个页从小到大）`ZRelocationSetSelectorGroup::semi_sort`
    - 选择迁移集合（确保堆中碎片不超过25%`ZFragmentationLimit`）
  - 设置晋升年龄，如果要晋升所有对象，则晋升年龄为0。 `ZGenerationYoung::select_tenuring_threshold`
  - 根据选择的迁移集合创建对应的`ZForwarding`信息，放到`ZRelocationSet::_forwardings`。 `ZRelocationSet::install`
    - 每个需要迁移的页对应一个`ZForwarding`，放在`ZRelocationSet::_forwardings`
    - 每个`ZForwarding`有一个`ZForwardingEntry数组`，每个`ZForwardingEntry`条目是一个对象的迁移信息
  - 提高`不需要迁移的页`的年龄 `ZGeneration::flip_age_pages`
    - 如果年龄大于晋升年龄，则要修复对应的空地址 `ZBarrier::promote_barrier_on_young_oop_field`
    - 新建新的页，设置为新的年龄
    - 如果晋升，则要调整一些整体的信息 `ZGenerationYoung::flip_promote`
    - 把晋升的页放到`ZRelocationSet::_flip_promoted_pages`中
  - 把上一步创建的`ZRelocationSet::_forwardings`信息加入`ZForwardingTable`哈系表。 `ZForwardingTable::insert`
    - 一个堆只有一个表，在`XHeap:_forwarding_table`，`key`为`地址`，`value`为`ZForwarding`
    - 也就是表中同一个页的对象地址指向同一个页的`ZForwarding`，再从`ZForwarding`中获取具体的地址
  - 更新一些数据


**迁移开始** `ZGenerationYoung::pause_relocate_start -> VM_ZRelocateStartYoung::pause`
`ZDriverMinor`提交任务`VM_ZRelocateStartYoung`给`VMThread`线程。`VMThread`线程调用`VM_ZRelocateStartYoung::do_operation -> ZGenerationYoung::relocate_start`进行操作:
- 反转一些常量到迁移阶段状态 `ZGenerationYoung::flip_relocate_start -> ZGlobalsPointers::flip_young_relocate_start`
  - 反转新生代remap掩码 `ZPointerRemappedYoungMask`
  - 设置`remap`位 `ZPointerRemapped`为`ZPointerRemappedOldMask & ZPointerRemappedYoungMask`。
  - 设置`load barrier`的好地址掩码 `ZPointerLoadGoodMask`为`ZPointerRemapped`
  - 设置`mark barrier`的好地址掩码 `ZPointerMarkGoodMask`为`ZPointerLoadGoodMask | ZPointerMarkedYoung | ZPointerMarkedOld`。
  - 设置`store barrier`的好地址掩码 `ZPointerStoreGoodMask`为`ZPointerMarkGoodMask | ZPointerRemembered`。**隐式地设置了`ZStackWatermark::epoch_id`。**
  - 设置`load barrier`的坏地址掩码 `ZPointerLoadBadMask`为`ZPointerLoadGoodMask ^ ZPointerLoadMetadataMask`。
  - 设置`mark barrier`的坏地址掩码 `ZPointerMarkBadMask`为`ZPointerMarkGoodMask ^ ZPointerMarkMetadataMask`。
  - 设置`store barrier`的坏地址掩码 `ZPointerStoreBadMask`为`ZPointerStoreGoodMask ^ ZPointerStoreMetadataMask`。
  - 设置向量相关的掩码（和数组、向量操作有关，未看）
  - 设置`load barrier`应该平移的位数 `ZPointerLoadShift`。`ZPointerLoadShift`由`ZPointerLoadGoodMask`的值（`1`所在的位置）决定。
- 调整一些barrier `ZGenerationYoung::flip_relocate_start -> ZBarrierSetAssembler::patch_barriers` // TODO 不懂
- 设置阶段`ZGeneration::_phase`为`Phase::Relocate`
- 记录迁移开始时的一些计数信息 `ZStatHeap::at_relocate_start`
- 设置年轻代GC的序列号 `ZGenerationOld::_young_seqnum_at_reloc_start`
- 设置`ZRelocateQueue::_nworkers`worker线程数量 `ZRelocate::start`
  - `ZRelocateQueue`是为了防止`Java线程`和`新生代GC线程`操作新生代、老年代GC线程`在当前页in-place迁移`的页。
    - `新生代GC线程`的迁移会和`Java线程`并发运行
    - `老年代GC线程`的迁移会和`Java线程`、`新生代GC线程的标记阶段`并发运行
  - 一样情况下，`Java线程`、`新生代GC线程`、`老年代GC线程`可以并发迁移一个页的对象。迁移前后使用`ZForwarding::retain_page`和`ZForwarding::release_page`做一些计数工作即可。
  - 但是在内存不足的情况下，`GC线程`则会把该页作为目标页进行`in-place`迁移，也就是该页的对象迁移到该页，等于进行了页内的压缩。
  - `Java线程`或`新生代的标记阶段`会使用`ZForwarding::retain_page`来获取页，如果这个页因为内存不足而`在当前页in-place地迁移`:
    - 则会调用`ZRelocateQueue::add_and_wait`把页放到`ZRelocateQueue`队列中，然后等待。（这里也算是内存不足导致stall了）
    - GC线程处理完这个页之后，在调用`ZRelocateQueue::synchronize_poll -> ZRelocateQueue::prune_and_claim`获取下一个页时，会先判断`ZRelocateQueue`中的页是否已经完成，完成则唤醒等待的线程。
  - `Java线程`或`新生代的标记阶段`在relocate的时候，如果分配失败，导致不能relocate
    - 也会调用`ZRelocateQueue::add_and_wait`把页放到`ZRelocateQueue`队列中，然后等待。（这里也算是内存不足导致stall了）
    - GC线程调用`ZRelocateQueue::synchronize_poll -> ZRelocateQueue::prune_and_claim`获取这些页进行迁移（有可能`在当前页in-place地迁移`），迁移完成后，也会同样唤醒线程。
  - 注意上面2点的区别（其实究其原因都是内存不足！）：
    - 第一点是`GC线程`因为内存不足**已经**`在当前页in-place地迁移`，`Java线程`或`新生代的标记阶段`探测到这个`in-place`信息，从而阻塞。
    - 第二点是`Java线程`或`新生代的标记阶段`自己探测到内存不足的信息，就阻塞，让GC线程完成操作（GC线程这时有可能`在当前页in-place地迁移`）。

**并发迁移** `ZDriverMinor::concurrent_relocate -> ZGenerationYoung::relocate -> ZRelocate::relocate`

**处理store barrier buffer指针**
`ZDriverMinor`提交任务`ZRelocateStoreBufferInstallBasePointersTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZRelocateStoreBufferInstallBasePointersTask::work ----> ZRelocateStoreBufferInstallBasePointersThreadClosure::do_thread -> ZStoreBarrierBuffer::install_base_pointers`进行处理。

把`store barrier buffer`的指针`ZStoreBarrierBuffer::ZStoreBarrierEntry::_p`所在对象（如果对象所在的页需要迁移）的地址放到`ZStoreBarrierBuffer::_base_pointers`中，因为relocate阶段会清除这些页，如果不把对象地址保留下来，就无法定位到迁移后的位置。（之后Java线程会调用`ZStoreBarrierBuffer::on_new_phase_relocate`把这些迁移前的地址，转换成迁移之后的地址，详见文档`stack_watermark.md`和代码`ZStackWatermark::start_processing_impl`）

**迁移工作**
`ZDriverMinor`提交任务`ZRelocateTask`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZRelocateTask::work`迁移对象。

`ZRelocateTask::work`先调用`ZRelocateQueue::synchronize_poll`来获取队列`ZRelocate::ZRelocateQueue _queue`（`ZRelocateQueue`具体内容详见上文）中的`ZForwarding`（如果队列中有已经完成的页，会唤醒在等待的线程）。如果上面队列中获取不到，则调用`ZRelocationSetParallelIterator::next`获取`迁移集`的下一个页，并调用`ZForwarding::claim`设置对应的`_claimed`位（**`ZRelocationSetParallelIterator`确保各个并发worker线程不会重复获取一个页，但是还是要调用`claim`。因为`ZRelocateQueue::synchronize_poll`也会获取页，不被`ZRelocationSetParallelIterator`所控制**）。

总的来说，`ZRelocateTask`会遍历`ZRelocationSet::_forwardings`的每一项（一项对应一页），迁移页中所有存活对象`ZRelocateWork::do_forwarding -> ZForwarding::object_iterate ---> ZRelocateWork::relocate_object`。下面是`ZRelocateWork::relocate_object`的具体操作:
- 调用`ZRelocateWork::try_relocate_object -> ZRelocateWork::try_relocate_object_inner`迁移对象
  - 获取对象大小 `XUtils::object_size`
  - 根据年龄选择转移的目标页 `ZRelocateWork::target`
  - 在`ZForwarding`信息中查看当前对象是否已经被迁移,是则直接返回 `zRelocate.cpp::forwarding_find`
  - 在刚刚选择的目标页上分配对象，详见上文`堆内存分配` `ZRelocateSmallAllocator/ZRelocateMediumAllocator::alloc_object -> ZPage::alloc_object`
  - 把对象从旧地址复制到新地址 `ZUtils::object_copy_disjoint`
  - 把新地址信息放到`ZForwarding`中 `zRelocate.cpp::forwarding_insert`
    - 如果地址信息存放失败，说明另一个线程已经迁移并处理了该对象，这时候要回收刚刚分配的内存 `ZRelocateSmallAllocator/ZRelocateMediumAllocator::undo_alloc_object`
    - 中页是共享的，如果其他线程已经在这个页上分配对象，`_top`指针已经改变，这时候已经不能回收刚刚分配的内存，所以只能直接返回，这时候页中多了一个垃圾对象
    - 新地址信息存放失败，使用别的线程存放的新地址
    - **注意: 这里新地址信息存放失败，使用别的线程存放的新地址这种情况也算迁移成功**
- 更新记忆集 `ZRelocateWork::try_relocate_object -> ZRelocateWork::update_remset_for_fields`
  - 如果不是老年代的页，则直接返回
  - 如果本来就是老年代的页，则要更新记忆集到新的页 `ZRelocateWork::update_remset_old_to_old` // TODO `in-place`页使用旧的记忆集，好像有问题，如果当前的记忆集并发添加了新的内容的话，旧的记忆集的内容就不完整了。
  - 如果本来年轻代页，现在晋升到老年代，则要构造记忆集到新的页 `ZRelocateWork::update_remset_promoted`
  - 更新和构造最终都是使用`ZPage::remember`完成操作
- 如果迁移不成功，说明页中空间不够，分配新的页之后再回到上一步分配对象
  - 分配一个新的页 `ZRelocateSmallAllocator/ZRelocateMediumAllocator::alloc_and_retire_target_page`
    - 如果是小页，则直接调用 `zRelocate.cpp::alloc_page -> ZAllocatorForRelocation::alloc_page_for_relocation`分配
    - 如果是中页，则要看共享的页`ZRelocateMediumAllocator::_shared`是否可用，可用则返回共享页，不可用则像小页一样分配页
    - 如果分配页不成功，说明堆中空间不足，则使用当前的页`in-place`放置对象
  - 如果新页分配成功，则重新回到上一步迁移对象
  - 如果新页分配不成功，说明要使用当前页来放迁移的对象（相当于页内压缩空间了） `ZRelocateWork::start_in_place_relocation`
    - 认领当前页，不让其他线程访问 `ZForwarding::in_place_relocation_claim_page`
    - 设置`ZForwarding::_in_place`为真，设置`_in_place_top_at_start`。 `ZForwarding::in_place_relocation_start`
    - 设置其他信息，用到再看


**给晋升页添加记忆集** // TODO 这一步内容好像和上一步的`更新记忆集`重复了，不知道加这一步的原因
`ZDriverMinor`提交任务`ZRelocateAddRemsetForFlipPromoted`给`WorkerThread`线程。每个`WorkerThread`线程都调用`ZRelocateAddRemsetForFlipPromoted::work`进行处理。

遍历每个这次晋升到老年代的页，遍历页的每个指针，如果指针指向年轻代，则在记忆集中记录该位置。 `zRelocate.cpp::remap_and_maybe_add_remset -> ZRelocate::add_remset -> ZGenerationYoung::remember -> ZRemembered::remember -> ZPage::remember`


#### 老年代垃圾收集（full gc）

老年代收集之前，要收集1-2次新生代收集  `ZDriverMajor::gc -> ZDriverMajor::collect_young`
- 如果需要预清理年轻代，则要进行2次新生代收集
  - 第一次收集类型为`ZYoungType::major_full_preclean`，**为了晋升所有对象到老年代**。
    - 一次正常的年轻代收集，不会标记老年代对象。
    - 会把晋升年龄设置为0，也就是**把所有对象晋升到老年代**。
    - 详见方法`ZGenerationYoung::concurrent_select_relocation_set`。
  - 第二次收集类型为`ZYoungType::major_full_roots`，**为了标记年轻代指向老年代的对象**。
    - 和其他类型的年轻代收集的主要区别在`标记开始`阶段。
- 如果不需要预清理年轻代，则只要进行1次新生代收集
  - 收集类型为`ZYoungType::major_partial_roots`。和`ZYoungType::major_full_roots`一样，**为了标记年轻代指向老年代的对象**。

**年轻代收集类型`ZYoungType::major_full_roots`和`ZYoungType::major_partial_roots`会有下面特殊操作：**
- `标记开始`阶段的任务不再是`VM_ZMarkStartYoung`，而是`VM_ZMarkStartYoungAndOld`。
  - `VM_ZMarkStartYoungAndOld`比`VM_ZMarkStartYoung`多了一步: 调用`ZGenerationOld::mark_start`来**启动老年代的标记**。
- **启动老年代的标记，也就意味着`栈水位操作`会标记老年代的对象，把对象放在线程的老年代标记栈。**
  - 详见`ZStackWatermarkProcessOopClosure`、`ZUncoloredRoot::process/ZUncoloredRoot::mark`、文档。
  - 具体代码路径为: `ZUncoloredRoot::process/ZUncoloredRoot::mark -> ZUncoloredRoot::barrier -> ZUncoloredRoot::mark_object -> ZBarrier::mark -> ZGeneration::mark_object_if_active`
  - 注意: 虽然`ZBarrier::mark`的代码会根据老年代、新生代来标记对象，但是可能不是真的标记。因为它调用的`ZGeneration::mark_object_if_active`会判断当前代是否处于标记阶段，当前代处于标记阶段才会标记。也就是如果前面`不启动老年代的标记`，老年代对象就永远不会被`ZGeneration::mark_object_if_active`标记。
- **递归遍历堆时，遇到老年代对象，会把对象放在线程的老年代标记栈。**
  - 这样就得到了所有`年轻代指向老年代`的对象。
  - 具体代码在`ZMarkBarrierFollowOopClosure::do_oop`、`ZBarrier::mark_barrier_on_young_oop_field -> ZBarrier::barrier -> ZBarrier::mark_from_young_slow_path`。
- 注意: 前面的步骤只是`标记老年代对象`和`把对象放入线程的老年代栈中`
  - **不会获取、遍历线程的老年代栈进行递归标记**
  - **线程的老年代栈中内容留给接下来的`老年代收集`来处理**
- 注意: 标记根的时候，不会标记`老年代对象`。
  - 也就是只需要获取所有`年轻代指向老年代`的对象，不能获取根指向老年代的对象
  - 前面的栈水位操作确实会标记Java线程的指向老年代的对象，只是根的少部分内容。
  - 所以老年代并发标记还是要重新`遍历、标记`一次根
- 注意: 经过这一轮`年轻代收集`之后，`老年代收集`并发标记的时候，遇到的所有指向年轻代的指针都是好指针，从而不标记年轻代对象（直到下一次年轻代收集开启）。

具体老年代的收集在`ZDriverMajor::collect_old -> ZGenerationOld::collect`。大体流程和新生代差不多。主要有以下区别:
- 老年代`标记开始`阶段和年轻代`标记开始`阶段同时开始（这一点刚刚已经详细描述），使得**栈水位操作标记老年代的对象**。
- `并发标记根`阶段会标记根指向的所有对象,包括年轻代的对象
  - 因为上一轮`年轻代收集`后，所有年轻代指针都是好指针，从而不标记年轻代对象（直到下一次年轻代收集开启） // TODO
  - 年轻代收集使用`ZMarkYoungRootsTask`、`ZMarkYoungOopClosure`、`ZBarrier::mark_young_good_barrier_on_oop_field`
  - 老年代收集使用`ZMarkOldRootsTask`、`ZMarkOopClosure`、`ZBarrier::mark_barrier_on_oop_field`
- 老年代只标记强的根（`ZRootsIteratorStrongColored`、`ZRootsIteratorStrongUncolored`），而年轻代会标记所有根（包括强和弱）（`ZRootsIteratorAllColored`、`ZRootsIteratorAllUncolored`）
- `并发标记`阶段不用扫描记忆集
  - 年轻代收集使用记忆集相关代码进行标记 `ZRemembered::scan_and_follow`、`ZRememberedScanMarkFollowTask`、`ZMark::follow_work`
  - 老年代收集使用`ZMarkTask`、`ZMark::follow_work`
- 标记结束后、迁移开始前的`并发操作`里面多加了两步操作
  - `非强引用（弱引用）处理`，详见文档`reference.md`和代码`ZGenerationOld::concurrent_process_non_strong_references`、`ZReferenceProcessor`、`ZWeakRootsProcessor`。
  - 并发`relocate/remap`年轻代的根 `concurrent_remap_young_roots` // TODO 不懂
- 选择relocation集合的时候，新生代的页会被`ZGenerationPagesIterator`略过。 `ZGenerationPagesIterator::next`

