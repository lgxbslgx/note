## handshake 握手
handshake可以单独停止某个线程，避免像safepoint一样停止全部Java线程。

### 数据结构
每个Java线程都有一个字段`HandshakeState _handshake`用于记录handshake相关的信息。里面有
- 当前线程 `JavaThread* _handshakee`
- 操作任务队列 `FilterQueue<HandshakeOperation*> _queue`
- 发起握手的线程 `Thread* volatile _active_handshaker`


### 发起握手操作
每个线程调用方法`Handshake::execute`即可对另一个线程发起握手操作。具体内容：
- 往线程的`HandshakeState _handshake::_queue`添加一个任务
- 调用`SafepointMechanism::arm_local_poll_release`设置线程的`_polling_word`和`_polling_page`
- 不断调用`HandshakeState::try_process`处理任务，直到队列中没有任务则返回

还有一种异步握手操作。具体内容：
- 往线程的`HandshakeState _handshake::_queue`添加一个任务
- 调用`SafepointMechanism::arm_local_poll_release`设置线程的`_polling_word`和`_polling_page`
- 这里没有处理操作，也就是**只提交**。


### 响应握手操作
Java线程在特定位置查询自己的`_polling_word`或`_polling_page`判断是否需要进行安全点操作。如果需要则判断`SafepointSynchronize::_state`是否等于`SafepointSynchronize::_not_synchronized`，来决定是否阻塞。（详见`safepoint.md`）

如果不需要阻塞，则调用`HandshakeState::has_operation`判断是否有handshake操作，如果有操作，则调用`HandshakeState::process_by_self`来进行处理。

// TODO 疑问: handshake的时候，线程没有真正地停止，只有处理操作或者直接返回。这样对吗？还是遗漏了什么？

