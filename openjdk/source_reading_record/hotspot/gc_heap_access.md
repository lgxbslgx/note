## 堆访问
本文记录**HotSpot中C++代码访问堆内存**的方法。
文档`gc_barrier.md`有C++代码实现的`GC barrier`（`XXXBarrierSet`、`XXXBarrierSet::AccessBarrier`），这些`GC barrier`会被这里`访问堆内存的代码`调用，具体关系看下文。

注意模板解释器、C1、C2生成的代码要访问堆内存，也会使用GC提供的相关barrier，
即`XXXBarrierSetAssembler`、`XXXBarrierSetC1`、`XXXBarrierSetC2`等，
本文不关心这些内容，它们的内容详见文档`gc_barrier.md`。


### 对外接口
对外接口在`Access`及其子类中:
- Access 包含了各种操作，操作详见下面`access.hpp`的注释。
  - 下面列出的子类都是使用`Access`的方法，只是传入的修饰符（decorators）不同。修饰符具体信息见下文。
  - RawAccess 原生访问，**不经过`GC barrier`**。垃圾收集器的代码中大量使用RawAccess。
  - HeapAccess 正常堆访问。runtime代码大量使用HeapAccess。
  - NativeAccess 在根（roots）中访问堆
  - NMethodAccess 在`code/nmethod`中访问堆
  - ArrayAccess 重写了数组相关操作

`Access`主要有读、写、原子写、数组复制等操作。`BarrierType`列出了操作类型。具体如下注释所示。
注意，下面的操作如果带`oop_`前缀，则表示要把操作数转成`oop`或`narrowOop`类型，再继续操作。

```c++
// 摘自`access.hpp`
// * load: Load a value from an address.
// * load_at: Load a value from an internal pointer relative to a base object.
// * store: Store a value at an address.
// * store_at: Store a value in an internal pointer relative to a base object.
// * atomic_cmpxchg: Atomically compare-and-swap a new value at an address if previous value matched the compared value.
// * atomic_cmpxchg_at: Atomically compare-and-swap a new value at an internal pointer address if previous value matched the compared value.
// * atomic_xchg: Atomically swap a new value at an address without checking the previous value.
// * atomic_xchg_at: Atomically swap a new value at an internal pointer address without checking the previous value.
// * arraycopy: Copy data from one heap array to another heap array. The ArrayAccess class has convenience functions for this.
// * clone: Clone the contents of an object to a newly allocated object.
```

修饰符（decorators）表示内存访问的类型，比如内存有序性、引用强度、barrier强度、访问发生的位置等。
详见代码`accessDecorators.hpp`。


### 接口用法
使用Access及其子类的方法，加上`修饰符`作为模板实参。例子:

```C++
// RawAccess in G1ScanClosureBase
obj->forwardee() == RawAccess<>::oop_load(p)

// HeapAccess in oop.cpp
oop oopDesc::obj_field_acquire(int offset) const { return HeapAccess<MO_ACQUIRE>::oop_load_at(as_oop(), offset); }

// NativeAccess in ClassLoaderData
NativeAccess<IS_DEST_UNINITIALIZED>::oop_store(handle, o);

// NMethodAccess in nmethod
return NMethodAccess<AS_NO_KEEPALIVE>::oop_load(oop_addr_at(index));

// ArrayAccess in ObjArrayKlass
ArrayAccess<ARRAYCOPY_DISJOINT>::oop_arraycopy(s, src_offset, d, dst_offset, length);
```


### 整体步骤
堆内存访问要经过下面的步骤:
- 设置对应的修饰符（decorators）和类型（decay type）
- 退化类型（Reduce types）
- 调用前: 检测调用是否可以避免（Pre-runtime dispatch）
- 具体的调用（Runtime-dispatch）
- 解析调用（Barrier resolution），第一次调用时要解析，之后不用。
- 调用后: 类型转换（Post-runtime dispatch）

```C++
// 摘自`access.hpp`
// == IMPLEMENTATION ==
// Each access goes through the following steps in a template pipeline.
// There are essentially 5 steps for each access:
// * Step 1:   Set default decorators and decay types. This step gets rid of CV qualifiers
//             and sets default decorators to sensible values.
// * Step 2:   Reduce types. This step makes sure there is only a single T type and not
//             multiple types. The P type of the address and T type of the value must
//             match.
// * Step 3:   Pre-runtime dispatch. This step checks whether a runtime call can be
//             avoided, and in that case avoids it (calling raw accesses or
//             primitive accesses in a build that does not require primitive GC barriers)
// * Step 4:   Runtime-dispatch. This step performs a runtime dispatch to the corresponding
//             BarrierSet::AccessBarrier accessor that attaches GC-required barriers
//             to the access.
// * Step 5.a: Barrier resolution. This step is invoked the first time a runtime-dispatch
//             happens for an access. The appropriate BarrierSet::AccessBarrier accessor
//             is resolved, then the function pointer is updated to that accessor for
//             future invocations.
// * Step 5.b: Post-runtime dispatch. This step now casts previously unknown types such
//             as the address type of an oop on the heap (is it oop* or narrowOop*) to
//             the appropriate type. It also splits sufficiently orthogonal accesses into
//             different functions, such as whether the access involves oops or primitives
//             and whether the access is performed on the heap or outside. Then the
//             appropriate BarrierSet::AccessBarrier is called to perform the access.
```


### 代码实现
最开始:
- 根据访问类型设置默认修饰符，再加上传入的修饰符。然后验证修饰符是否正确。`Access::verify_*`
- 根据访问类型转换参数或结果类型。
  - 参数类型在调用前设置
    - `Access::oop_store_at`开始时，`value`转换成`oop`类型
  - 结果类型在最后`return`语句自动类型转换。
    - `Access::load_at`返回的时候，`LoadAtProxy`转换成其他类型（调用`AccessInternal::load_at`）
    - `Access::oop_load_at`返回的时候，`OopLoadAtProxy`转换成`oop`类型

下面是官方给的步骤:
- 1. 设置对应的修饰符（decorators）和类型（decay type）
- 2. 退化类型（Reduce types）
  - 代码在`AccessInternal`命名空间。比如`AccessInternal::load_at`和`AccessInternal::load_at`
  - 使用`decay`和修饰符`decorators`来决定最终类型

- 3. 调用前: 检测是否需要`GC barrrier`（Pre-runtime dispatch）
  - 如果修饰符`decorators`包含`AS_RAW`，则**不需要**`GC barrier`
  - 如果修饰符`decorators`不包含`AS_RAW`，也不包含`INTERNAL_VALUE_IS_OOP`，则**不需要**`GC barrier`
  - 如果修饰符`decorators`不包含`AS_RAW`，包含`INTERNAL_VALUE_IS_OOP`，则**需要**`GC barrier`
  - **不需要`GC barrier`，则直接调用`RawAccessBarrier`的方法即可**
  - **需要`GC barrier`，则调用`RuntimeDispatch`的方法进行调用**

- 4. 具体调用（Runtime-dispatch）
  - 每个`RuntimeDispatch`都有一个类型为方法指针`func_t`的静态字段，它被初始化赋值为`RuntimeDispatch`中的初始化函数
    - 比如`BARRIER_LOAD`类型的`RuntimeDispatch`就会被初始化为`RuntimeDispatch`的`load_init`方法
    - 所以第一次调用`RuntimeDispatch`时，会调用对应的初始化方法（如`RuntimeDispatch::load_init`），也就是注释说的`5.a`步骤

  - 5.a barrier解析（Barrier resolution）主要是找对应GC相关的`XXXBarrierSet::AccessBarrier`
      - `RuntimeDispatch`的方法指针`func_t`运行，会调用`BarrierResolver::resolve_barrier`获取对应GC相关的`PostRuntimeDispatch`（对应GC也就是`BarrierSet`及其`AccessBarrier`）
      - 解析完成后，把刚刚获取到的`PostRuntimeDispatch`里面的访问方法 赋值给 `RuntimeDispatch`的方法指针
      - 之后调用`RuntimeDispatch`的方法指针`func_t`（也就是`5.b`）。之后每次调用都不需要在解析了，因为上一步已经修改对应的方法指针。

  - 5.b 调用（Post-runtime dispatch）
    - 调用`XXXBarrierSet::AccessBarrier`对应的函数进行具体的`barrier`操作，和具体的GC有关。详见文档`gc_barrier.md`。
    - 注意`XXXBarrierSet::AccessBarrier`的方法有一步是调用`RawAccessBarrier`的方法来完成具体的操作，`RawAccessBarrier`操作的前后就是`GC barrier`的内容。`RawAccessBarrier`里面有压缩指针的编码（转换正常地址为压缩指针）、解码操作（转换压缩指针为正常地址）。


相关代码在:
- Access及其子类、AccessInternal
- PostRuntimeDispatch、RuntimeDispatch、PreRuntimeDispatch、BarrierResolver
- HeapOopType、BarrierType、AccessFunctionTypes、AccessFunction、RawAccessBarrier
- DecoratorSet
- XXXBarrierSet、XXXBarrierSet::AccessBarrier
- Atomic

