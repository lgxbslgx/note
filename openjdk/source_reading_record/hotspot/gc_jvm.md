## Generations
- young(new) generation
- old(tenured) generation
- permanent generation(metaspace after JDK8)

## Collection types
- Minor collection(young generation collection)
- Full collection(major collection): collect young, old and permanent generations. But CMS don't collect young generation. And the permanent generation is not exist after JDK8.

## HotSpot中的GC（这节是概要知识，具体的内容在后面）
- Epsilon: no-op garbage collector

- serial collector: young and old collections are done serially, in a stop-the-world fashion.
	- Young generation: copying
	- Old generation: mark-sweep-compact. sliding. Actually it is a mark-compact algorithm.
	- Usage: default collector in client-class vm. Or use -XX:+UseSerialGC.

- Parallel(throughput) collector: stop-the-world.
	- Young generation: parallel copying.
	- Old generation: serial mark-sweep-compact before jdk8, parallel mark-compact after jdk8.
	- Usage: default collectors in server-class vm in JDK8. Or use -XX:+UseParallelGC. Before JDK8, use -XX:+UseParallelOldGC to enable parallel mark-compat in old generation. But after JDK8, the parallel old collection is enabled when use -XX:UseParallelGC.

- Concurrent Mark-Sweep (CMS) collector
	- Young generation: parallel copying. ParNew.
	- Old generation: concurrent mark sweep. Init marking(STW), concurrent marking, remark(STW), concurrent sweep. It doesn't compact.
	- Usage: -XX:+UseConcMarKSweepGC

- G1
	- Data structure: 
		- heap regions
		- remember set(A logical Rset pre region. A set or hashtable of cards.): Store the location which point to this region. 
		- card table(heap 512byte:1byte card): 
		- marking buffer(one buffer per thread)
		- global marking buffer
		- remember set log buffer(a buffer per thread)
		- global rem set buffer
		- hot queue
		- collection set
		- previous and next marking bitmap(64bit:1bit)
		- mark stack
		- previous and next top at mark start(TAMS)
	- Init when creating vm
		- init arguments
			- heap region size: limit size 1M-32M, suggested count 2048(GrainBytes, GrainWords, LogOfHRGrainBytes, LogOfHRGrainWords, CardsPerRegion, LogCardsPerRegion, G1HeapRegionSize)
			- rem set size(fine-grain, sparse)
			- alignment(SpaceAlignment, HeapAlignment)
			- heap size and alignment(max 3g, min 8m, init 186m)
		- initialize heap and additional data
			- create g1CollectedHeap
			- get heap start address and end address(ReservedSpace, memRegion)
			- create card table
			- create barrier set
			- create hot card cache
			- create previous and next bitmap
			- create remember set
			- create block offset table
		- init gc related threads
			- create gc work gang and worker and create gc thread(GangWorker, GC Thread#0)
			- create concurrent mark thread(G1ConcurrentMarkThread extends ConcurrentGCThread, G1 main marker)
			- create concurrent work and create thread(GangWorker, G1 conc#0)
			- create concurrent refinement(G1ConcurrentRefine extends ConcurrentGCThread, G1 refine#0)
			- initialize service hread(G1ServiceThread, G1 service)
		- init other
			- G1DirtyCardQueueSet
			- dummy HeapRegion
			- G1MonitoringSupport
			- G1StringDedup
			- _collection_set
	- Initial Marking(STW)
		- Clear the next marking bitmap.
		- STW and then mark all objects from the roots.
	- Concurrent Marking
	- Final Marking(remark)(STW)
		- Drain the mark stack
		- Complete log buffer
	- Cleanup
	- Evacuation

- shenandoah
// TODO

- ZGC
// TODO

## GC初始化基本流程
初始化调用栈，注意栈的上面几个方法的前后还有一些操作，具体操作看下文。注意，文中**特定GC内容**在对应的GC描述中。
```
Universe::initialize_heap universe.cpp:843
universe_init universe.cpp:785
init_globals init.cpp:124
Threads::create_vm threads.cpp:548
JNI_CreateJavaVM_inner jni.cpp:3571
JNI_CreateJavaVM jni.cpp:3657
InitializeJVM java.c:1459
JavaMain java.c:413
ThreadJavaMain java_md.c:650
start_thread 0x0000003ff7ef051c
__thread_start 0x0000003ff7f3de3e
```

- 判断使用哪个GC，并获取对应的`GCArguments子类` `Arguments::apply_ergo -> Arguments::set_ergonomics_flags -> GCConfig::initialize`
- 设置最大堆对齐信息 `Arguments::apply_ergo -> Arguments::set_ergonomics_flags -> Arguments::set_conservative_max_heap_alignment -> GCArguments::conservative_max_heap_alignment` **特定GC内容**
- 人体工学（`ergonomically`）地设置堆大小信息 `Arguments::apply_ergo -> Arguments::set_heap_size`
- GC参数初始化  `Arguments::apply_ergo -> GCArguments::initialize` **特定GC内容**

- GC初始化基本流程 `universe_init里面使用的GCLogPrecious::initialize、GCConfig::arguments()->initialize_heap_sizes、Universe::initialize_heap`
  - 初始化`GC Log`日记处理相关类 `GCLogPrecious::initialize`
    - 和统一日记不同，这里主要为了虚拟机crash的时候，输出内容到`hs_err`文件
    - 类`GCLogPreciousHandle`和`GCLogPrecious`
  - 调整堆大小参数，为了`类数据共享CDS功能`dump数据
  - 根据传入参数初始化堆配置（大小等）`universe_init -> GCArguments::initialize_heap_sizes`
    - 初始化对齐信息，**特定GC内容** `GCArguments::initialize_alignments（纯虚函数）`
    - 初始化堆大小和其他参数 **特定GC内容** `GCArguments::initialize_heap_flags_and_sizes`
    - 再次启发式地设置堆参数，**特定GC内容** `GCArguments::initialize_size_info`
  - 初始化堆(这里面的内容大部分由具体的GC决定) `universe_init -> Universe::initialize_heap`
    - 创建堆对象，`new`一个`CollectedHeap`的子类（**特定GC内容**）的对象 `GCArguments::create_heap`
    - 初始化堆，至少有`下面的内容`加上**特定GC内容** `CollectedHeap::initialize`
      - 跟操作系统申请保留一个连续的区域
      - 新建`BarrierSet`，设置到静态变量`BarrierSet::_barrier_set`中，**BarrierSet和GC相关**。
        - `BarrierSetAssembler`等汇编器，和`体系结构、指令集`相关，结合`BarrierSet和GC相关`，则要放在`/hotspot/cpu/CPU_NAME/gc/GC_NAME_OR_shared/`里面
        - `BarrierSetC1`，C1特定的一些方法，和GC相关，要放在`/hotspot/share/gc/GC_NAME_OR_shared/c1`
        - `BarrierSetC2`，C2特定的一些方法，和GC相关，要放在`/hotspot/share/gc/GC_NAME_OR_shared/c2`
        - 一些共享的内容则是放在`shared`目录，`GC_NAME_OR_shared`里面的`OR_shared`就表示`shared`目录
  - 初始化线程本地分配缓存 `Universe::initialize_tlab`
  - 初始化`barrier集`的`汇编器`，操作可能为空。**特定GC内容** `init_globals -> gc_barrier_stubs_init`

## 堆内存分配基本流程
`堆内存分配`的可能路径:

- 解释器调用字节码`new`、`newarray`、`anewarray`、`multianewarray`，代码在`TemplateTable`。其中一个调用栈:
```
CollectedHeap::obj_allocate collectedHeap.inline.hpp:35
InstanceKlass::allocate_instance instanceKlass.cpp:1434
InterpreterRuntime::_new interpreterRuntime.cpp:243
<unknown> 0x00007f9c73d9507c  // <- 这里是`TemplateTable::_new`
// 省略
```

- C2的runtime库`OptoRuntime::new_instance_C`。其中一个调用栈:
```
CollectedHeap::obj_allocate collectedHeap.inline.hpp:36
InstanceKlass::allocate_instance instanceKlass.cpp:1434
OptoRuntime::new_instance_C runtime.cpp:235
// 省略
```

- 直接调用堆的分配方法（在虚拟机初始化的时候，解释器还没有初始化完成，就会直接调用） `Universe::heap()->obj_allocate等方法`。其中一个调用栈:
```
CollectedHeap::obj_allocate collectedHeap.inline.hpp:35
InstanceKlass::allocate_instance instanceKlass.cpp:1434
java_lang_String::basic_create javaClasses.cpp:271
java_lang_String::create_from_unicode javaClasses.cpp:289
StringTable::do_intern stringTable.cpp:370
StringTable::intern stringTable.cpp:359
StringTable::intern stringTable.cpp:341
Universe::genesis universe.cpp:360
universe2_init universe.cpp:973
init_globals init.cpp:146
// 省略
```

- 直接调用`MemAllocator`及其子类的内存分配方法`MemAllocator::allocate`
- // TODO 其他`堆内存分配`的可能路径


在模板解释器`TemplateTable`相关代码中，会先在TLAB中分配，如果分配不成功，则调用runtime库函数`InterpreterRuntime::_new`进行“慢速分配”，这里“慢速”是`TemplateTable`里面的叫法。之后就会和上面的调用栈一样: `InterpreterRuntime::_new -> InstanceKlass::allocate_instance -> CollectedHeap::obj_allocate`。

下面着重写`CollectedHeap::obj_allocate -> MemAllocator::allocate -> MemAllocator::mem_allocate`的内容。下文中**特定GC内容**在对应的GC描述中。
  - 先从线程的TLAB上分配，TLAB上的可用空间大于需要空间就可以分配成功 `MemAllocator::mem_allocate_inside_tlab_fast`
  - 分配不成功则开始慢速分配 `MemAllocator::mem_allocate_slow`
    - 尝试新建新的TLAB并分配 `MemAllocator::mem_allocate_inside_tlab_slow`
	  - 如果设置了`should_post_sampled_object_alloc`，则从TLAB上再尝试分配一次
	  - 如果TLAB上剩余空间过多（大于`tlab.refill_waste_limit`），则保留该TLAB，直接返回，在下一个阶段`MemAllocator::mem_allocate_outside_tlab`分配（即保留当前buffer，在其他地方分配，因为当前buffer还是空间多，不能浪费）
	  - 计算新分配的TLAB的大小 `tlab.compute_size` `ThreadLocalAllocBuffer::compute_min_size`
	  - 记录浪费的空间，清除TLAB的一些记录数据，当前TLAB剩下的部分用一个`Object`对象或者`Array`对象填充
	  - 新建（叫`分配`也行）新的TLAB `CollectedHeap::allocate_new_tlab` 
	    - 尝试分配 **特定GC内容**
		- 使用`0`值或者一个特殊的值填充TLAB，初始化TLAB相关记录信息
		- 分配成功后返回的`TLAB指针`就是`新分配对象的指针`
	- 前面的分配都不成功后，在TLAB外分配 `MemAllocator::mem_allocate_outside_tlab` **特定GC内容**


## 垃圾收集基本情况
### GC原因（很多）
代码在`GCCause::Cause`，下面列出一些，还有很多，未一一列出。
- 堆分配失败 `GCCause::_allocation_failure`
- 元空间分配失败 `GCCause::_metadata_GC_threshold`
- 调用Java方法`System.gc` 调用链为`System.gc -> Runtime.c::Java_java_lang_Runtime_gc -> jvm.cpp::JVM_GC -> CollectedHeap::collect` `GCCause::_java_lang_system_gc`

### 垃圾收集的接口（`collectedHeap`的方法）
`collectedHeap`只有垃圾收集接口，没有分代垃圾收集接口。分代相关操作在子类中。
- `collect` 一般是被`java方法System.gc`调用，`collect`一般直接或间接调用`do_full_collection`
- `do_full_collection` 一般是`full GC`
- `collect_as_vm_thread` vm线程调用

### 垃圾收集基本流程 // TODO 等全部GC看完之后再回来总结一遍
- 无垃圾收集: Epsilon
- 基本都是同步操作的GC（Serial、Parallel）// TODO 要改
  - 提交`VM_GC_Sync_Operation/VM_GC_Operation及其子类`给`VMThread`线程，然后等待`VMThread`线程完成操作。
  - 或者直接调用`垃圾收集`的接口: `collect`、`do_full_collection`、`collect_as_vm_thread`。注意上一点的`VM_GC_Sync_Operation/VM_GC_Operation`操作里面也是调用这3个接口，只不过这里是用户线程调用，上面是`VMThread`线程调用。
  - 注意，之前`CMS`存在的时候，`VMThread`是可以做异步操作的，现在`CMS`删除了，`VMThread`就只做同步操作了。
- 基本都是异步操作（并发）的GC
  - // TODO 要改

## HotSpot GC 基础部分总结
`CollectedHeap`提供堆的统一接口:
- 堆初始化的接口: `initialize`
- 分配堆内存的接口: `allocate_new_tlab`、`mem_allocate` **GC特定内容**
- 一些堆内存分配的便捷接口: `obj_allocate`、`array_allocate`、`class_allocate`。这里会用到下面的`MemAllocator::allocate`，`MemAllocator::allocate`之后又会调用`allocate_new_tlab`、`mem_allocate`完成分配。
- 垃圾收集的接口: `collect`、`do_full_collection`、`collect_as_vm_thread`

`MemAllocator`及其子类提供内存分配的接口（可以说是模板方法）: 
- 分配内存的接口: `allocate`、`mem_allocate`。`allocate`会调用`mem_allocate`。
- 分配内存的一些工具方法: `mem_allocate_inside_tlab_fast`、`mem_allocate_inside_tlab`、`mem_allocate_inside_tlab_slow`、`mem_allocate_slow`、`mem_allocate_outside_tlab`

`MemAllocator`模板主要有3个步骤:
1.在TLAB内分配 `mem_allocate_inside_tlab_fast`
2.新建TLAB，再在TLAB内分配 `mem_allocate_inside_tlab_slow`
3.在TLAB外分配 `mem_allocate_outside_tlab`
`mem_allocate_inside_tlab`包括了上面`1、2`
`mem_allocate_slow`包括了上面`2、3`
`allocate`、`mem_allocate`包括了上面`1、2、3`
