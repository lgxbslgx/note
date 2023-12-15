本文描述`安全点`相关内容

## 安全点
`VMThread`线程执行`VM_Operation`操作时，必须进入安全点，也就是其他线程必须停止。最常见的就是GC操作。
进入安全点后，只有`VMThread`线程和它的`WorkerThread`能运行，其他线程必须停止。
`VMThread`线程必须等待其他线程进入安全点，其他线程在安全点必须停止。
线程内容详见`threads.md`。

安全点初始化:
`SafepointMechanism::initialize -> pd_initialize -> default_initialize`
- `_poll_word_armed_value`置为`1`，`_poll_word_disarmed_value`置为`~1`
- 向系统申请2个页`os::reserve_memory`并提交 `os::commit_memory_or_exit`
- 一个页`bad_page`置为`不可读不可写`，另一页`good_page`设置为`可读`
- `_poll_page_armed_value`置为`bad_page`，`_poll_page_disarmed_value`置为`good_page`
- `_polling_page`置为`bad_page`，`_poll_bit`置为`1`(也就是初始化后就处于安全点)
- 注意:
  - `_poll_word_armed_value`和`_poll_word_disarmed_value`是值，用于测试它的值是否为1。主要是解释器、native代码使用。
  - `_poll_page_armed_value`和`_poll_page_disarmed_value`是对应页的首地址，用于测试页是否可读。主要是编译后的代码使用。


### `VMThread`线程
`VMThread`线程进行具体操作之前，要通知、确认其它线程停止在安全点。 具体操作在`SafepointSynchronize::begin`。
`VMThread`线程执行完具体操作后，要通知其他线程可以退出安全点。具体操作在`SafepointSynchronize::end`。 

具体运行栈：
```shell
SafepointSynchronize::begin safepoint.cpp:353
VMThread::inner_execute vmThread.cpp:428
VMThread::loop vmThread.cpp:502
VMThread::run vmThread.cpp:175
Thread::call_run thread.cpp:217
thread_native_entry os_linux.cpp:778
start_thread 0x00007f253a52a6db
clone 0x00007f253ac8461f
```

`SafepointSynchronize::begin`具体操作:
- 设置`SafepointTracing`的一些值
- **调用堆的同步开始方法`CollectedHeap::safepoint_synchronize_begin -> SuspendibleThreadSet::synchronize`。这一步会停止所有GC相关的并发线程。**
  - 把`SuspendibleThreadSet::_suspend_all`设置为`true`
  - 调用`SuspendibleThreadSet::is_synchronized`直到所有正在运行的GC并发线程停止（GC并发线程的操作见下文）
  - 所有运行的GC并发线程最终停止的判断: `SuspendibleThreadSet::_nthreads`等于`SuspendibleThreadSet::_nthreads_stopped`
- 获取线程锁`Threads_lock->lock`
- 设置`_nof_threads_hit_polling_page`和`_current_jni_active_count`为0
- 获取Java线程（继承`JavaThread`的线程）个数`Threads::number_of_threads`，设置到`SafepointSynchronize::_waiting_to_block`中
- **进入安全点操作 `SafepointSynchronize::arm_safepoint`**
  - 调用`WaitBarrierType::arm`设置`_futex_barrier`为安全点计数（安全点数量，也就是下一个安全点的id）
    - `_futex_barrier`会在后面Java线程阻塞的时候使用。Java线程使用`futex`系统调用，判断`_futex_barrier`是否等于原来的值，等于的话则一直阻塞。
  - 递增安全点计数`_safepoint_counter`
  - 设置`_state`为`_synchronizing`
  - **设置每个Java线程的`_polling_word`为`_poll_word_armed_value`，`_polling_page`为`_poll_page_armed_value`。**
    - 代码在`SafepointMechanism::arm_local_poll`
    - 注意: 恢复`_polling_word`和`_polling_page`的内容是由Java线程自己做的，后面的`SafepointSynchronize::end`不用操作。
- **确定所有Java线程已经停止 `SafepointSynchronize::synchronize_threads`**
  - 先遍历一遍所有线程，找出未停止的线程
  - 循环遍历上一步`未停止的线程`，直到所有线程停止
  - **判断Java线程是否停止的代码在`SafepointSynchronize::thread_not_running`**
    - 判断`_safepoint_safe`是否为`true`，正常情况下为`false`。代码在`ThreadSafepointState::is_running`
    - 验证Java线程状态 `ThreadSafepointState::examine_state_of_thread`
      - 确认Java线程状态是否正确 `safepoint.cpp::safepoint_safe_with`
        - 如果线程处于`_thread_in_native`（运行native代码），最后一个不是Java帧或者有`walkable`的栈，则正常
        - 如果线程处于`_thread_blocked`（阻塞），则正常
        - 其他情况，都不正常，说明线程还未进入安全点
      - 对状态正常（已进入安全点）的线程进行计数 `ThreadSafepointState::account_safe_thread`
        - 递减`SafepointSynchronize::_waiting_to_block`。 `SafepointSynchronize::decrement_waiting_to_block`
        - 如果Java线程处于临界区，则递增`_current_jni_active_count`
        - 设置线程的`_safepoint_safe`为`true`。
- 设置`_state`为`_synchronized`
- 递增`_safepoint_id`
- 设置`_current_jni_active_count`到`GCLocker::_jni_lock_count`
- 再次设置`SafepointTracing`的一些值
- 做一些清理的工作`SafepointSynchronize::do_cleanup_tasks`。未仔细看。
- 提交一些JFR事件

`SafepointSynchronize::end`具体操作:
- 退出安全点操作 `SafepointSynchronize::disarm_safepoint`
  - 设置`_state`为`_not_synchronized`
  - 递增安全点计数`_safepoint_counter`（开始递增一次，结束又递增一次）
  - 设置所有线程的`ThreadSafepointState::_safepoint_safe`为`false`
    - 进入安全点时，会在`ThreadSafepointState::account_safe_thread`设置它为`true`
  - 释放获取线程锁`Threads_lock->unlock`
  - 调用`WaitBarrierType::disarm`设置`_futex_barrier`为0
    - `_futex_barrier`会在后面Java线程阻塞的时候使用。设置`_futex_barrier`为0使得`futex`系统调用不再阻塞，Java线程从而可以返回
- 调用堆的同步方法`CollectedHeap::safepoint_synchronize_end -> SuspendibleThreadSet::desynchronize`。这一步会唤醒所有GC相关的并发线程。
  - 调用`SuspendibleThreadSet::desynchronize`，把`SuspendibleThreadSet::_suspend_all`设置为`false`
  - 调用`MonitorLocker::notify_all`唤醒所有GC并发线程（GC并发线程的操作见下文）
- 设置`SafepointTracing`的一些值
- 提交一些JFR事件


### GC并发线程
使用`SuspendibleThreadSet`管理。
包括G1的refine、mark、service线程，还有ZGC、Shenandoah的GC线程。相关代码在`SuspendibleThreadSet`、`SuspendibleThreadSetJoiner`。

GC并发线程开始具体工作之前，会调用`SuspendibleThreadSet::join`（`SuspendibleThreadSetJoiner`的构造函数）:
- 如果`VMThread`已经通知了要停止（`SuspendibleThreadSet::_suspend_all`为`true`，即`SuspendibleThreadSet::should_yield`返回`true`）
  - 则GC并发线程调用`MonitorLocker::wait`，等待其他地方唤醒
- 如果`VMThread`未通知要停止（`SuspendibleThreadSet::_suspend_all`为`false`，即`SuspendibleThreadSet::should_yield`返回`false`）
  - 递增`SuspendibleThreadSet::_nthreads`，GC并发线程继续操作

GC并发线程完成具体工作之后，会调用`SuspendibleThreadSet::leave`（`SuspendibleThreadSetJoiner`的析构函数）:
- 递减`SuspendibleThreadSet::_nthreads`。
- 如果`VMThread`已经通知了要停止（`SuspendibleThreadSet::_suspend_all`为`true`，即`SuspendibleThreadSet::should_yield`返回`true`）
  - 则GC并发线程调用`MonitorLocker::wait`，等待其他地方唤醒
- 如果`VMThread`未通知要停止（`SuspendibleThreadSet::_suspend_all`为`false`，即`SuspendibleThreadSet::should_yield`返回`false`）
  - GC并发线程继续操作

GC并发线程工作过程中，会不断调用`SuspendibleThreadSet::yield`来判断`VMThread`是否通知要停止
- 如果`VMThread`已经通知了要停止（`SuspendibleThreadSet::_suspend_all`为`true`，即`SuspendibleThreadSet::should_yield`返回`true`）
  - 递增`SuspendibleThreadSet::_nthreads_stopped`
  - 调用`MonitorLocker::wait`，等待其他地方唤醒
  - 唤醒后，递减`SuspendibleThreadSet::_nthreads_stopped`
- 如果`VMThread`未通知要停止（`SuspendibleThreadSet::_suspend_all`为`false`，即`SuspendibleThreadSet::should_yield`返回`false`）
  - GC并发线程继续操作

这样数量`SuspendibleThreadSet::_nthreads_stopped`和`SuspendibleThreadSet::_nthreads`可以对应。


### Java线程 状态为`_thread_in_Java`（解释执行字节码时）
模板解释器`TemplateInterpreter`有一个正常入口表`_normal_table`和一个安全点入口表`_safept_table`，还有一个当前活跃的入口表`_active_table`。
安全点入口表`_safept_table`的每一字节码**入口位置**都比正常入口表`_normal_table`多运行一个方法`InterpreterRuntime::at_safepoint`。
一般情况下`_active_table`设置为正常入口表`_normal_table`。 

当`VMThread`线程通知Java线程进入安全点时，即`VMThread`设置每个Java线程的`_polling_word`为`_poll_word_armed_value`，
`_polling_page`为`_poll_page_armed_value`时，解释器代码会在一些特定时候（主要是特定字节码运行的时候）轮寻`_polling_word`，
判断是否需要进入安全点（`_polling_word`是否等于`SafepointMechanism::_poll_bit`）。这些具体的时候为:
- 分支相关字节码 `goto*`、`if*`、`tableswitch`、`lookupswitch`、`jsr*`
- 返回相关字节码 `*return`、`ret`

生成这些`检测代码`的位置:
- `TemplateTable::分支相关字节码 -> InterpreterMacroAssembler::dispatch_only(,true) -> dispatch_base -> JavaThread::polling_word_offset`
- `TemplateTable::返回相关字节码 -> InterpreterMacroAssembler::dispatch_next(,,true) -> dispatch_base -> JavaThread::polling_word_offset`
- `TemplateTable::_return -> JavaThread::polling_word_offset` （这里感觉可以重用`dispatch_next`的代码）

轮寻`_polling_word`发现需要进入安全点时:
- 把`_safept_table`赋值给`_active_table`
  - `dispatch_base`里面的`lea(rscratch1, ExternalAddress((address)safepoint_table))`
- 之后调用安全点入口表`_safept_table`的代码，即会调用方法`InterpreterRuntime::at_safepoint`
  - 先创建`ThreadInVMfromJava`对象
    - `ThreadInVMfromJava`对象的构造函数会调用`transition_from_java`把Java线程状态设置为`_thread_in_vm`
  - `ThreadInVMfromJava`对象的析构函数会调用`transition_from_vm`把Java线程状态设置为`_thread_in_Java`
    - 调用`SafepointMechanism::process_if_requested_with_exit_check -> SafepointMechanism::process_if_requested`判断是否要进入安全点
      - 检测Java线程的`_polling_word`是否等于`SafepointMechanism::_poll_bit`（和刚开始的操作一样） `SafepointMechanism::local_poll_armed`
      - 调用`SafepointMechanism::process -> SafepointMechanism::global_poll`检测`SafepointSynchronize::_state`是否等于`SafepointSynchronize::_not_synchronized`（是否在安全点）
      - 处于安全点则调用`SafepointMechanism::process -> SafepointSynchronize::block`设置Java线程状态为`_thread_blocked`，然后调用`LinuxWaitBarrier::wait -> futex系统调用`阻塞线程，直到`_futex_barrier`被修改。
      - 阻塞返回后，设置Java线程状态为未阻塞前的状态
      - 判断有没有握手`handshake`操作需要处理
      - **如果栈水位线对应的`epoch_id`有修改，说明栈要重新设置水位线并且重新被遍历。详细见`stack_watermark.md`。**  `SafepointMechanism::process -> StackWatermarkSet::on_safepoint -> StackWatermark::on_safepoint -> StackWatermark::start_processing`
      - 恢复线程的`_polling_word`、`_polling_page`
    - 把Java线程状态设置为`_thread_in_vm`


如果使用`全局页轮寻`，则`VMTHread`线程调用`Interpreter::notice_safepoints`，把`_active_table`设置成`_safept_table`。
现在主线已经删除了`全局页轮寻`，全部使用`线程本地论寻`，也就是上面说的内容。


### Java线程 状态为`_thread_in_Java`（执行已编译代码时）
编译后的代码轮寻`_polling_page`页，判断`_polling_page`页的首地址是否可读，不可读则表示进入安全点。
相关代码在:
- C1: `LIR_Assembler::safepoint_poll`
- C2: `Parse::add_safepoint`

虚拟机初始化的时候，会向操作系统注册一些信号处理函数。注册的处理器中有一项类型为`SIGSEGV`，用于处理内存访问错误（段错误）。注册相关代码为:
```
Threads::create_vm ->
os::init_2 ->
PosixSignals::init ->
install_signal_handlers ->
set_signal_handler ->
PosixSignals::install_sigaction_signal_handler 注册`JVM_handle_linux_signal`为处理函数
```

轮寻`_polling_page`发现不可读时，会生成`SIGSEGV`信号，然后会调用之前注册的信号处理函数`JVM_handle_linux_signal`。它调用`PosixSignals::pd_hotspot_signal_handler -> SharedRuntime::get_poll_stub`获取`SIGSEGV`对应的处理函数: `SharedRuntime::_polling_page_return_handler_blob`、`SharedRuntime::_polling_page_safepoint_handler_blob`。

处理函数`SharedRuntime::_polling_page_return_handler_blob`、`SharedRuntime::_polling_page_safepoint_handler_blob`在`SharedRuntime::generate_stubs -> SharedRuntime::generate_handler_blob`中创建。

处理函数`SharedRuntime::_polling_page_return_handler_blob`、`SharedRuntime::_polling_page_safepoint_handler_blob`**最终会调用`SafepointSynchronize::handle_polling_page_exception`完成进入安全点的操作**:
- Java线程状态设置为`_thread_in_vm`
- 递增`_nof_threads_hit_polling_page`
- 调用`ThreadSafepointState::handle_polling_page_exception`完成具体操作
  - 注意: 里面会调用`SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）
- Java线程状态设置为`_thread_in_Java`


### Java线程 状态为`_thread_in_native`（执行native代码时）
`VMThread`线程会把执行native代码的Java线程（Java线程状态为`thread_in_native`），视为已进入安全点。
不过Java线程在执行native代码的前后，会判断是否进入安全点（轮寻`_polling_word`）。**也就是Java线程状态转换时会判断是否进入安全点，详见下文`Java线程状态转换`。**
- `native`方法返回时
- 执行`MethodHandle`对应的`native`代码前

生成这些`检测代码`的位置:
- `native`方法返回时 `TemplateInterpreterGenerator::generate_native_entry -> MacroAssembler::safepoint_poll`
- 执行`MethodHandle`对应的`native`代码前 `AdapterHandlerLibrary::create_native_wrapper -> SharedRuntime::generate_native_wrapper -> MacroAssembler::safepoint_poll`

`safepoint_poll`轮寻`_polling_word`发现要进入安全点时:
`native`方法返回时 或者 执行`MethodHandle`对应的`native`代码前，都是执行`JavaThread::check_special_condition_for_native_trans -> SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）


### Java线程状态为`_thread_in_vm`（执行虚拟机代码时）
// TODO 


### Java线程状态为`_thread_blocked`（线程阻塞时）
在阻塞的代码前，插入一个`ThreadBlockInVM`、`ThreadBlockInVMPreprocess`类型的变量
- `ThreadBlockInVMPreprocess`的构造函数中，调用`transition_from_vm(thread, _thread_blocked)`转换状态为`_thread_blocked`
- 阻塞的线程唤醒后，会调用`ThreadBlockInVMPreprocess`的析构函数，转换状态为`_thread_in_vm`，然后使用`SafepointMechanism::process_if_requested`进行**安全点相关操作**（和上文一样）


### Java线程状态转换
主要Java线程状态
- `_thread_in_vm`: 线程运行所有虚拟机目录`src/hotspot`的代码时都在`_thread_in_vm`状态（也就是运行C++代码时都在`_thread_in_vm`状态，当然除了C++解释器）
- `_thread_in_Java`: 线程运行模板解释器、C++解释器、编译器生成的代码时都在`_thread_in_Java`状态
- `_thread_in_native`: 线程调用native方法时处于`_thread_in_native`状态（也就是运行C代码时处于`_thread_in_native`状态）

注意: 模板解释器、编译器会在虚拟机初始化时或者运行中动态生成代码。这时编译器线程处在`_thread_in_vm`状态，但是运行生成的代码的线程在`_thread_in_Java`状态。


在下面Java线程状态转换的时候，要检测安全点
- `_thread_in_native` -> `_thread_in_vm`
- `_thread_in_vm` -> `_thread_in_Java`
- `_thread_in_native` -> `_thread_in_Java`
- `_thread_blocked` -> `_thread_in_vm`

详细内容如下:

`_thread_in_vm` <--> 其他状态
- 当虚拟机代码调用native代码的时候
  - 会在native代码调用前，创建`ThreadToNativeFromVM`对象（没有固定的宏，需要开发者自己注意），`ThreadToNativeFromVM`构造函数会调用`transition_from_vm(thread, _thread_in_native)`转换成`_thread_in_native`状态
  - 从native代码返回的时候，`ThreadToNativeFromVM`析构函数会调用`transition_from_native(_thread, _thread_in_vm)`转换成`_thread_in_vm`状态
    - 先把状态变成`_thread_in_vm`
    - 调用`SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）
    - 再把状态变成`_thread_in_vm`
- 当虚拟机代码调用Java代码的时候 `JavaCalls::call -> JavaCalls::call_helper`
  - 会在Java代码调用前，创建`JavaCallWrapper`对象，`JavaCallWrapper`构造函数会调用`ThreadStateTransition::transition_from_vm(thread, _thread_in_Java, true /* check_asyncs */)`转换成`_thread_in_Java`状态
    - 调用`SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）
    - 再把状态变成`_thread_in_Java`
  - 从Java代码返回的时候，`JavaCallWrapper`析构函数会调用`ThreadStateTransition::transition_from_java(_thread, _thread_in_vm)`转换成`_thread_in_vm`状态


`_thread_in_Java` <--> 其他状态
- 当Java代码调用hotspot内部方法的时候（主要是runtime库）
  - 会在宏`JRT_ENTRY`处创建`ThreadInVMfromJava`对象，`ThreadInVMfromJava`构造函数会调用`transition_from_java(thread, _thread_in_vm)`转换成`_thread_in_vm`状态
  - 从虚拟机返回的时候，`ThreadInVMfromJava`析构函数会调用`transition_from_vm(_thread, _thread_in_Java, _check_asyncs)`转换成`_thread_in_Java`状态
    - 调用`SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）
    - 再把状态变成`_thread_in_Java`
- 当Java代码调用native方法的时候 `TemplateInterpreterGenerator::generate_native_entry`
  - 调用native代码前，调用`movl(Address(thread, JavaThread::thread_state_offset()),_thread_in_native)`把状态转换成`_thread_in_native`状态
  - native代码返回后
    - 先调用`JavaThread::check_special_condition_for_native_trans -> SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**。（和上文一样）
    - 调用`movl(Address(thread, JavaThread::thread_state_offset()),_thread_in_Java)`把状态转换成`_thread_in_Java`状态


`_thread_in_native` <--> 其他状态
- 当native代码调用hotspot内部方法的时候（主要是虚拟机对外接口`jni.h、jvm.h`）
  - 会在宏`JNI_ENTRY`处创建`ThreadInVMfromNative`对象，`ThreadInVMfromNative`构造函数会调用`transition_from_native(thread, _thread_in_vm)`转换成`_thread_in_vm`状态
    - 先把状态变成`_thread_in_vm`
    - 再调用`SafepointMechanism::process_if_requested_with_exit_check`进行**安全点相关操作**（和上文一样）
    - 再把状态变成`_thread_in_vm`
  - 从虚拟机返回的时候，`ThreadInVMfromNative`析构函数会调用`transition_from_vm(_thread, _thread_in_native)`转换成`_thread_in_native`状态
- native代码调用Java代码
  - 先调用hotspot内部方法（主要是虚拟机对外接口`jni.h、jvm.h`）`_thread_in_native` -> `_thread_in_vm`
    - 比如`jni_CallStaticVoidMethod`
  - hotspot内部方法再使用`JavaCalls::call`调用Java代码 `_thread_in_vm` -> `_thread_in_Java`


### 各种线程具体情况
- Java主线程（详见`start_init.md`）
在初始化虚拟机`Threads::create_vm`的时候会把自己的Java线程状态设置为`_thread_in_vm`。在将要返回到`java.c::JavaMain -> java.c::InitializeJVM`的时候，在`jni.cpp::JNI_CreateJavaVM_inner`设置状态为`_thread_in_native`。之后的状态转换完全按上文的`Java线程状态转换`规则进行。

- 用户显式创建的Java线程（调用Java代码`Thread::start0 -> jvm.cpp::JVM_StartThread`)
  - 先调用`JavaThread::JavaThread -> os::create_thread`创建线程（Java线程状态初始化为`_thread_new`），然后调用`Thread::start`启动线程
  - 线程运行开始时，调用`os_linux.cpp::thread_native_entry -> Thread::call_run -> JavaThread::run`设置状态为`_thread_in_vm`。之后的状态转换完全按上文的`Java线程状态转换`规则进行。

- 其他内部的Java线程（编译器线程等）
和上面的`用户显式创建的Java线程`一样，调用`os_linux.cpp::thread_native_entry -> Thread::call_run -> JavaThread::run`设置状态为`_thread_in_vm`。之后的状态转换完全按上文的`Java线程状态转换`规则进行。

