`Reference引用`相关内容

## 相关资料
- 论文《Deep Dive into ZGC: A Modern Garbage Collector in OpenJDK》 Section 4、5
- 论文《Reference Object Processing in On-The-Fly Garbage Collection》

## Reference类别

- Reference 抽象类，不能被实例化
  - SoftReference 软引用，内存不够用才被回收，一般用作cache（`SoftReference`比`WeakReference`更难清除，详见下文`ReferenceProcessor::discover_reference`）
  - WeakReference 弱引用，，一般用作规范映射（`canonicalizing mapping`，比如`WeakHashMap`）
  - PhantomReference 虚（虚幻）引用，一创建就直接被去除（不是被虚拟机清除，只是`get`方法直接返回`null`），用于调用后置的清理操作（所以构造函数一定要有参数`ReferenceQueue`）
  - FinalReference
    - Finalizer 为了实现重写`finalize`方法的类。包私有，也就是不能被开发者自己创建。

那些不是继承`Reference及其子类`的对象，都叫强引用。


## Reference状态

`Reference`类有2类状态、4个字段，每一类状态决定2个字段的值。状态相关信息不懂也可以，因为虚拟机代码没有这些状态，`Reference`相关类代码也没有这些状态，只有注释有。
只需要弄懂4个字段是怎么被虚拟机、`ReferenceHandler`线程、`FinalizerThread`线程 处理的就行。

4个字段：
- `referent`: 表示引用的对象
- `discovered`: 表示`GC已发现（将要清理）列表 discovered reference list`（对应`hotspot`的`DiscoveredList`）的下一个元素、引用等待列表`pending-Reference list`（对应`hotspot`的`Universe::_reference_pending_list`）的下一个元素
- `queue`: 引用所在的队列`ReferenceQueue`、`ReferenceQueue::ENQUEUED`、`ReferenceQueue::NULL`
- `next`: 引用所在的队列`ReferenceQueue`的下一个元素或者为该引用（即当前引用，当`queue`只有一个元素时）

第一类状态为`Active`、`Pending`、`Inactive`，决定了字段`referent`、`discovered`的值:
- `Active` 引用新建时的状态
  - 对应`referent`不为空，为引用的对象
  - 对应`discovered`为空或者`GC已发现（将要清理）队列`的下一个元素
- `Pending` 表示被GC清理后（如果GC未完成，这里就是指对象不被标记，准备清理），引用在等待引用队列`pending-Reference list`（对应`hotspot`的`Universe::_reference_pending_list`），等待被引用处理器`ReferenceHandler`处理
  - 对应`referent`为空
  - 对应`discovered`为等待引用列表（`pending-Reference list`）（对应`hotspot`的`Universe::_reference_pending_list`）的下一个元素
- `Inactive` 已被引用处理器`ReferenceHandler`处理
  - 对应`referent`为空
  - 对应`discovered`为空

第二类状态为`registered`、`enqueued`、`dequeued`、`unregistered`
- `registered` 新建引用时，如果传入`引用队列`不为空，则为`registered`状态
  - 对应`queue`为构造函数传入的`引用队列`
  - 对应`next`为空
- `enqueued` 被引用处理器处理后的状态，表示引用现在在`传入的引用队列中`
  - 对应`queue`为`ReferenceQueue.ENQUEUE`
  - 对应`next`为所进入队列的下一个元素
- `dequeued` 表示引用现在已经从`传入的引用队列中`删除
  - 对应`queue`为`ReferenceQueue.NULL`
  - 对应`next`为当前引用
- `unregistered` 新建引用时，如果没有传入`引用队列`（或者说`引用队列`传入为空），则为`unregistered`状态
  - 对应`queue`为`ReferenceQueue.NULL`
  - 对应`next`为空

开始状态 `active/registered`、`active/unregistered`
终止状态 `inactive/dequeued`、`inactive/unregistered`
不可能状态: `active/enqueued`、`active/dequeued`

图示（摘抄自`Reference`类的注释）:
```
     * Initial states:
     *   [active/registered]
     *   [active/unregistered] [1]
     *
     * Transitions:
     *                            clear [2]
     *   [active/registered]     ------->   [inactive/registered]
     *          |                                 |
     *          |                                 | enqueue
     *          | GC              enqueue [2]     |
     *          |                -----------------|
     *          |                                 |
     *          v                                 |
     *   [pending/registered]    ---              v
     *          |                   | ReferenceHandler
     *          | enqueue [2]       |--->   [inactive/enqueued]
     *          v                   |             |
     *   [pending/enqueued]      ---              |
     *          |                                 | poll/remove
     *          | poll/remove                     | + clear [4]
     *          |                                 |
     *          v            ReferenceHandler     v
     *   [pending/dequeued]      ------>    [inactive/dequeued]
     *
     *
     *                           clear/enqueue/GC [3]
     *   [active/unregistered]   ------
     *          |                      |
     *          | GC                   |
     *          |                      |--> [inactive/unregistered]
     *          v                      |
     *   [pending/unregistered]  ------
     *                           ReferenceHandler
     *
     * Terminal states:
     *   [inactive/dequeued]
     *   [inactive/unregistered]
     *
     * Unreachable states (because enqueue also clears):
     *   [active/enqueued]
     *   [active/dequeued]
     *
```

## 使用例子

```java
import java.lang.ref.*;

public class ReferenceTest {

  public static void main(String[] args) {
    test();
    System.gc();
  }

  public static void test() {
    ReferenceQueue<String> queue = new ReferenceQueue<>();
    SoftReference<String> sr1 = new SoftReference<>("SoftReference");
    SoftReference<String> sr2 = new SoftReference<>("SoftReference_with_queue", queue);
    WeakReference<String> wr1 = new WeakReference<>("WeakReference");
    WeakReference<String> wr2 = new WeakReference<>("WeakReference_with_queue", queue);
    PhantomReference<String> pr = new PhantomReference<>("PhantomReference_must_with_queue", queue);
    ReferenceTest test = new ReferenceTest();
    System.out.println(queue);
    System.gc();
  }

  @Override
  protected void finalize() throws Throwable {
    System.out.println("ReferenceTest.finalize");
  }
}
```

## hotspot实现

### 类加载阶段
`InstanceKlass::allocate_instance_klass`会判断该类是否是`Reference`的子类，如果是，则**新建`InstanceRefKlass`**，而不是`InstanceKlass`。`InstanceRefKlass`会重写大部分oop遍历方法`oop_oop_iterate*`，在垃圾收集的时候有一些特殊处理（详见下文）。

`Rewriter::rewrite_bytecodes`重写`Object类`的构造函数的`_return`为`_return_register_finalizer`，为了之后初始化`finalize`方法。

**如果一个类重写了`finalize`方法，且`finalize`非空**，`新建对象`时，会调用`Object`的构造函数，也就是会执行字节码`_return_register_finalizer`（代码在`TemplateTable::_return`）。然后会调用`InterpreterRuntime::register_finalizer`来注册该对象。具体操作是调用java方法`java.lang.ref.Finalizer::register`新建一个`Finalizer`引用对象（该引用对象引用刚刚创建的对象），把`Finalizer::queue`传给该对象，把该对象放到队列`Finalizer::unfinalized`中。


### 垃圾收集阶段
相关的类有:
- `ReferencePolicy及其子类`，里面的方法`should_clear_reference`用于判断引用是否被应该`发现`，**注意: 发现引用就意味着将要被清理（除了`Finalizer`）**
- `ReferenceProcessorPhaseTimes` 一些计时、计数、统计信息
- `ReferenceProcessorStats` 引用数量汇总信息
- `ReferenceDiscoverer及其子类` 引用处理具体操作

引用处理具体操作在`ReferenceDiscoverer及其子类`。对应的类继承关系如下所示。我们现在主要关心`ReferenceProcessor`，`zgc`和`shenandoah`相关内容后面再看。

```
ReferenceDiscoverer (referenceDiscoverer.hpp)
  ReferenceProcessor (referenceProcessor.hpp) serial、parallel、G1共用的处理器
  ShenandoahIgnoreReferenceDiscoverer (shenandoahVerifier.cpp)
  ShenandoahReferenceProcessor (shenandoahReferenceProcessor.hpp)
  XReferenceProcessor (xReferenceProcessor.hpp)
  ZReferenceProcessor (zReferenceProcessor.hpp)
```

#### 引用发现（就是找出要清理的引用）
垃圾收集扫描堆时，会调用`InstanceKlass`对应的方法`oop_oop_iterate*`.如果是`InstanceKlass`的子类`InstanceRefKlass`，则有自己的`oop_oop_iterate*`。

这些`InstanceRefKlass::oop_oop_iterate*`会先调用父类`InstanceKlass`对应的`oop_oop_iterate*`，再调用`oop_oop_iterate_ref_processing`进行引用处理。

`oop_oop_iterate_ref_processing`会根据传入的`closure`类型（具体类型在`OopIterateClosure::ReferenceIterationMode`）调用方法`oop_oop_iterate_discovery`、`oop_oop_iterate_discovered_and_discovery`、`oop_oop_iterate_fields`、`oop_oop_iterate_fields_except_referent`进行处理。这4个方法会调用`do_referent`、`do_discovered`、`try_discover`进行特殊操作。

- `closure`类型为`OopIterateClosure::DO_DISCOVERY`时，会调用`oop_oop_iterate_discovery`:
  - 调用`try_discover`
    - 先获取该引用里面的`referent`对象（也就是引用的具体对象），判断其是否被标记，也就是它是否被强引用
    - 如果`referent`对象没被标记（没被强引用），则调用`ReferenceProcessor::discover_reference`尝试发现引用（**注意: 发现引用就意味着将要被清理**）。发现引用则直接返回。
  - 如果上一步`try_discover`没发现引用，说明该引用不符合清理`clear`规则，可以继续保留。则调用`do_referent`、`do_discovered`，把该引用当作正常对象处理，把`closure`应用到该对象。

- `closure`类型为`OopIterateClosure::DO_DISCOVERED_AND_DISCOVERY`时，会调用`oop_oop_iterate_discovered_and_discovery`:
  - 调用`do_discovered`
  - 再调用`oop_oop_iterate_discovery`，具体操作和上面一样
    - 调用`try_discover`
    - 调用`do_referent`
    - 调用`do_discovered`

- `closure`类型为`OopIterateClosure::DO_FIELDS`时，会调用`oop_oop_iterate_fields`:
  - 调用`do_referent`
  - 调用`do_discovered`

- `closure`类型为`OopIterateClosure::DO_FIELDS_EXCEPT_REFERENT`时，会调用`oop_oop_iterate_fields_except_referent`:
  - 只调用`do_discovered`

`try_discover`:
- 先获取该引用里面的`referent`对象（也就是引用的具体对象），判断其是否被标记，也就是它是否被强引用
- 如果`referent`对象没被标记（没被强引用），则调用`ReferenceProcessor::discover_reference`尝试发现引用（**注意: 发现引用就意味着将要被清理**）。发现引用则直接返回。

`do_referent`:
取该引用的`relerect`字段（就是所引用的对象），使用`closure`处理该对象，例如递归标记对象等。

`do_discovered`
取该引用的`discovered`字段，使用`closure`处理该对象，例如递归标记对象等。

`ReferenceProcessor::discover_reference`：
进行一系列的排除操作（排除一些情况，即一些情况下，不用发现、清理该引用），最后把不能排除的引用（即被发现的、要清理的引用）加到对应列表`DiscoveredList`中（代码在`ReferenceProcessor::add_to_discovered_list`）。每一种引用类型、每一个`WorkThread`都有对应的队列。详见`ReferenceProcessor`的字段:
```
// ReferenceProcessor类
  DiscoveredList* _discoveredSoftRefs;
  DiscoveredList* _discoveredWeakRefs;
  DiscoveredList* _discoveredFinalRefs;
  DiscoveredList* _discoveredPhantomRefs;
```

如果是软引用`SoftReference`，`ReferenceProcessor::discover_reference`中要比较 `最近一次引用处理`的时间`ReferenceProcessor::_soft_ref_timestamp_clock、SoftReference::clock`
和最近一次`调用get方法`的时间`SoftReference::timestamp`的差 是否大于 `_max_interval`（`_max_interval`由堆空间决定，详见`ReferencePolicy及其子类`）。

`ReferenceProcessor::add_to_discovered_list`:
- 设置该引用的字段`discoverd`为`DiscoveredList`列表的表头节点。
- 把该引用加到`DiscoveredList`列表中


#### 引用处理（`hotspot`对上一步找出的引用进行处理）
代码在`ReferenceProcessor::process_discovered_references`。
- 整个过程都需要设置一些统计信息到`ReferenceProcessorPhaseTimes`
- 处理软引用`SoftReference`、弱引用`WeakReference`、`Finalizer`引用（`SoftWeakFinalRefsPhase`）
  - 并行处理时，平衡各个队列
  - 处理软引用`SoftReference`，对应阶段`ProcessSoftRefSubPhase`
  - 处理弱引用`WeakReference`，对应阶段`ProcessWeakRefSubPhase`
  - 处理`Finalizer`引用，对应阶段`ProcessFinalRefSubPhase`
  - 具体代码在`RefProcProxyTask及其子类`、`RefProcTask及其子类`、`ReferenceProcessor::process_discovered_list(_work)`、`DiscoveredListIterator`。所有引用类型都有下面具体操作:
    - 如果引用对象不存活:
      - **清理**`Refenrence::referent`字段（把它置为空）
      - 把引用放到前一个不存活引用的`discoverd`字段，也就是放到引用等待列表（`pending-Reference list`）。
      - 遍历下一个引用
      - 最后**调用`DiscoveredListIterator::complete_enqueue`把该引用队列放到`Universe::_reference_pending_list`，给`ReferenceHandler`线程使用**
    - 如果引用对象还存活（对象被其他地方强引用）:
      - 把该引用从引用队列中`DiscoveredList`删除，代码在`DiscoveredListIterator::remove`（注意这里的删除不是清理`Refenrence::referent`字段）
      - 标记该对象为存活对象，比如设置markword为`|其他|11`（前面`引用不存活`的情况没有这一步，所以对象就会被回收）
      - 遍历下一个引用
- 处理final引用`Finalizer`（`KeepAliveFinalRefsPhase`）因为后面`FinalizerThread`要调用对象的`finalize`方法，所以还不能清除`Finalizer`引用的对象。
  - 把上一步所有的`Finalizer`引用的对象标记为存活，放到`next`字段和`discovered`字段中，为了后面再次处理。
  - 具体代码在`RefProcProxyTask及其子类`、`RefProcTask及其子类`、`ReferenceProcessor::process_final_keep_alive_work`、`DiscoveredListIterator`。
- 处理虚引用`PhantomReference`（`PhantomRefsPhase`）具体操作和上面 软引用`SoftReference`、弱引用`WeakReference`、`Finalizer`引用差不多。
  - 因为`虚引用`弱于`final引用`，所以上一步对final引用的对象及其后继（传递闭包）重新标记为存活之后，对应的`虚引用`对象也会被标记成存活，所以`虚引用`要在最后处理。
  - ZGC中`虚引用`和其他引用一起处理，不用最后单独处理，因为ZGC的`标记阶段`会识别出**正常存活的对象**和**因finalizable存活的对象**，所以引用处理阶段无需特殊处理。详见`XReferenceProcessor`和`ZReferenceProcessor`。
- 设置引用数量汇总信息到`ReferenceProcessorStats`并返回


## `ReferenceHandler`线程对引用进行处理
`hotspot`会把引用队列放到`Universe::_reference_pending_list`，给`ReferenceHandler`线程使用。
`ReferenceHandler`线程把队列所有引用的`discovered`字段置为空，`next`字段置为上一个入队的值，`queue`字段置为`ENQUEUED`，也就是把所有引用加入到`引用创建时传入的队列`中（`原来的queue值`）。
具体操作在java代码`Reference::ReferenceHandler::run`和`Reference::processPendingReferences`。


## `FinalizerThread`线程对`Finalizer`引用进行处理
`hotspot`会把引用队列放到`Universe::_reference_pending_list`，给`ReferenceHandler`线程使用。`ReferenceHandler`线程会把引用加入到引用创建时传入的队列中（`原来的queue值`）。而`Finalizer`类传入的队列`queue`为固定的`Finalizer::queue`。

`FinalizerThread`线程则会对`Finalizer::queue`的引用进行操作（`Finalizer::FinalizerThread::run`和`Finalizer::runFinalizer`）。把对象从队列中取出来，调用它的`finalize`方法。下一次GC的时候对应的`Finalizer`引用就不可达，该引用和引用的对象都会被清除。

