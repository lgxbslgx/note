## CPU内存排序`memory ordering`和内存屏障`barrier`
资料：
- 论文[Shared Memory Consistency Models: A Tutorial](https://www.cs.wustl.edu/~roger/569M/rz066.pdf)
- 论文[Memory Consistency and Event Ordering in Scalable Shared-Memory Multiprocessors](https://dl.acm.org/doi/pdf/10.1145/285930.285997)


内存排序`memory ordering`指的是处理器发起的`读写操作`通过系统总线到达系统内存的顺序（或者是到达共有缓存的顺序，然后通过缓存一致性协议来控制到系统内存的顺序）。

共享数据被多个逻辑CPU（也叫执行线程、执行单元、hart，比如2核4线程可以说是4个执行线程）**并行**修改，才要处理内存排序的问题。由于市面上大部分机器都是多核的了，并发的代码基本都是会并行运行，所以内存排序问题也就成了一个普遍的问题。

内存排序模型`memory-ordering model`（也叫内存一致性模型`memory consistency model`、内存模型`memory model`）常见种类：
- **线性一致性`Sequential Consistency Model`、程序顺序`PO program ordering`、强序`strong ordering`**
  - 处理器发起的`读写操作`通过系统总线的顺序**和指令流的顺序（也就是程序顺序）完全一样**
  - 例子：X86早期的386微架构
- **完全存储顺序 `TSO Total Store Ordering`、处理器顺序`processor ordering`**
  - **允许写后读`store-load`重排**
  - **写操作组成一个全序**，即所有写操作的顺序都要遵循程序顺序
  - 例子：X86的P6之后的架构
  - 例子：RISC-V实现`Ztso`拓展时
  - 采用TSO时，因为一些细微区别，而有下面分类：
    - **不允许**同地址的写后读`store-load`重排
    - **允许**当前执行线程的同地址的写后读`store-load`重排
    - **允许**不同执行线程的同地址的写后读`store-load`重排
- **部分存储顺序 `PSO partial store order`**
  - **允许`写后读`和不同地址的`写后写`重排**
  - **写操作组成一个偏序**，即写操作不需要遵循程序顺序
  - 例子：SPARC V8 PSO （注意：SPARC支持TSO和PSO）
- **弱内存序`WMO Weak Memory Ordering`、宽松内存序`RMO relaxed memory order`**
  - **允许全部读写顺序重排（4种，`写后读`、`写后写`、`读后写`、`读后读`）**
  - 提出`同步操作 synchronizurion operation`（`同步写`、`同步读`、`加锁操作`、`解锁操作`等），和传统的读写操作分开
    - `同步操作`组成一个全序，遵循程序顺序
    - `同步操作`可以作为屏障，分割其前后的传统读写操作
  - 例子：暂时没接触过相应架构。基本都是下文的`release consistency model`。
  - `WMO`主要描述不同地址的读写操作重排。而具体的`WMO`变种会允许一些相同地址的重排，比如允许相同地址的`load-load`、`store-load`重排。
- **`RCM release consistency model`**
  - `release consistency model`可以说是一种特殊的`弱内存序`，比`弱内存序`的要求更加宽松
  - `同步操作 synchronizurion operation`分成`acquire操作`和`release操作`
    - `同步操作`（包括`acquire操作`和`release操作`）组成一个全序，遵循程序顺序
    - `acquire操作`：acquire后面的操作要在acquire后进行，即不能排到acquire前面。
    - `release操作`：release前面的操作要在release前完成，即不能排到release后面。
  - `RCsc`和`RCpc`区别（注意RISC-V里面的不同）：
    - `RCsc`：release consistency with sequential consistency among special operations
    - `RCpc`：release consistency with processor consistency among special operations
  - 例子：RISC-V。注意RISC-V文档里面的`RCsc`表示 release consistency with processor-consistent synchronization operations，和前面论文的定义不一样，RISC-V是`同步操作`，论文是`special operations`即有数据竞争的操作。
  - 例子：ARMv8


注意内存模型和内存屏障的内容要区分对待：
- 比如X86一般都是TSO模型，所以它只需要`store-load`屏障，但是X86却有`lfence`、`sfence`、`mfence`指令，一般来说`lfence`就是多余的，以后它的内存模型改变了，`lfence`才有用。
- 比如RISC-V一般都是RCM模型，但是如果机器实现了`Ztso`拓展，也就退化成X86那样只有写后读重排，这样RISC-V的大部分内存屏障指令也没用了。


一些名词：
- `shared memory`共享内存
- `program order`运行程序的指令顺序
- `global memory order`全局可见的访问内存的顺序
- `preserved program order`保留的程序顺序（也就是不重排的程序顺序）。也是`global memory order`和`program order`一致的那部分指令的顺序。


### X86的内存模型
资料：
- Intel X86文档 第3卷 8.2 MEMORY ORDERING 
- Intel X86文档 第3卷 8.3 SERIALIZING INSTRUCTIONS
- Intel X86文档 第3卷 11 MEMORY CACHE CONTROL
- AMD X86文档 第1卷 2 Memory Model
- AMD X86文档 第2卷 2 Memory System

X86的内存模型主要有下面情况：
- 386：全部读写操作遵循程序顺序`program ordering`，文档中叫这种情况叫强序`strong ordering`
- 486和Pentium：读写操作遵循处理器顺序`processor ordering`，只有一种情况和程序顺序`program ordering`不同。这种情况是，满足下面条件时，读操作可以重排到写操作前面。
  - 读操作的数据不在缓存中
  - 写操作的数据在缓存中
  - 读和写操作**不操作同一个地址**的数据
- P6之后：也是处理器顺序`processor ordering`，读操作可以重排到写操作前面，而且同一地址的也可以重排。
  - 注意**同一地址**的写后读也可以重排，这一点和前面的`486和Pentium`不同。
  - 详见`Intel-X86文档 第3卷 8.2.2 Memory Ordering in P6 and More Recent Processor Familiesg`。
  - **这种内存模型也叫TSO，只不过X86不明确地把它称为TSO。**

处理器使用`store buffer`和`store buffer bypass/forwarding`来进行优化（存储写的数据在`store buffer`，等待数据写到缓存）。
- 在`store buffer`的写操作还不能被其他处理器见到，这时候一个**不同地址的读操作**在流水线上进行，则该读操作可能会先完成，从而导致了不同地址的`store-load`重排。
- 在`store buffer`的写操作还不能被其他处理器见到，这时候一个**相同地址的读操作**在流水线上进行，该读操作会使用`store buffer`里面的内容（这个优化叫`forwarding`或者`bypass`、`旁路`），从而导致了相同地址的`store-load`重排。
- 注意还在`store buffer`的写操作不会被其他处理器见到，而已经在缓存中的写操作可以被其他处理器看到。因为`store buffer`的存在引起`store-load`重排的乱序问题，而不是因为缓存。（缓存的写操作会因为缓存控制协议而可以被其他处理器见到，不会引起乱序问题。不过需要注意，除X86外的处理器的缓存可能引起乱序问题。）

特殊情况：
- 不满足时间局部性`Non-temporal`的数据对应的操作（比如向量相关操作，指令`MOVNTDQ`、`MOVNTI`、`MOVNTPD`、`MOVNTPS`、`MOVNTQ`等），不会缓存数据，如果之前有读操作的缓存，则会驱逐`evict`对应的缓存。还会使用`write combining WC`，使得写操作的顺序发生改变。
- 快速字符串操作（指令`MOVS`、`MOVSB`、`STOS`、`STOSB`）
  - 单个快速字符串操作的写是乱序的
  - 多个快速字符串操作的写是有序的

加强内存序（具有屏障功能）的方法：
- IO指令（指令`IN`、`OUT`）
- 有锁语义的指令、`lock`指令前缀（详见[X86提供的原子指令](/hardware/atomic.md#X86提供的原子指令)）
- barrier指令`mfence`、`sfence`、`lfence`
- 线性指令`serializing instruction`，详见`Intel-X86文档 第3卷 8.3 SERIALIZING INSTRUCTIONS`。

改变内存序的方法：
- 设置memory type range registers (MTRRs)
- 设置age attribute table (PAT)


### ARM的内存模型
资料：
- ARM手册 B2 The AArch64 Application Level Memory Model
- ARM手册 D7 The AArch64 System Level Memory Model
- ARM手册 E2 The AArch32 Application Level Memory Model
- ARM手册 G4 The AArch32 System Level Memory Model
- 论文[A Tutorial Introduction to the ARM and POWER Relaxed Memory Models](https://pauillac.inria.fr/~maranget/papers/tutorial-power-arm.pdf)

// TODO 未完成


### RISC-V的内存模型
资料：
- RISC-V规范 2.7 Memory Ordering Instructions
- RISC-V规范 3 “Zifencei” Instruction-Fetch Fence
- RISC-V规范 17 RVWMO Memory Consistency Model
- RISC-V规范 27 "Ztso" Standard Extension for Total Store Ordering
- RISC-V规范 Appendix A RVWMO Explanatory Material
- RISC-V规范 Appendix B Formal Memory Model Specifications

RISC-V的内存模型分类：
- 一般情况下（不实现`Ztso`拓展）**允许全部读写（4种）顺序重排**，除了一些`保留程序顺序`（17.1.3 Preserved Program Order）。
- 实现`Ztso`拓展时，则类似x86，只允许`写后读`重排。

RISC-V的内存模型（不实现`Ztso`拓展）具体内容（3个公理、5类`保留程序顺序`的情况，里面有12种`保留程序顺序`的具体类型）：
- 公理`Load Value Axiom`：每一个加载的值（读的值）必须满足属于下面2个情况之一
  - 读之前的全局内存序`global memory order`写的值。
  - 读之前的程序顺序存储`program ordering`写的值。
    - 当前程序指令顺序有对应的写，那当前CPU的读一定能获取其值
    - 不管该写的值在`store buffer`（未出现在全局内存序，未被其他CPU见到）
    - 还是已经写入缓存或者系统内存（已经出现在全局内存序，能被其他CPU见到）
  - 这也就和x86一样，因为`store buffer`的存在，从而允许`store-load`重排。
  - 注意：分支结构的投机执行`executes speculatively`会打乱执行顺序，也会打乱获取内存的顺序（见`A.3.2. Table 44`的例子）。
- 公理`Atomicity axiom`：对于`lr`和`sc`指令对，要满足下面2个要求（这2个只是最低要求，满足要求`sc`也不一定运行成功）
  - 对于指令序列`w -> lr -> sc`，`lr`可以重排到`写操作w`前面（因为`store buffer`），但是`sc`一定要不能重排到`w`前面
  - 另一个执行线程不能在当前CPU的`lr`和`sc`中间进行相同地址的写操作。（如果其他执行线程进行了相同地址的写操作，则`sc`运行失败）
- 公理`Progress axiom`：一个执行线程的写操作会在有限时间内被另一个执行线程看到。
- `保留程序顺序`的情况1：`Overlapping-Address Orderings`地址重合时的顺序
  - 写操作和前面的读或写操作访问同一个地址，则不能乱序
  - 同一地址的2个读操作的程序顺序之间没有同地址的写操作，并且这2个读操作读到不同写操作（其他执行线程的写操作）写入的值，则这2个读操作不能乱序。
  - 原子写操作（AMO、sc）后，同一个地址的读操作读到原子写操作写入的数据，则这里的`写后读`不能乱序
  - **前面3种情况说明：操作地址相同时，只有下面2种情况之一才能重排**
    - **`load-load`后一个load的值不旧于前一个load值（CoRR Coherence for Read-Read pairs）**，也可以说**2个load之间有store，或者2个load读到相同的store的值**
    - **`store-load`中的写操作不是`原子写操作`**
- `保留程序顺序`的情况2：`Fences`屏障指令（详见下文）
- `保留程序顺序`的情况3：`Explicit Synchronizatio`显式同步，设置原子指令（包括`LD/SC`指令对）的`aq/rl`位（详见下文）
- `保留程序顺序`的情况4：`Syntactic Dependencies`语法依赖
  - 后一个指令`语法地址依赖 syntactic address dependency`前一个指令，则不能乱序
  - 后一个指令`语法数据依赖 syntactic data dependency`前一个指令，则不能乱序
  - 后一个指令是**写操作**，并且`语法控制依赖 syntactic control dependency`前一个指令，则不能乱序
  - `语法依赖`具体内容：
    - `语法依赖 syntactic dependency`：
      - 直接依赖（中间没有其他指令）：前一个指令的`目的寄存器`等于后一个指令的`源寄存器`，并且中间没有指令以`后一个指令的源寄存器`作为目的寄存器
      - 间接依赖（中间有其他指令）：中间的某一个指令依赖前一个指令，后一个指令依赖该中间指令，并且该中间指令的`源寄存器`和`目的寄存器`有依赖关系。（注意**内存操作**指令的`源寄存器`和`目的寄存器`一般没有依赖关系，比如`load/store`相关、原子指令，其中`store`相关指令直接没有`目的寄存器`）
    - 注意`语法依赖`是任意2个指令的关系，而下面3种依赖则是`内存操作指令（即读写操作）`之间的关系。
    - `语法地址依赖 syntactic address dependency`：一个指令的`地址源寄存器`语法依赖前一个指令的`目的寄存器`
    - `语法数据依赖 syntactic data dependency`：后一个指令是**写操作**，并且该指令的`数据源寄存器`语法依赖前一个指令的`目的寄存器`。
    - `语法控制依赖 syntactic control dependency`：2个指令中间有分支指令（或间接跳转指令），且该分支指令语法依赖于前一个指令
- `保留程序顺序`的情况5：`Pipeline Dependencies`流水线依赖
  - 后一个指令是**读操作**，中间有一个**写操作**`语法地址或数据依赖`前一个指令，并且**后一个指令获取了中间`写操作`的值**，则不能乱序
  - 后一个指令是**写操作**，中间有一个指令`语法地址依赖`前一个指令，则不能乱序

**可以乱序的情况总结：**
- 同地址的 **`load-load`后一个load的值不旧于前一个load值（CoRR Coherence for Read-Read pairs）**，也可以说**2个load之间有store，或者2个load读到相同的store的值**
- 同地址的 **`store-load`中的写操作不是`原子写操作`**
- **不同地址且没有`语法依赖`和`流水线依赖`**的读写操作
  - 注意不同地址的`写后读`、`写后写`一定可以重排，因为写操作（前一个写操作）没有`目的寄存器`，也就不会被`语法依赖`和`流水线依赖`

加强内存序的方法汇总：
- `FENCE`指令
  - `FM`为`0000`，自定义屏障类型（设置`FM`后面的8个位的内容，3种类型组成8位：IO/内存、读/写、前/后）。目前只支持下面类型
    - `FENCE RW,RW`相当于全屏障
    - `FENCE RW,W`**类似于**其他架构的`release`
    - `FENCE R,RW`**类似于**其他架构的`acquire`
    - `FENCE R,R`相当于`load-load`
    - `FENCE W,W`相当于`store-store`
  - `FM`为`1000`，TSO内存模型，即只允许写后读`store-load`指令。
    - 指令汇编码为`FENCE.TSO`
- 原子指令里面的`aq/rl`位，详见文档[RISC-V提供的原子指令](/hardware/atomic.md#RISC-V提供的原子指令)
  - 设置`aq`位时，原子指令后面的指令不能重排到原子指令前面
  - 设置`rl`位时，原子指令前面的指令不能重排到原子指令后面
  - 同时设置`aq/rl`位时，原子指令相当于全屏障，前后的指令都不能跨过原子指令
  - 原子指令中，`LD/SC`指令对也不能重排。

注意`FENCE.I`指令会刷新当前核的指令缓存，只影响当前核的内容。


### 问题
- RISC-V的`fence`指令现在不支持`store-load``load-store`，那openjdk里面的相关代码是不是有问题？
