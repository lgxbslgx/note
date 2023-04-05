## 线程类`Thread`继承层级
每一个线程类`Thread`都有一个`OSThread`记录OS指定的数据。
对于`JavaThread`则还有一个`OopHandle _threadObj`，指向对应java代码的`Thread`。

下面类全都继承`Thread`
```
JavaThread (javaThread.hpp) Java线程
    CompilerThread (compilerThread.hpp) 编译器线程，执行`CompileTask`
    JvmtiAgentThread (jvmtiAgentThread.hpp) jvmti agent（代理）产生的线程
    MonitorDeflationThread (monitorDeflationThread.hpp)
    NotificationThread (notificationThread.hpp)
    ServiceThread (serviceThread.hpp) 服务线程，很杂，详见`ServiceThread::service_thread_entry`
NonJavaThread (nonJavaThread.hpp)
    AsyncLogWriter (logAsyncWriter.hpp) 写日记
    JfrThreadSampler (jfrThreadSampler.cpp)
    NamedThread (nonJavaThread.hpp)
        ConcurrentGCThread (concurrentGCThread.hpp)
          // 很多GC相关的线程
        VMThread (vmThread.hpp) 虚拟机线程，负责执行`VM_Operation`
        WorkerThread (workerThread.hpp) // GC相关
    WatcherThread (nonJavaThread.hpp) 模拟计时器中断，执行定时任务`PeriodicTask`
```

## 线程创建、执行流程
上面的线程类（或其父类）重写了`Thread`的``run`方法，并且其构造函数或者父类构造函数都会调用`os::create_thread`来创建线程，`os::create_thread`通过方法`glibc`的`pthread_create`方法来创建线程。调用`pthread_create`的时候都传入了统一方法入口`thread_native_entry`。新线程就每次都从`thread_native_entry`开始执行。

普通线程类只需要重写`run`方法就行了，但是`JavaThread`在此上又封装了一层，最终调用`entry_point`方法（通过`JavaThread`的构造函数传入）。对于Java代码的线程，传入的`entry_point`为`jvm.cpp::thread_entry`，里面使用`JavaCalls::call_virtual`调用对应的java代码。

线程的执行流程（即`thread_native_entry`的代码过程:
```
// Thread execution sequence and actions:
// All threads:
//  - thread_native_entry  // per-OS native entry point
//    - stack initialization
//    - other OS-level initialization (signal masks etc)
//    - handshake with creating thread (if not started suspended)
//    - this->call_run()  // common shared entry point
//      - shared common initialization
//      - this->pre_run()  // virtual per-thread-type initialization
//      - this->run()      // virtual per-thread-type "main" logic 具体做的操作
//        这里面是`JavaThread`的统一操作
//        - this->thread_main_inner()
//        - this->entry_point()  // set differently for each kind of JavaThread
//      - shared common tear-down
//      - this->post_run()  // virtual per-thread-type tear-down
//      - // 'this' no longer referenceable
//    - OS-level tear-down (minimal)
//    - final logging
```

## 虚拟线程(loom)
// TODO

## Linux线程调度
// TODO

