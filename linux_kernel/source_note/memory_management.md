## Linux内存管理
[x86_64 Support - 29.3. Memory Management](https://docs.kernel.org/arch/x86/x86_64/mm.html)
[Memory Layout on AArch64 Linux](https://docs.kernel.org/arch/arm64/memory.html)
《Linux Kernel Development》
  - 第12章 Memory Management
  - 第15章 The Process Address Space
  - 第16章 The Page Cache and Page Writeback
《Linux内核源代码情景分析》
  - 第2章 存储管理
《Professional Linux Kernel Architecture》
  - 第3章 Memory Management
  - 第4章 Virtual Process Memory
  - 第16章 Page and Buffer Cache
  - 第18章 Page Reclaim and Swapping
《Understanding the Linux Kernel》
  - 第2章 Memory Addressing
  - 第8章 Memory Management
  - 第9章 Process Address Space
  - 第15章 The Page Cache
  - 第17章 Page Frame Reclaiming
《Understanding The Linux Virtual Memory Manager》


### 数据结构
常用类型定义在下列文件中
```
arch/x86/include/asm/page*
arch/x86/include/asm/pgtable*
include/linux/mm*
arch/x86/mm/*
```

#### 物理内存相关数据结构
一个系统有多个numa节点（由硬件决定），一个numa节点有多个区域`zone`（按区域类型`zone_type`划分，一般有5个区域类型），一个区域`zone`有多个自由区域`free_area`（按伙伴分配器的层级划分，一般有11层），每个自由区域`free_area`列表有多个自由列表`free_list`（按迁移类型`migratetype`划分，一般有5个迁移类型）

- **所有numa节点的内存信息在`arch/x86/mm/numa.c`的全局变量`struct pglist_data *node_data[MAX_NUMNODES]`**，是一个`struct pglist_data`指针数组。
- 每个numa节点的信息在`include/linux/mmzone.h::struct pglist_data/pg_data_t`。
  - **该numa节点的所有区域`zone`在`struct zone node_zones[MAX_NR_ZONES]`**，是一个`zone`数组
  - 每个numa节点最多有5个`zone`，对应5个`zone`类型`zone_type`。
  - 所有numa节点的所有`zone`在`struct zonelist node_zonelists[MAX_ZONELISTS]`，是一个`node_zonelists`数组
    - 每个`node_zonelists`都包含所有numa节点的所有`zone`，只不过这些`zone`在`node_zonelists`的顺序不同
    - 分配内存的时候指定一个`node_zonelists`，就会按`node_zonelists`中`zone`的顺序进行分配
    - 也就是`node_zonelists`数组的每一个`node_zonelists`就是一个分配顺序。
  - 其它，未看
- 区域`include/linux/mmzone.h::zone`表示一个内存区域的信息。一个numa节点的每个区域类型`zone_type`都会有一个区域`zone`
  - 5个区域类型`zone_type`为`DMA`、`DMA32`、`Normal`、`Movable`、`Device`。
  - 上一层的信息： numa节点号`int node`，numa节点信息`struct pglist_data	*zone_pgdat`
  - 各种页的数量、区域名`name`、区域是否连续`contiguous`
  - **空闲区域`free_area`数组`struct free_area	free_area[MAX_ORDER + 1]`，每个空闲区域`free_area`对应伙伴分配器的一个层级。**
  - 其他，未看
- 空闲区域`include/linux/mmzone.h::free_area`
  - 每个空闲区域`free_area`对应伙伴分配器的一个层级，伙伴分配器一共有11层，对应`2^0 * 4K - 2^10 * 4K`，即`4K - 4M`。
  - 空闲区域的空闲页数量`unsigned long nr_free`（注意，这里的页大小由伙伴分配器层级决定）
  - 空闲区域由多个自由列表`struct list_head	free_list[MIGRATE_TYPES]`，自由列表按迁移类型`migratetype`划分，一般有5个迁移类型
- 自由列表`include/linux/mmzone.h::free_area::free_list`
  - 自由列表按迁移类型`migratetype`划分，一般有5个迁移类型`MIGRATE_UNMOVABLE`、`MIGRATE_MOVABLE`、`MIGRATE_RECLAIMABLE`、`MIGRATE_PCPTYPES`、`MIGRATE_ISOLATE`
  - 不同类型的自由列表`free_list`可能共享同一个列表
  - // TODO
- 页`page`
// TOOD

- 物理页分section汇总信息 `mm/sparse.c::struct mem_section **mem_section`
稀疏且不连续，不同于连续平铺的`mem_map`或者numa节点内部连续的`node_mem_map`
// TODO

#### 虚拟内存相关数据结构
每个进程（或线程）的`include/linux/sched.h::task_struct`中，有一个`struct mm_struct *mm/active_mm`表示该进程（或线程，多个线程共享一个`mm_struct`）的所有内存相关信息。

`task_struct`具体内容详见[进程管理 process_management.md](/linux_kernel/source_note/process_management.md)。

进程的所有内存相关信息`include/linux/mm_types.h::mm_struct`：
- 上一层的信息：`struct task_struct *owner`
- 引用计数`mm_count`、用户数`mm_users`、VMA数量`map_count`、虚拟空间大小`task_size`等计数信息
- **`vm_area_struct`的信息`struct maple_tree mm_mt`，一个maple树**。（`maple树`取代了之前的`链表+AVL树`）
- 顶级页表的地址 `pgd_t * pgd`
- 代码段、数据段的信息`start_code, end_code, start_data, end_data`
-`brk`的信息`start_brk, brk`
- 参数和环境信息`arg_start, arg_end, env_start, env_end`

进程的一段内存区域`include/linux/mm_types.h::vm_area_struct`：
- 上一层的信息：`struct mm_struct *vm_mm`
- 该段的开始和结束地址`[vm_start, vm_end)`
- 权限信息`pgprot_t vm_page_prot`、`vm_flags_t vm_flags`
- 方法指针`struct vm_operations_struct *vm_ops`


#### 交换区间相关数据结构
所有交换设备信息在`mm/swapfile.c::struct swap_info_struct *swap_info[MAX_SWAPFILES]`，每个`swap_info_struct`
// TODO




### 算法（内存相关操作）
- 页面分配和释放
- 页面换入、换出
- `Page Fault`操作


#### 页面分配和释放



#### 页面换入、换出
- free list
- inactive clean list
- inactive dirty list
- active list



#### `Page Fault`操作
```
asm_exc_page_fault（没找到具体代码在哪个文件）
arch/x86/mm/fault.c::exc_page_fault
arch/x86/mm/fault.c::handle_page_fault
  arch/x86/mm/fault.c::do_kern_addr_fault
  arch/x86/mm/fault.c::do_user_addr_fault
```

- 越界访问，返回`SIGSEGV`
- 非法访问（权限不足等），返回``
- 合法，但是物理页还没分配
  - 拓展栈
    - 正常成功拓展会改变`vm_area_struct`（虚拟地址的内容），之后要在页表中建立内存映射（物理地址的内容）
    - 如果栈超出限制范围，则返回`-ENOMEM`
  - `vm_area_struct`已经有的页
    - 文件mmap中的页
    - 其他mmap的页（注意，这里只读的页都为空，指向唯一的空页）
    - 其他 // TODO
- 合法，页在交换区
  - 页面从交换区换入


### 相关系统调用

#### brk系统调用
`mm/mmap.c::SYSCALL_DEFINE1(brk, ...)`


#### mmap系统调用
`arch/x86/kernel/sys_x86_64.c::SYSCALL_DEFINE6(mmap, ...)`


#### munmap系统调用
`mm/mmap.c::SYSCALL_DEFINE2(munmap, ...)`



#### mremap系统调用
`mm/mremap.c::SYSCALL_DEFINE5(mremap, ...)`


#### mprotect系统调用
`mm/mprotect.c::SYSCALL_DEFINE3(mprotect, ...)`


