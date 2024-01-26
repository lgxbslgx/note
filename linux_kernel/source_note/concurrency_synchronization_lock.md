## 并发、同步和锁 concurrency_synchronization_lock.md
《Linux Kernel Development》
  - 第9章 An Introduction to Kernel Synchronization
  - 第10章 Kernel Synchronization Methods
《Linux内核源代码情景分析》
  - 第9章 多处理器SMP系统结构
《Professional Linux Kernel Architecture》
  - 第5章 Locking and Interprocess Communication
  - 第17章 Data Synchronization
《Understanding the Linux Kernel》
  - 第5章 Kernel Synchronization

### 基础概念
本文涉及的问题：
- 操作的原子性（多核并行或核内任务调度引发）
- 乱序执行的问题

访问、操作`共享数据`的代码路径叫**临界区`critical region`**。为了避免临界区的代码并发访问共享数据，程序员要确保临界区的代码**原子`atomic`**地执行。如果不幸发生不安全的并发访问，这种情况叫做**竞争状态`race condition`**。防止不安全的并发和竞争状态的方法叫做**同步`synchronization`**。

编译器和CPU为了提高运行效率，会打乱指令的执行顺序（重排序、乱序）。

### 操作的原子性（多核并行或核内任务调度引发）
实现原子性的方案：
- 操作的数据量小，**可以**用硬件的基础数据类型表示时：**直接使用硬件提供的原子指令来实现原子操作**
- 操作的数据量大，**不可以**用硬件的基础数据类型表示时：**使用原子指令来实现一个锁，再使用锁来实现原子操作**
- **`直接使用原子指令`还是`使用显式的锁`，取决于操作的数据的粒度**

#### 硬件提供的原子指令
**[硬件原子指令的内容](/hardware/atomic.md)**

其中一些注意点如下：
- 网上一些文章说的：我的代码、我的框架使用原子指令（特别是java程序员经常经常提到的`compareAndSwap`），比使用锁效率高。这明显是本末倒置了。如果数据粒度**可以**用硬件的基础数据类型表示，当然用原子指令来实现原子操作，而不使用锁。这基本不需要思考，按照数据粒度来决定就行了。
- 而真正需要进行思考的是锁优化相关的内容：
  - 锁操作对应的原子指令的旧值和新值要取什么值。很多情况是使用`0`和`1`。
  - 锁操作前进行的操作
  - 锁操作不成功后进行的操作

#### linux内核中原子操作相关接口
原子类型`atomic_t`、`atomic64_t`定义在`include/linux/types.h`。

原子操作定义在`include/linux/atomic/atomic-instrumented.h`、`include/linux/atomic/atomic-arch-fallback.h`。
Bit类型的原子操作定义在`include/linux/bitops.h`、`include/asm-generic/bitops/instrumented-atomic.h`。

相关架构的内容在：
- x86: `arch/x86/include/asm/atomic64_64.h`、`arch/x86/include/asm/atomic.h`、`arch/x86/include/asm/bitops.h`
- arm:
  - 32位 `arch/arm/include/asm/atomic.h`
  - 64位 `arch/arm64/include/asm/atomic.h`
- riscv: `arch/riscv/include/asm/atomic.h`

#### 锁的基础知识
注意并发编程中，实现一个锁并不难（如果不做锁相关优化的话），难的是识别共享数据（也就是哪些数据需要锁来保护）和识别使用共享数据的临界区（也就是哪些代码需要使用锁）。

识别共享数据（也就是哪些数据需要锁来保护）：
- 数据只被某一任务（进程、线程）使用，不需要保护。
  - 数据创建在线程私有的数据区（比如栈上，一般是函数的局部变量）
  - 数据创建在共享数据区（比如堆），但是其地址只在线程私有的数据区（地址不传到全局变量共享数据区）
- 数据**可能**被多个任务使用，则需要保护
  - 数据创建在共享数据区（比如堆），其地址也在共享数据区被引用
  - 注意，创建在共享数据区的数据只是可能被多个任务使用，具体是否使用，还要看具体的代码

识别使用共享数据的临界区（也就是哪些代码需要使用锁）：
- 这一步一般很好判断，代码使用了共享数据，就是临界区了。不过还是有很多注意的地方。
- 锁是**保证对某个共享数据的互斥访问，不是对代码的互斥访问。锁数据而不是锁代码。**
- 也就是说**当一段代码使用到多个不同的共享数据的时候，需要分别获得多个数据的锁，而不是单纯一个锁。**
- 获取多个锁要注意锁的顺序，避免死锁

#### linux内核中锁相关接口

##### 自旋锁`spin lock`相关接口
自旋锁类型信息在`include/linux/spinlock_types.h`、`include/linux/spinlock_types_raw.h`、`include/asm-generic/qspinlock_types.h`。
自旋锁操作在`include/linux/spinlock.h`、`kernel/locking/spinlock.c`、`include/linux/spinlock_api_smp.h`。

自旋锁常用操作：
- 创建一个自旋锁：`include/linux/spinlock_types.h::DEFINE_SPINLOCK`或者`include/linux/spinlock.h::spin_lock_init`
- 获取锁：`include/linux/spinlock.h::spin_lock`
- 尝试获取锁：`include/linux/spinlock.h::spin_trylock`
- 释放锁：`include/linux/spinlock.h::spin_unlock`
- 判断是否已锁：`include/linux/spinlock.h::spin_is_locked`

注意：
- linux内核的自旋锁不是可重入的，如果已经获取一个锁，再尝试获取这个锁，就会死锁了。
- 注意自旋锁获取后，线程不能睡眠，直到是否锁，所以自旋锁只适用短时间的操作。
- 中断处理器主要使用自旋锁，因为中断处理器中间不能睡眠，而其他锁机制，比如信号量，则会导致线程睡眠。

##### 读写锁`read-write lock`相关接口
读写锁类型信息在`include/linux/rwlock_types.h`、`include/asm-generic/qrwlock_types.h`
读写锁操作在`include/linux/rwlock.h`、`kernel/locking/spinlock.c`、`include/linux/rwlock_api_smp.h`。

读写锁常用操作：
- 创建一个读写锁：`include/linux/rwlock_types.h::DEFINE_RWLOCK`或者`include/linux/rwlock.h::rwlock_init`
- 获取读锁：`include/linux/rwlock.h::read_lock`
- 获取写锁：`include/linux/rwlock.h::write_lock`
- 尝试获取读锁：`include/linux/rwlock.h::read_trylock`
- 尝试获取写锁：`include/linux/rwlock.h::write_trylock`
- 释放读锁：`include/linux/rwlock.h::read_unlock`
- 释放写锁：`include/linux/rwlock.h::write_unlock`

注意：
- 如果获取了一个`读锁`，想再获取对应的`写锁`。要先释放前面获取`读锁`，再获取`写锁`，要不然会死锁。（也就是`写锁`要等所有`读锁`全部释放才能获取）
- 因为`写锁`要等所有`读锁`全部释放才能获取，所以当有不同线程不断获取`读锁`，从而导致`读锁`计数一直不减少到0，`写锁`就一直获取不了。这使得使用读写锁要非常小心。


##### 信号量`semaphores`相关接口
注意：
- 获取自旋锁的线程不能睡眠，只能不断的获取锁。获取`信号量`的线程可以睡眠，加入到等待队列中，释放信号量的线程会唤醒等待队列中的线程。
- 信号量允许任意数量（数量在初始化的时候设置）的线程获取信号量，而自旋锁只能一个线程获取锁。
- 当信号量初始化设置数量大于`1`时，计数信号量`Counting Semaphores`。
- 当信号量初始化设置数量为`1`时，则为二进制信号量`Binary Semaphores`，也叫互斥量`mutex`。

信号量类型信息在`include/linux/semaphore.h`。
信号量操作在`kernel/locking/semaphore.c`。

信号量常用操作：
- 创建一个信号量：`include/linux/semaphore.h::DEFINE_SEMAPHORE`或者`include/linux/semaphore.h::sema_init`
- 获取信号量：`kernel/locking/semaphore.c::down`
- 尝试获取信号量：`kernel/locking/semaphore.c::down_trylock`
- 释放信号量：`kernel/locking/semaphore.c::up`

##### 读写信号量`Reader-Writer semaphores`相关接口
读写信号量实际上是一个`互斥量`，而且可以重复获取读信号。大部分和读写锁类似，只是读写信号量和普通信号量一样可以睡眠。

读写信号量类型信息在`include/linux/rwsem.h`。
读写信号量操作在`kernel/locking/rwsem.c`。

读写信号量常用操作：
- 创建一个读写信号量：`include/linux/rwsem.h::DECLARE_RWSEM`或者`include/linux/rwsem.h::init_rwsem`
- 获取读信号量：`kernel/locking/rwsem.c::down_read`
- 获取写信号量：`kernel/locking/rwsem.c::down_write`
- 尝试获取读信号量：`kernel/locking/rwsem.c::down_read_trylock`
- 尝试获取写信号量：`kernel/locking/rwsem.c::down_write_trylock`
- 释放读信号量：`kernel/locking/rwsem.c::up_read`
- 释放写信号量：`kernel/locking/rwsem.c::up_write`

##### 互斥量`mutex`相关接口
和自旋锁类似，只是互斥量可以睡眠，自旋锁不可以。和自旋锁一样，不能重复获取互斥量。

互斥量类型信息在`include/linux/mutex.h`。
互斥量操作在`kernel/locking/mutex.c`。

互斥量常用操作：
- 创建一个互斥量：`include/linux/mutex.h::DEFINE_MUTEX`或者`include/linux/semaphore.h::mutex_init`
- 获取互斥量：`kernel/locking/mutex.c::mutex_lock`
- 尝试获取互斥量：`kernel/locking/mutex.c::mutex_trylock`
- 释放互斥量：`kernel/locking/mutex.c::mutex_unlock`


##### 完成状态、完成变量`Completion Variables`
主要用在进程调度时，父子进程的交互。

完成变量类型信息在`include/linux/completion.h`。
完成变量操作在`kernel/sched/completion.c`。

完成变量常用操作：
- 创建一个完成变量：`include/linux/completion.h::DECLARE_COMPLETION`或者`include/linux/completion.h::init_completion/reinit_completion`
- 等待完成：`kernel/sched/completion.c::wait_for_completion`
- 通知已完成：`kernel/sched/completion.c::complete`


##### 顺序锁`Sequential locks`
和读写锁、读写信号量类似，只不过顺序锁是**写锁优先**，不会像读写锁那样`写锁`需要和所有`读锁`竞争，而是`读锁`的获取要判断是否有线程在申请`写锁`，有线程申请则让出，让`写锁`优先。

顺序锁类型信息在`include/linux/seqlock.h`。
顺序锁操作在`include/linux/seqlock.h`。

顺序锁常用操作：
- 创建一个顺序锁：`include/linux/seqlock.h::DEFINE_SEQLOCK`或者`include/linux/seqlock.h::seqlock_init`
- 获取写锁：`include/linux/seqlock.h::write_seqlock`
- 释放写锁：`include/linux/seqlock.h::write_sequnlock`
- 获取读锁：`include/linux/seqlock.h::read_seqbegin`
- 判断`read_seqbegin`获取的读锁是否有效：`include/linux/seqlock.h::read_seqretry`

读操作的写法和平常的锁不一样，如下所示：
```
do {
  seq = read_seqbegin(&seq_lock); // 获取读锁
  // 具体读操作
} while (read_seqretry(&seq_lock, seq)); 
// 判断开始获取的读锁是否有效，如果没效，说明读操作的时候有另外一个线程获取了写锁，
// 更新了数据。所以循环里面的读操作就没有用了，要回到循环开头再次获取读锁，进行读操作，直到成功为止。
```

### 乱序执行的问题
乱序执行的原因一般有
- 编译器优化引起（编译器不会重排有数据依赖的代码，也就是不会修改代码的语义）
- 高速缓存`cache`引起
- CPU内部指令级并行优化引起

CPU和编译器都提供了让指令顺序执行的机制（叫`barrier`、`fence`）：
- CPU提供保证顺序相关的指令
- 编译器（可能是语言语法、语言函数库、编译器的拓展）提供不重排的机制

**[硬件内存排序和内存屏障的内容](/hardware/memory_order_barrier.md)**
[LINUX KERNEL MEMORY BARRIERS](https://www.kernel.org/doc/Documentation/memory-barriers.txt)

#### linux内核中barrier相关接口
barrier接口内容在`include/asm-generic/barrier.h`。

相关架构的内容在：
- x86: `arch/x86/include/asm/barrier.h`
- arm: 32位 `arch/arm/include/asm/barrier.h`，64位 `arch/arm64/include/asm/barrier.h`
- riscv: `arch/riscv/include/asm/barrier.h`

