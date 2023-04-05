## linux
映射物理内存到虚拟内存
接口: 系统调用`brk`、`mmap`（根据是否文件映射、是否共享，至少分成4种类型）等
// TODO

## glibc库
使用`brk`和`mmap`对虚拟内存进行管理，提供易于使用的方法
接口: 
分配释放方法: malloc、realloc、calloc、free等
内存映射相关方法（在mman.h头文件中）: mmap、munmap等
// TODO

接下来是OpenJDK的抽象

## hotspot中与平台无关的操作内存的方法
`os`模块、`os_<os_name>`模块 例如`os::Linux`、`os::Posix`
抽象出一些与平台无关的方法供上层调用，虽然有很多方法，但是大部分底层都是
使用mmap，只是传入的参数不同。
接口:
  保留内存相关方法: 
    `*reserve_memory*`（使用`mmap`，传入的`__prot`为`PROT_NONE`）
    `*release_memory*`（使用`munmap`）
    `*map_memory*`（使用`mmap`，主要用于文件映射）
    `*unmap_memory*`（使用`munmap`，主要用于文件映射）
  提交内存相关方法:
    `commit_memory*`（使用`mmap`，传入的`__prot`为`PROT_READ|PROT_WRITE|PROT_EXEC`，建立页表？）
    `uncommit*`（使用`mmap`，不是`munmap`，传入的`__prot`为`PROT_NONE`，撤销页表？）

上面都是使用底层的接口，所以其中的数据结构不清晰，接下来的层次数据结构就会详细一点。

## hotspot中虚拟内存空间抽象
类`ReservedSpace`表示一段保留内存
  子类`ReservedHeapSpace`表示一段Java堆内存
  子类`ReservedCodeSpace`表示一段代码内存
类`VirtualSpace`表示一段committed的内存，也就是可以使用的（或者已经使用的）内存

## hotspot中内存的具体分类:
不严格的分类：
OpenJDK的内存主要分成 C堆对象、栈对象、静态对象metaspace元空间、Arena区域、、Java堆
  C堆对象，由malloc/free进行管理，其类都要继承`CHeapObj`
  栈对象，其类都要继承`StackObj`
  静态对象，里面全是静态字段和方法，作为命名空间使用，其类都要继承`AllStatic`
  Arena区域：资源对象区域（resource area）、HandleArea等
  metaspace元空间的对象，其类都要继承`MetaspaceObj`
  Java堆的对象，其类都要继承`oopDesc`（常说的`OOP`是`oopDesc *`）
  CodeCache，详见`interpreter.md`

### C堆对象
  其类都要继承`CHeapObj`或者`CHeapObjBase`
  支持`new`、`delete`操作，里面由malloc/free进行操作

### 栈对象
  其类都要继承`StackObj`
  不支持`new`、`delete`操作

### 静态对象
  其类都要继承`AllStatic`
  里面全是静态字段和方法，作为命名空间使用
  不支持`new`、`delete`操作

### Arena区域（其实里面也是由malloc/free进行操作，有`ChunkPool`避免了频繁分配回收）
  `Arena`自己要继承`CHeapObjBase`
  由一系列不连续的块（`Chunk`）组成(即`Chuck`组成的链表)，对象分配在块中
  字段`Chunk *_first`开始块
  字段`Chunk *_chunk`当前块，也是最后的块
  字段`char *_hwm, *_max`当前块的可分配地址（下一个对象从这里开始分配）和终止地址
  分配在Arena区域的对象，都要继承`ArenaObj`
  Arena和metaspace有很多类似的地方，`Arena`类似`RootChunkArea`，`Chunk`类似`MetaChunk`，`ChunkPool`类似`ChunkHeaderPool`，但是元空间那边有自己特殊的地方

  资源区域（`ResourceArea`），特殊的Arena
    用于线程的resource area（字段`Thread::ResourceArea* _resource_area`），可以用`ResourceMark`标志，`ResourceMark`析构的时候，对应的资源对象也会被清除
    分配在ResourceArea区域的对象，都要都要继承`ResourceObj`
    支持`new`，不支持`delete`操作

  `HandleArea`，特殊的Arena
    类似`ResourceArea`
    用于线程的handle area（字段`HandleArea* _handle_area`），可以用`HandleMark`标志，`HandleMark`析构的时候，对应的handle也会被清除
    分配在`HandleArea`区域的对象，都要继承`Handle`。注意，`Handle`表示栈上的handle信息，`OopHandle`表示非栈上的handle信息。

### metaspace元空间
metaspace元空间的对象，其类都要继承`MetaspaceObj`。支持`new`，不支持`delete`操作。

元数据类型（MetadataType）有类和非类（即枚举量`ClassType`和`NonClassType`），
其中枚举量`ClassType`对应常说的`Klass`及其子类。

`Metaspace`类，元空间的一个“逻辑”上的类
  方法`global_initialize`: 初始化整个元空间，设置各个参数、常量初始值，初始化`MetaspaceContext`的`_class_space_context`和`_nonclass_space_context`
  方法`allocate`: 分配元空间内存给传入的类加载器`ClassLoaderData`

`MetaspaceContext`类，“元空间上下文”，里面的静态字段`_class_space_context`和`_nonclass_space_context`合起来就是整个元空间:
  静态字段`MetaspaceContext* _class_space_context`表示类空间（存Klass），一定是连续地址空间，所以其`_vslist`里只有一个节点
  静态字段`MetaspaceContext* _nonclass_space_context`表示非类空间
  字段`VirtualSpaceList* _vslist`表示该空间的所有虚拟内存，链表的形式连起来，链表每个节点类型是`VirtualSpaceNode`
  字段`ChunkManager* _cm`表示该空间的块管理器，一个伙伴（buddy）块内存管理器

`VirtualSpaceList`: 表示一个context空间的链表，节点类型为`VirtualSpaceNode`
  字段`VirtualSpaceNode* _first_node`表示链表的头节点
  方法`create_new_node`给链表分配新的节点
  方法`allocate_root_chunk`分配一个新的根块（最大块），确保第一个节点剩余空间足够，使用`VirtualSpaceNode::allocate_root_chunk`完成分配

`VirtualSpaceNode`:一段连续的虚拟内存
  字段`VirtualSpaceNode* _next`表示链表下一个节点，即下一段虚拟内存
  字段`ReservedSpace _rs`表示当前虚拟内存
  字段`RootChunkAreaLUT _root_chunk_area_lut`表示根块的查看表（lookup table）
  方法`commit_range`和`ensure_range_is_committed`用于提交内存，即用mmap跟系统说要使用这块内存（建立页表？）
  方法`uncommit_range`“不提交”内存，即用mmap把一块内存置为不使用（撤销页表？）
  方法`allocate_root_chunk`在该节点表示的内存区域中取一个最大块
  方法`split`把一个块进行对半切分，分到想要的大小，分出来的块加入到自由链表中。使用`RootChunkArea::split`完成操作
  方法`merge`合并一个块和它的伙伴（buddy），如果可以合并的话。使用`RootChunkArea::merge`完成操作

`RootChunkAreaLUT`：根块（最大块）区域的查看表
  字段`int _num`根块区域数量
  字段`RootChunkArea* _arr`根块区域数组

`RootChunkArea`: 一个根块（最大块）区域
  字段`Metachunk* _first_chunk`表示该根块区域的第一个块，其`Metachunk::_prev_in_vs、_next_in_vs`表示它在该跟区域的前后块，用于伙伴（buddy)块的合并
  方法`alloc_root_chunk_header`在块头池`ChunkHeaderPool`里面拿一个块头（应该是把表示块的结构`Metachunk`缓存起来重用了，避免因为split和merge操作过于频繁导致的问题）
  方法`split`把一个块进行对半切分，分到想要的大小，分出来的块加入到自由链表中。
  方法`merge`合并一个块和它的伙伴（buddy），如果可以合并的话。

`ChunkHeaderPool`块头池，缓存`Metachunk`来复用，避免频繁创建和销毁。`split`和`merge`操作很频繁，从而使得`Metachunk`频繁创建和销毁。
  字段`Slab* _first_slab`和`_current_slab`维护了一个`Slab`链，每个`Slab`可以存128个`Metachunk`。`_current_slab`可以理解成该链表的尾指针。
  字段`MetachunkList _freelist`维护一个`Metachunk`链表，用于存放回收的`Metachunk`。所以获取的时候先从`_freelist`取，`_freelist`没有再在`Slab`中创建。

`Slab`每个存128个`Metachunk`

`MetachunkList`: `Metachunk`组成的链表，注意只有链表头指针，没有链表尾指针。而`FreeChunkList`有链表尾指针。
`Metachunk`: 表示元空间的一个块
  字段`chunklevel_t _level`表示块级别，也是块大小，为0时块空间最大（当前最大为16M，所以最小是1k，块级别为15)
  字段`Metachunk* _prev`和`_next`表示当前链中的前后成员，可以是`ChunkHeaderPool`、`MetaspaceArena`、`ChunkManager`中的链表
  字段`Metachunk* _prev_in_vs`和`_next_in_vs`表示在伙伴（buddy）系统中相邻的块指针
  方法`ensure_committed*`和`uncommit*`负责提交、撤销内存，即创建页表和撤销页表

`ChunkManager`: 块管理器，管理、操作上面各种数据结构所表示的块`Metachunk`。
  类加载器数据`ClassLoaderData`就是通过这个类来获取元空间的块的。
  字段`VirtualSpaceList* _vslist`表示要操作的context空间
  字段`FreeChunkListVector _chunks`表示`FreeChunkList`组成的数组，数组的每一项（即一个`FreeChunkList`）表示相同`chunklevel`（也就是块大小一样）的块组成的链表
  方法`get_chunk`和`get_chunk_locked`: 获取一个块的方法。通过一些策略从`_chunks`中查看合适的块。如果找不到则先调用`VirtualSpaceList::allocate_root_chunk`分配一个块。最后找到合适的块`Metachunk`，就看其`chunklevel`调用`Metachunk::VirtualSpaceNode::split`进行`split`操作。然后按照需要`commit`内存。
  方法`return_chunk`和`return_chunk_locked`: 回收一个块的方法。先调用`Metachunk::VirtualSpaceNode::merge`来合并块，把合并后的块加入自由块链表`_chunks`中。
  方法`purge`: 对块进行清理工作，GC后被调用。使用`Metachunk::uncommit_locked`来清理`_chunks`中大于提交（`commit`）粒度的所有块（撤销页表？）。

FreeChunkListVector: `FreeChunkList`组成的数组
  字段`FreeChunkList _lists[]`表示`FreeChunkList`组成的数组

`FreeChunkList`: `Metachunk`组成的链表，有链表头和尾指针。

整体对外接口: 
  `ChunkManager::get_chunk`被`ClassLoaderData`的`ClassLoaderMetaspace::MetaspaceArena::allocate_new_chunk和allocate`使用
  `ChunkManager::return_chunk`被`MetaspaceArena::~MetaspaceArena`析构函数使用，在GC后，`delete ClassLoaderData`时被调用
  `ChunkManager::purge`被`ClassLoaderDataGraph::purge`，最终被GC使用
  `Metaspace::allocate`被`MetaspaceObj::operator new`使用，用于分配继承`MetaspaceObj`的类的对象。不过`Metaspace::allocate`最后还是调用`ClassLoaderData::ClassLoaderMetaspace::MetaspaceArena::allocate`来分配

也就是:
一个类继承了`MetaspaceObj`，`new`的时候要传入一个类加载器数据`ClassLoaderData`作为参数，然后调用`MetaspaceObj::operator new`进行new操作，它会调用`Metaspace::allocate`，最后调用`ClassLoaderData::ClassLoaderMetaspace::MetaspaceArena::allocate`来分配内存。所以一个类加载器的所有加载的类和其他元数据都被记录下来了，最后如果类加载器的OOP被GC回收了，对应元空间的内容都可以去除。

### Java堆的对象
  其类都要继承`oopDesc`（常说的`OOP`是`oopDesc *`）

## 关于内存的总结: 1、2、3规律
1个C堆，大部分对象都分配在C堆，用malloc/realloc/free方法
2种特殊对象，StackObj不能分配在堆上、AllStatics不能分配
3种特殊管理的内存，Java堆，metaspace，Arena

