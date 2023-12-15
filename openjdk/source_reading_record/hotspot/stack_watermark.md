## 线程的栈水位线 Stack Watermark
目前只有GC（ZGC和Shenandoah）使用这个功能，为了并发访问Java线程栈，减少STW（stop-the-world）时间。

每个`Java线程`创建的时候，会注册对应的`GC水位线`到`Java线程`中，其中含有GC自己的具体遍历操作的代码位置。
GC开始时，在STW的时候，只遍历`Java线程`栈顶的一个帧（或者前几个帧），之后就可以让`GC线程`和`Java线程`并发运行。
- `GC线程`不断遍历之前的帧和提高水位线。
- `Java线程`如果返回的速度超过了水位线，则会调用对应GC的遍历代码，代替GC执行遍历操作。
这样`GC线程`和`Java线程`并发运行，避免`Java线程`过长时间的停止。

下面以ZGC为例子。


### 注册水位线
每个`Java线程`创建的时候，会注册对应的水位线，放到字段`JavaThread::_stack_watermarks`中。
设置`StackWatermark::_state`的值为`XStackWatermark::epoch_id`，也就是`XAddressBadMask`的高32位，如果`XAddressBadMask`修改了，说明要重置水平线，重新处理栈。

Java主线程注册水位线:
```
Threads::create_vm 虚拟机初始化的时候，创建Java主线程，这时候要给主线程注册水位线
Threads::add
ZBarrierSet::on_thread_attach
StackWatermarkSet::add_watermark
```

其他Java线程创建时注册水位线:
```
JVM_StartThread Java代码中的`Thread::start0`对应的native方法，表示线程创建和运行
JavaThread::prepare 准备线程，里面会给主线程注册水位线
Threads::add
ZBarrierSet::on_thread_attach
StackWatermarkSet::add_watermark
```


### 开始遍历栈
GC在STW阶段，会根据接下来的阶段修改`XAddressBadMask`的值（代码在`XAddress::flip_to_marked`、`XAddress::flip_to_remapped`），也就是修改了`XStackWatermark::epoch_id`返回的值，说明要重置水平线，重新处理栈。

在安全点的Java线程被唤醒后（安全点内容详见`safepoint.md`），会调用`StackWatermarkSet::on_safepoint -> StackWatermark::on_safepoint -> StackWatermark::start_processing -> StackWatermark::start_processing_impl`完成栈定的遍历。
- 会遍历栈顶3个帧，后面2个命名为`callee`、`caller`
- 处理的具体操作由方法`StackWatermark::process`和`XStackWatermark::epoch_id`共同决定。`StackWatermark::process`同时有mark、relocate、remap操作，和`GC barrier`差不多。如果`XStackWatermark::epoch_id`显示是标记阶段，`StackWatermark::process`则会对帧包含的OOP指向的对象进行标记。其他阶段类似。
- 设置栈水平线`StackWatermark::_watermark`为`callee`的`sp`


### 并发遍历栈
上一步栈顶的帧处理完成后，`GC线程`和`Java线程`就可以并发运行，因为除了栈顶的帧，Java线程无法修改和访问其它帧。

只是Java线程每次返回或者异常抛出的时候，删除活动记录时`InterpreterMacroAssembler::remove_activation`，都要看它是否超过了水位线，如果超过，则要代替GC线程做具体的操作（标记等）。
- 调用`InterpreterRuntime::at_unwind -> StackWatermarkSet::before_unwind`进行操作
  - 获取线程之前注册的栈水位线，进行操作。
    - 获取处于栈顶的栈帧 `JavaThread::last_frame`
    - 再获取前一个栈帧 `frame::sender`
    - 确保刚刚获取的前一个栈帧不高于水位线`callee的sp`，高于则要处理一个栈帧，从而提高水位线（callee和caller）。
  - 使用`SafepointMechanism::update_poll_values`更新线程的`_polling_word`、`_polling_page`

`并发遍历栈`具体操作在`StackWatermarkSet::finish_processing`中，迭代处理栈的每个帧，进行对应操作。

