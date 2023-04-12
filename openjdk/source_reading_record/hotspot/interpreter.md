## 解释器入口
- 虚拟机代码调用`JavaCalls::call*`，`JavaCalls::call*`调用`JavaCalls::call_helper`，
最终调用`StubRoutines::call_stub`执行Java代码。
- `JavaCalls::call*`是虚拟机调用Java代码的入口
- `StubRoutines::call_stub`可以说是解释器的入口，最终调用`Method::from_interpreted_entry`。

## Java代码调用native代码
- 通过intrinsic执行native代码
  - 一种intrinsic是直接修改方法入口，具体类型在`AbstractInterpreter::MethodKind和_entry_table`
  - 一种是通过普通的JNI接口，统一的方法入口，为``AbstractInterpreter::MethodKind::native*`
- 普通用户则通过JNI执行native代码

## Zero解释器（C++解释器）
JVM可能不支持一些平台，但是C/C++的编译器一般支持的平台很多，所以可以利用C++编译器的功能使得Java运行在更多平台。
C++解释器在需要特定平台代码的地方全部用C++代码实现，使得代码可以运行在一些未知平台。
**注意，它的基本框架和`模板解释器`是一样的，模板解释器需要在虚拟机启动的时候初始化一些存根（stub）代码和保存这些代码地址，C++解释器也要设置这些存根地址，只不过代码是C++写好的代码，不是汇编器生成的代码，所以保存对应的方法地址就行。**

## 模板解释器
虚拟机启动时生成对应的代码，并把代码对应的地址保存起来。
- 代码地址保存的位置主要在类`AbstractInterpreter`、`TemplateInterpreter`、`StubRoutines`等。
- 代码生成操作主要在类`TemplateInterpreterGenerator`、`TemplateTable`、`SharedRuntime`等。

具体路径:
- `AbstractICache::_flush_icache_stub`  刷新指令缓存（方法`ICacheStubGenerator::generate_icache_flush`）
- `VM_Version_StubGenerator::get_cpu_info_stub/detect_virt_stub`（方法`VM_Version_StubGenerator::generate_get_cpu_info/generate_detect_virt`）
- `vm_version_x86.cpp::getCPUIDBrandString_stub`（方法`VM_Version::initialize_tsc`）
- `StubRoutines::很多静态变量`，分阶段初始化（方法`StubRoutines::initialize_stubs -> StubGenerator::StubGenerator构造函数`）:
  - 详见`StubGenerator::generate_initial_stubs` 很多程序入口点，包括`call_stub`
  - 详见`StubGenerator::generate_continuation_stubs` Continuation stubs 和虚拟线程有关
  - 详见`StubGenerator::generate_compiler_stubs` 很多编译器相关的存根，用于编译代码生成（注意是在编译器线程内被调用）
  - 详见`StubGenerator::generate_final_stubs` barrier、数组拷贝等
- `SharedRuntime::很多静态变量` 解析函数调用、退优化等（方法`SharedRuntime::generate_stubs`）
- `AdapterHandlerLibrary::很多静态变量和_adapter_handler_table` i2c/c2i adapter适配器，根据参数个数和类型有不同的适配器（方法`AdapterHandlerLibrary::initialize`）
- `AbstractInterpreter和TemplateInterpreter的很多静态变量` 模板解释器的代码（方法`TemplateInterpreter::initialize_code -> TemplateTable::initialize`和`TemplateInterpreterGenerator构造函数`）


## 代码存放（CodeCache相关）

`CodeCache`: 描述整个运行时生成的代码区域，含有各种堆`CodeHeap`。
- 类似元空间的`VirtualSpaceList`，在代码区域外。
```
  static GrowableArray<CodeHeap*>* _heaps;
  static GrowableArray<CodeHeap*>* _compiled_heaps;
  static GrowableArray<CodeHeap*>* _nmethod_heaps;
  static GrowableArray<CodeHeap*>* _allocable_heaps;
```

`CodeHeap`: 描述某种类型代码的区域。
- 类似元空间的`VirtualSpaceNode`，在代码区域外。
- `CodeCache::initialize_heaps`向操作系统map一段连续的空间，然后分成三段（三个连续的空间`CodeHeap`）
  - `Profiled nmethods`（2、3级，带剖析信息的编译代码）
  - `Non-nmethods`（0级，未编译，即解释器等）
  - `Non-profiled nmethods`（1、4级，不带剖析信息的编译代码）
```
`CodeCache`
  VirtualSpace _memory; // 可用空间（已经committed）
  VirtualSpace _segmap; // 保留空间
  size_t       _next_segment; // 可用空间开始位置
  FreeBlock*   _freelist; // 空余块列表
```
```
整个堆
--------------------------------------------------------
 |HeapBlock CodeBlob 代码| |FreeBlock（里面有下一个块的地址）
--------------------------------------------------------
```

`FreeBlock`、`HeapBlock`管理`CodeHeap`的自由块。
  - 类似元空间的`block`，嵌入在代码区域内
  - 最小分配单元是`segment`(一般为128B)，一个`block`有多个`segment`。但是元空间的block最小分配单元是`word`（4或8字节）

`CodeBlob`: 描述一个方法在`CodeHeap`中的代码块。
  - 嵌入在代码区域内，跟在`HeapBlock`后面
```
CodeBlob继承层次
  CompiledMethod (compiledMethod.hpp)
    nmethod (nmethod.hpp)
  RuntimeBlob (codeBlob.hpp)
    BufferBlob (codeBlob.hpp) 非可重定向的代码，解释器、存根代码
      AdapterBlob (codeBlob.hpp)
      MethodHandlesAdapterBlob (codeBlob.hpp)
      VtableBlob (codeBlob.hpp)
    RuntimeStub (codeBlob.hpp)
    SingletonBlob (codeBlob.hpp)
      DeoptimizationBlob (codeBlob.hpp)
      ExceptionBlob (codeBlob.hpp)
      SafepointBlob (codeBlob.hpp)
      UncommonTrapBlob (codeBlob.hpp)
    UpcallStub (codeBlob.hpp)
```

`CodeBuffer`: `CodeBlob`在代码生成阶段的表示，传给汇编器使用。

## 具体代码（x86)

### 刷新指令缓存 `AbstractICache::_flush_icache_stub`
循环调用`clflush`命令(only `x86`)，注意其他架构可能不用实现该功能，只有一条`ret`指令

### VM调用Java方法（解释器入口）`StubRoutines::call_stub`
- 保存现场
  - rbp压栈，rsp直接跳到对应位置
  - 把寄存器的6个参数(rdi、rsi、rdx、rcx、r8、r9)压栈（都是mov指令，不是push，因为rsp已经不是当前栈顶，而是一个最终要到的位置。这是优化？）（方法后面的参数先压栈，注意和后面不同）
  - 保存callee需要保存的5个寄存器（rbx、r12、r13、r14、r15）
  - 保存mxcsr寄存器，设置mxcsr寄存器为新的值（不懂为什么设置）
  - 把线程`Thread`对象地址和堆基地址放入`r15`和`r12`
-调用Java方法
  - 判断当前线程是否有异常（Thread对象的`_pending_exception`字段）
  - **把Java方法的参数压栈（前面的参数先压栈，和前面C++的参数不同）**
  - **把方法`Method`的指针放到`rbx`，把`rsp`放在`r13`（也叫`rbcp`）**
  - 调用Java方法（`x86`的`call`指令，它会把`返回地址`压进栈），执行地址在`entry_point`（即`Method`的`from_interpreted_entry`）的代码。
  - 根据方法的结果类型，把`call`指令的结果（也就是`rax`或者`xmm0`）存到我们设置的结果地址
- 恢复现场，返回结果
  - 把rsp设置为Java方法调用前的地址
  - 验证线程是否正确，是否被污染（即`r15`和原来的参数内容相比较，看是否相同）
  - 恢复保存的5个寄存器（rbx、r12、r13、r14、r15）
  - 恢复mxcsr寄存器
  - 把rsp设置为`call_stub`调用前的位置
  - 设置rbp
  - `ret`返回

### Java方法入口点 `AbstractInterpreter::_entry_table`
也叫`i2i`入口。方法调用前，方法参数需要放在栈中（和JVM规范描述的一样），对应方法`Method`指针存放在`rbp`寄存器。`StubRoutines::call_stub`里面有这一步，用其他方式调用Java方法也要有这一步。

#### 普通方法入口（对应类型`MethodKind`为``zerolocals`、`zerolocals_synchronized`）
- 准备
  - 获取参数数量，本地变量数量
  - 检测是否栈溢出
  - 返回地址出栈，放到`rax`
  - 计算第一个参数在栈中的位置，放在`r14`
  ```
    // rax: reture address
    // rbx: Method*
    // rcx: size of parameters
    // rdx: size of locals
    // r13/rbcp: sender_sp 
    // r14: pointer to args/locals
    current stack:
    ---low---
    locals
    args
    ---high--
  ```

- 构建解释器帧（frame）
  - 返回地址`rax`进栈
  - `rbp`进栈，设置`rbp`为当前`esp`
  - `rbcp`进栈
  - 0进栈（`last sp`），主要是本地变量的栈槽（`push`一个`0`值进栈）
  - 设置`r13/rbcp`为字节码开始地址（`Method::_constMethod对象最后紧接着字节码`）
  - `rbx`（方法指针`Method*`）进栈
  - 取得该方法对应的`Klass`的mirror oop（即是Java中的Class对象），push进栈（注意压缩指针和load barrier）
  - 负责计数的method data pointer进栈
  - `Method::_constMethod`进栈
  - 常量池cache栈，注意不是常量池
  - 局部变量开始地址`r14`进栈
  - 字节码指针`r13/rbcp`进栈
  - 保留空间
  - `rsp`进栈
  ```
  // Layout of asm interpreter frame:
  //    [expression stack      ] * <- sp
  //    [monitor               ]   \
  //     ...                        | monitor blocks
  //    [monitor               ]   /
  //    [monitor top pointer   ]
  //    [byte code pointer     ]                   = bcp() (only for native calls) bcp_offset
  //    [pointer to locals     ]                   = locals()             locals_offset
  //    [constant pool cache   ]                   = cache()              cache_offset
  //    [methodData            ]                   = mdp()                mdx_offset
  //    [klass of method       ]                   = mirror()             mirror_offset
  //    [Method*               ]                   = method()             method_offset
  //    [last sp               ]                   = last_sp()            last_sp_offset
  //    [old stack pointer     ]                     (sender_sp)          sender_sp_offset
  //    [old frame pointer     ]   <- fp/bp           = link()
  //    [return pc             ]
  //    [oop temp              ]                     (only for native calls)
  //    [result handler        ]                     (only for native calls)
  //    [locals and parameters ]
  //                               <- sender sp
  ```
- 检测:  被调用方法不能是native方法或者抽象方法
- 设置`JavaThread::do_not_unlock_if_synchronized`为真
- 设置参数在`MethodData`对应的类型
- 递增方法计数器，可能是`MethodData`（`ProfileInterpreter`为真时）或者`MethodCounters`)。如果数量超过了通知阈值，则调用方法看是否需要编译。
- // TODO
- 同步方法则加锁（下文有具体内容）
- 执行方法（使用`dispatch_next`调用方法的第一个字节码）


#### native方法入口（对应类型`MethodKind`为``native`、`native_synchronized`）
- 准备和构建栈帧，和上面差不多。（注意这里不用分配本地变量的slots了）
- 检测:  被调用方法不能是`非native`方法或者抽象方法
- 设置`JavaThread::do_not_unlock_if_synchronized`为真。（和上面一样）
- 同步方法则加锁（下文有具体内容）
- **分配参数空间（因为是native方法，要遵循C++代码调用规范）** 
- 调用`InterpreterRuntime::prepare_native_call`找方法地址
  - 找到native方法入口
  - 根据方法签名找到（或者创建）签名处理器`Signature Handler`(注意这里不是`i2c/c2i adapter`，不过他们功能类似)
- 调用签名处理器`Signature Handler`，按照调用惯例，把一些参数放到寄存器，另一些放到栈（所以这里栈的内容有一部分重复了）
- 如果是静态方法，把mirror对象放进参数寄存器`c_rarg1（就是rsi）`
- 把`JNIEnv`放进参数寄存器`c_rarg0（就是rdi）`
- **调用native方法**
- // TODO
- `synchronized`方法结束要释放锁
- // TODO

### 典型的字节码
所有字节码模板都在`TemplateInterpreterGenerator::generate_and_dispatch`里面调用`dispatch_next`,
从而方法代码可以不断执行。

#### 加锁（`sychronized`方法、`monitorenter`字节码）`InterpreterMacroAssembler::lock_object`
对于`sychronized`方法，要根据方法是否`static`来获取要加锁的对象。
对于`monitorenter`指令，要加锁的对象已经在栈中（在`rax`中，因为栈顶缓存tos），无需自己找，不过要把操作数栈的内容都前移1位，留出对应的monitor entry位置。
- 把oop的markword放到寄存器`rax`
- 把`rax`最后一位 置为`1`
- 把`rax`放入monitor entry的markword位置
  ```
  ---low---
  monitor entry
    markword 随机值
    oop 要加锁的oop
  ---high--

  ---heap---
  oopDesc
    markword |其他|01|
    others
  ```
- 使用`cmpxchg`，比较`rax`与oop的`markword`是否相等（即oop的`markword`最后一位要为`1`），相等则把monitor entry的地址存到oop的`markword`中，加锁成功。（oop的`markword`指向栈上的`monitor entry`，`monitor entry`的`makrdown`存了oop原来的`markword`）
  ```
  ---low---
  monitor entry
    markword |其他|01| <--这里变了
    oop 要加锁的oop
  ---high--

  ---heap---
  oopDesc
    markword |monitor entry pointer|00| <--这里变了
    others
  ```
- 如果`cmpxchg`加锁失败，则判断该线程（一个page内）是否已经拿了这个锁，如果判断已经拿到，则返回，否则调用`InterpreterRuntime::monitorenter`方法（slow，慢路径）获取锁
- `InterpreterRuntime::monitorenter`方法 调用 `ObjectSynchronizer::enter`方法
  - 递增`JavaThread`的monitor计数
  - 如果配置不使用`heavy monitor`，则再次`compare and swap`，直接返回结果
  - 使用`heavy monitor`（默认使用），则循环下面操作，直到获取到锁
    - inflate 对象（`markword`先设置为全`0`，再设置为`|其他|10|`）
      - 获取一个`ObjectMonitor`，该`ObjectMonitor`也放在链表`ObjectSynchronizer::_in_use_list`。
      - 这时候oop的`markword`指向`ObjectMonitor`
      - `ObjectMonitor`的`markword`指向栈上的`monitor entry`（如果另一个线程已经解锁，则`ObjectMonitor`的`markword`存了oop原来的`markword`）
      - `monitor entry`的`makrdown`存了oop原来的`markword`。
    ```
    // The mark can be in one of the following states:
    // *  Inflated     - just return
    // *  Stack-locked - coerce it to inflated
    // *  INFLATING    - busy wait for conversion to complete
    // *  Neutral      - aggressively inflate the object.
    ```
    - `ObjectMonitor::enter`获取锁
      - 最终要把`ObjectMonitor::_owner`设置为当前线程

`MonitorDeflationThread`线程间隔一段时间就检查链表`ObjectSynchronizer::_in_use_list`，清除没用的`monitor`。

#### `new`字节码
- 通过`Method`里面的`ConstantPool`，获取对应的要分配对象的`InstanceKlass`，确保`InstanceKlass`已经初始化
- 先尝试在TLAB(线程本地分配buffer)里面分配
  - 分配成功则初始化:
    - 整个对象的值置为0
    - 初始化对象头，`markword`置为`|很多0|01|`，字段`Klass _metadata._klass`置为对应的klass
  - 如果TLAB分配不成功，则开始慢分配（调用C++方法`InterpreterRuntime::_new`）
    - 获取klass确保Klass已经初始化
    - 调用`InstanceKlass::allocate_instance`进行分配，里面调用`CollectedHeap::obj_allocate`，具体内容需要看具体的GC

#### `athrow`字节码
调用`Interpreter::throw_exception_entry`完成操作，
它由`TemplateInterpreterGenerator::generate_throw_exception`创建。
在`athrow`之前，对应异常对象一定在栈顶，因为栈顶缓存，所以它一定在`rax`。
- 验证异常（`StubRoutines::_verify_oop_subroutine_entry`，由`StubGenerator::generate_verify_oop`生成）。
- 清空表达式栈
- 调用`InterpreterRuntime::exception_handler_for_exception`查找异常对应的处理器
  - `Method::fast_exception_handler_bci_for`找到异常处理器则返回对应的bcp（字节码位置）
    - 判断异常的行号是否在范围内（start，end）
    - 判断异常的是否是对应的子类
    - 找到异常处理器则设置字节码位置，和返回对应的字节码入口
  - 找不到则返回`TemplateInterpreter::_remove_activation_entry`（负责弹出当前栈帧）
- 跳转到对应的入口执行代码

#### `TemplateTable::branch`方法
不是字节码，但是很多字节码模板都使用这个方法创建代码。
- 如果不使用回边计数器，则直接跳转
- 使用回边计数器，则
  - 递增回边计数器
  - 计数器每次到达定值，则调用`InterpreterRuntime::frequency_counter_overflow`处理 // TODO
  - 如果上一步返回一个已经编译的方法`nmethod`，则进行栈上替换（OSR）
  - 调用方法`SharedRuntime::OSR_migration_begin`
    - 打包一个`OSR buffer`，里面是该方法的`局部变量和monitors`
    - `OSR buffer`放在`rax`返回
    - 因为下一步要把解释器帧去掉，没了基地址`rbp`和`local var pointer`之后就找不到本地变量了，所以要打包。
  - `解释器帧`出栈，`OSR buffer`放到`j_rarg0`（也就是`rsi`）
  - 跳转到`nmethod::_osr_entry_point`继续执行代码（已编译的代码）
    - // TODO

#### `return`相关字节码
如果是`Object`的构造函数的`return`，它会被改写成`_return_register_finalizer`。
new一个对象时，会调用`Object`的构造函数，一定会执行`_return_register_finalizer`，其他时候都不会执行它。
- 如果是`_return_register_finalizer`（也就是new一个对象）
  - 则要查看类是否重写了`finalize`方法，重写了则要执行`InterpreterRuntime::register_finalizer`来注册对象
  - 最终调用java方法`Finalizer::register`来完成操作（放在Java类`Finalizer`的静态变量`queue`链表里面）。
- 如果不是`_return_register_finalizer`，判断是否允许线程本地安全点轮寻，是则轮寻 // TODO
- 解锁monitor（`synchronized`方法的、`synchronized`块的）`InterpreterMacroAssembler::remove_activation -> unlock_object`
  - `InterpreterMacroAssembler::unlock_object`
    - `InterpreterRuntime::monitorexit`
- 弹出当前栈
- 获取返回的入口地址，就是返回要调用的代码（不是直接返回）。具体可以看invoke指令


#### `getfield`和`getstatic`、`putfield`和`putstatic`字节码
都调用方法`TemplateTable::getfield_or_static`。
- 解析常量池条目，得到对应字段的运行时位置
  - 获取`constant pool cache`和获取对应的`index`
  - 获取`constant pool cache entry`里面的`indices`，得到里面的bytecode
  - 如果字节码和当前字节码不相等，说明该条目未解析，调用`InterpreterRuntime::resolve_from_cache`进行解析
    - 根据名称和类型签名在`InstanceKlass`里面的`_fieldinfo_stream`里面找
    - 在实现的接口里面找
    - 在父类里面找（解析方法的时候，是先在父类里面找，刚好相反）
  - 获取`constant pool cache`和获取对应的`index`（因为`InterpreterRuntime::resolve_from_cache`可能修改了对应的寄存器）
- 从`constant pool cache entry`获取字段在对象中的偏移量
- 获取或者设置字段值
  - 如果是`getfield`和`getstatic`，则使用`MacroAssembler::access_load_at`获取字段（里面需要用到对应GC的`read barrier`），把值放入栈中
  - 如果是`putfield`和`putstatic`，则使用`MacroAssembler::access_store_at`存储字段（用到对应GC的`write barrier`）。如果是`volatie`值，写之前要执行`store-load/store-store barrier`
- 把字节码改写成快速版本，因为之后不需要再解析常量池条目

#### `invoke`调用相关字节码
`invokehandle`详细内容在`invoke_handle.md`
`invokedynamic`详细内容在`invoke_dynamic.md`

`invokespecial`、`invokestatic`:
- `TemplateTable::prepare_invoke`获取`Method`地址
  - `invokehandle`的额外常数进栈
  - 获取`receiver`常数地址
  - 返回入口地址进栈。它在`TemplateInterpreter::_invoke_return_entry`等字段中，根据不同的方法调用类型，有不同的返回入口。
- 递增方法计数器
- 修改和参数有关的profile数据
- 跳转到方法入口`Method:_from_interpreted_entry`

`invokevirtual`:
如果是final方法，则流程和`invokespecial`、`invokestatic`一样。非final方法如下:
- `TemplateTable::prepare_invoke`获取`vtable index`（方法在虚方法表的位置）
- 获取`receiver`（也就是Java的`this`指针）对应的`Klass`。
- 递增方法计数器
- 在`Klass`中获取虚方法`Method`地址
- 修改和参数有关的profile数据
- 跳转到方法入口`Method:_from_interpreted_entry`

`invokeinterface`:
- `TemplateTable::prepare_invoke`获取`Method`地址
- // TODO

`invokehandle`:
流程和`invokespecial`、`invokestatic`差不多，但是具体内容有区别，详细内容在`invoke_handle.md`

`invokedynamic`:
第一步是`load_invokedynamic_entry`，而不是`TemplateTable::prepare_invoke`，其它和`invokespecial`、`invokestatic`差不多，详细内容在`invoke_handle.md`

