本文描述`安全点`相关内容

## 安全点
`VMThread`线程执行`VM_Operation`操作时，必须进入安全点，也就是其他线程必须停止。最常见的就是GC操作。
进入安全点后，只有`VMThread`线程和它的`WorkerThread`能运行，其他线程必须停止。
`VMThread`线程必须等待其他线程进入安全点，其他线程在安全点必须停止。
线程内容详见`threads.md`。

安全点初始化:
`SafepointMechanism::initialize -> pd_initialize -> default_initialize`
- 向系统申请2个页`os::reserve_memory`并提交`os::commit_memory_or_exit`
- 一个页`bad_page`置为`不可读不可写`，另一页`good_page`设置为`可读`
- `_poll_page_armed_value`置为`bad_page`，`_poll_page_disarmed_value`置为`good_page`
- `_poll_word_armed_value`置为`1`，`_poll_word_disarmed_value`置为`~1`
- `_polling_page`置为`bad_page`，`_poll_bit`置为`1`
- 注意`_poll_word_armed_value`和`_poll_word_disarmed_value`是值，用于测试它的值是否为1。主要是解释器、native代码使用。
- `_poll_page_armed_value`和`_poll_page_disarmed_value`是对应页的首地址，用于测试页是否可读。主要是编译后的代码使用。


## `VMThread`线程
`VMThread`线程进行操作之前要确认其它线程停止在安全点。 具体操作在`SafepointSynchronize::begin`和`SafepointSynchronize::end`。

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
- **调用堆的同步开始方法`CollectedHeap::safepoint_synchronize_begin`。这一步会停止所有GC相关的并发线程。**
  - 调用`SuspendibleThreadSet::synchronize`，把`SuspendibleThreadSet::_suspend_all`设置为`true`
  - 调用`SuspendibleThreadSet::is_synchronized`直到所有正在运行的GC并发线程停止（GC并发线程的操作见下文）
  - 所有正在运行的GC并发线程停止: `SuspendibleThreadSet::_nthreads`等于`SuspendibleThreadSet::_nthreads_stopped`
- 获取线程锁`Threads_lock->lock`
- 设置`_nof_threads_hit_polling_page`和`_current_jni_active_count`为0
- 获取Java线程（继承`JavaThread`的线程）个数`Threads::number_of_threads`，设置到`SafepointSynchronize::_waiting_to_block`中
- 进入安全点操作 `SafepointSynchronize::arm_safepoint`
  - 调用`WaitBarrierType::arm`设置`_futex_barrier`为安全点计算
  - 递增安全点计数`_safepoint_counter`
  - 设置`_state`为`_synchronizing`
  - **设置每个Java线程的`_polling_word`为`_poll_word_armed_value`，`_polling_page`为`_poll_page_armed_value`。**
    - 代码在`SafepointMechanism::arm_local_poll`
- **确定所有Java线程已经停止 `SafepointSynchronize::synchronize_threads`**
  - 先遍历一遍所有线程，找出未停止的线程
  - 循环遍历上一步`未停止的线程`，直到所有线程停止
  - **判断Java线程是否停止的代码在`SafepointSynchronize::thread_not_running`**
    - 判断`_safepoint_safe`是否为`true`，正常情况下为`false`。代码在`ThreadSafepointState::is_running`
    - 验证线程状态 `ThreadSafepointState::examine_state_of_thread`
      - 确认线程状态是否正确 `safepoint.cpp::safepoint_safe`
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
- 调用堆的同步方法`CollectedHeap::safepoint_synchronize_end`。这一步会唤醒所有GC相关的并发线程。
  - 调用`SuspendibleThreadSet::desynchronize`，把`SuspendibleThreadSet::_suspend_all`设置为`false`
  - 调用`MonitorLocker::notify_all`唤醒所有GC并发线程（GC并发线程的操作见下文）
- 设置`SafepointTracing`的一些值
- 提交一些JFR事件

## GC并发线程
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

## Java线程（解释执行字节码时）
模板解释器`TemplateInterpreter`有一个正常入口表`_normal_table`和一个安全点入口表`_safept_table`，还有一个当前活跃的入口表`_active_table`。
安全点入口表`_safept_table`的每一字节码**入口位置**都比正常入口表`_normal_table`多运行一个方法`InterpreterRuntime::at_safepoint`。
一般情况下`_active_table`设置为正常入口表`_normal_table`。 

当`VMThread`线程通知Java线程进入安全点时，即`VMThread`设置每个Java线程的`_polling_word`为`_poll_word_armed_value`，
`_polling_page`为`_poll_page_armed_value`时，解释器代码会在一些特定时候（主要是特定字节码运行的时候）轮寻`_polling_word`，
判断是否需要进入安全点（`_polling_word`是否等于`SafepointMechanism::_poll_bit`）。这些具体的时候为:
- 分支相关字节码 `goto*`、`if*`、`tableswitch`、`lookupswitch`、`jsr*`
- 返回相关字节码 `*return`、`ret`
- 非字节码: 方法返回或者抛出异常后，删除活动记录时

生成这些`检测代码`的位置:
- `TemplateTable::分支相关字节码 -> InterpreterMacroAssembler::dispatch_only(,true) -> dispatch_base -> JavaThread::polling_word_offset`
- `TemplateTable::返回相关字节码 -> InterpreterMacroAssembler::dispatch_next(,,true) -> dispatch_base -> JavaThread::polling_word_offset`
- `TemplateTable::_return -> JavaThread::polling_word_offset` （这里感觉可以重用`dispatch_next`的代码）
- 方法返回或者抛出异常后，删除活动记录时 `TemplateInterpreterGenerator::generate_throw_exception/TemplateTable::_return -> InterpreterMacroAssembler::remove_activation -> MacroAssembler::safepoint_poll`

解释器运行到上面这些位置生成的代码时，会进行对应操作（根据类型而定）:
- 如果是分支、返回相关字节码
  - 把`_safept_table`赋值给`_active_table`
    - `dispatch_base`里面的`lea(rscratch1, ExternalAddress((address)safepoint_table))`
  - 之后调用安全点入口表`_safept_table`的代码，即会调用`InterpreterRuntime::at_safepoint`
    - `InterpreterRuntime::at_safepoint`会调用`StackWatermarkSet::before_unwind -> SafepointMechanism::update_poll_values`进行处理
- 如果是方法返回或者抛出异常后，删除活动记录时，则会调用`InterpreterRuntime::at_unwind`
  - `InterpreterRuntime::at_unwind`会调用`StackWatermarkSet::before_unwind -> SafepointMechanism::update_poll_values`进行处理

如果使用`全局页轮寻`，则`VMTHread`线程调用`Interpreter::notice_safepoints`，把`_active_table`设置成`_safept_table`。
现在主线已经删除了`全局页轮寻`，全部使用`线程本地论寻`，也就是上面说的内容。


## Java线程（执行native代码时）
`VMThread`线程会把执行native代码的Java线程（线程状态为`thread_in_native`），视为已进入安全点。
不过Java线程在执行native代码的前后，会判断是否进入安全点。具体如下文。

当`VMThread`线程通知Java线程进入安全点时，即`VMThread`设置每个Java线程的`_polling_word`为`_poll_word_armed_value`，
`_polling_page`为`_poll_page_armed_value`时，Java线程在一些特定时候（主要是特定字节码运行的时候）轮寻`_polling_word`，
判断是否需要进入安全点，具体为:
- `native`方法返回时
- 执行`MethodHandle`对应的`native`代码前

生成这些`检测代码`的位置:
- `native`方法返回时 `TemplateInterpreterGenerator::generate_native_entry -> MacroAssembler::safepoint_poll`
- 执行`MethodHandle`对应的`native`代码前 `AdapterHandlerLibrary::create_native_wrapper -> SharedRuntime::generate_native_wrapper -> MacroAssembler::safepoint_poll`

轮寻发现要进入安全点时:
- `native`方法返回时 或者 执行`MethodHandle`对应的`native`代码前，都是执行`JavaThread::check_special_condition_for_native_trans`
  - `JavaThread::check_special_condition_for_native_trans`会调用`StackWatermarkSet::before_unwind -> SafepointMechanism::update_poll_values`进行处理


## Java线程（执行已编译代码时）
前面2种状态的Java线程一般都是轮寻`_polling_word`，编译后的代码则一般是轮寻`_polling_page`，判断地址`_polling_page`对应页是否可读。
相关代码在:
- C1: `LIR_Assembler::safepoint_poll`
- C2: `Parse::add_safepoint`

最终线程会变成阻塞状态`_thread_blocked`。
剩下的内容未具体看。

## 其他Java线程（编译器线程、monitor deflation线程等，详见`threads.md`）
相关代码在`ThreadBlockInVMPreprocess`。// 未具体看 TODO

## 其他
- 已经阻塞`_thread_blocked`的线程，则继续保持阻塞状态即可。
- // 其他 TODO

