## GC barrier

### 分类
按barrier所在的位置划分
- 读barrier
  - `load barrier`: 对于语句`var x = obj.field`, the barrier is invoked on `field`, ensuring only “clean” pointers live on the stack。比如《The Garbage Collection Handbook》的`Algorithm 15.2`的`(a) Baker [1978] barrier`。
  - `use barrier`: 对于语句`var x = obj.field`, the barrier is invoked on `obj`, ensuring pointers are “cleaned” before using (dereferencing)。比如《The Garbage Collection Handbook》的`Algorithm 15.2`的`(b) Appel et al [1988] barrier`。
  - 也可以按`读前barrier`和`读后barrier`进行分类
- 写前barrier
- 写后barrier


### 并发收集失败的条件

- 黑色对象，对象被标记（没被扫描）并且**所有**字段都被遍历
- 灰色对象，对象被标记（没被扫描）但是**有些**字段没被遍历
- 白色对象，对象没被标记（没被扫描）

并发收集失败的条件
- 添加**一条**黑色对象指向白色对象的边
- 删除**所有**灰色对象指向**该**白色对象的边（路径）

要并发收集成功，只要破坏其中一个条件即可。


### HotSpot中barrier代码的位置

[GC统一接口的资料](https://openjdk.org/jeps/304)

简单描述:
- `BarrierSet`及其子类用C++实现barrier，主要给`BarrierSet::AccessBarrier`使用。
- `BarrierSet::AccessBarrier`及其子类使用`BarrierSet`的方法实现了C++版本的barrier，给runtime代码使用。
  - 所有C++代码需要访问堆的都要经过`BarrierSet::AccessBarrier`。详见[gc_heap_access.md](/openjdk/source_reading_record/hotspot/gc_heap_access.md)。
- `BarrierSetAssembler`的子类实现了`GC barrier`的汇编器，给模板解释器使用。C1、C2也可能使用它。
- `BarrierSetC1`的子类实现了C1的barrier
- `BarrierSetC2`的子类实现了C2的barrier
- `XXXBarrierSetRuntime`相关的类实现了barrier的runtime库。模板解释器、C1、C2（上面三个）会复用这里的代码。
  - 注意如果某个GC的barrier代码逻辑简单，就不用写这样一个runtime库了，直接在自己的类中写就行。
  - 如果虚拟机C++代码（`BarrierSet`、`BarrierSet::AccessBarrier`）和`模板解释器、C1、C2`的barrier代码逻辑复杂，很多相同的代码可以提取出来进行复用。
    - 比如`ZBarrier`作为公共代码，被`ZBarrierSet`和`ZBarrierSetRuntime`使用。
    - `ZBarrierSetRuntime`又被`ZBarrierSetAssembler`、`ZBarrierSetC1`、`ZBarrierSetC2`使用。


### Serial GC 和 Parallel GC

- `写后barrier`，为了维护记忆集。
  - 把卡表对应位置置为`dirty`。
  - 具体代码
    - C++代码 `ModRefBarrierSet::AccessBarrier::oop_store_in_heap`、`CardTableBarrierSet::write_ref_field_post`
    - 模板解释器 `ModRefBarrierSetAssembler::store_at`、`CardTableBarrierSetAssembler::oop_store_at`
    - C1 `CardTableBarrierSetC1::post_barrier`
    - C2 `CardTableBarrierSetC2::post_barrier`

相关代码（主要是每项的第一个，后面的一般是它的父类）
- C++代码 `CardTableBarrierSet`、`ModRefBarrierSet`、`BarrierSet`、
- 模板解释器 `CardTableBarrierSetAssembler`、`ModRefBarrierSetAssembler`、`BarrierSetAssembler`
- C1 `CardTableBarrierSetC1`、`ModRefBarrierSetC1`、`BarrierSetC1`
- C2 `CardTableBarrierSetC2`、`ModRefBarrierSetC2`、`BarrierSetC2`


### CMS
// TODO


### G1 GC

- `读barrier`，为了标记被读的**弱引用对象**。
  - 每个弱引用的对象（弱可达）被读之后，会变成强可达，所以需要标记。
  - 这些需要改变的弱引用的对象具体为: 它的`DecoratorSet`的`ON_STRONG_OOP_REF`为0（即非强可达），`AS_NO_KEEPALIVE`为`0`（即可以存活）。
  - 具体代码
    - C++代码 `G1BarrierSet::AccessBarrier::oop_load_in_heap`、`G1BarrierSet::enqueue_preloaded_if_weak`、`G1BarrierSet::enqueue_preloaded`
    - 模板解释器 `G1BarrierSetAssembler::load_at`、`G1BarrierSetAssembler::g1_write_barrier_pre`
    - C1 `G1BarrierSetC1::load_at_resolved`、`G1BarrierSetC1::pre_barrier`
    - C2 `G1BarrierSetC2::load_at_resolved`、`G1BarrierSetC2::pre_barrier`

- `写前barrier`，为了标记写前的对象。**也就是保留灰色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件2`。**
  - 把写前的对应对象指针放到队列（叫`satb mark queue`）中，然后让其他线程递归标记这些对象。
  - 具体代码
    - C++代码 `G1BarrierSet::AccessBarrier::oop_store_in_heap`、`G1BarrierSet::write_ref_field_pre`、`G1BarrierSet::enqueue`
    - 模板解释器 `ModRefBarrierSetAssembler::store_at`、`G1BarrierSetAssembler::oop_store_at`、`G1BarrierSetAssembler::g1_write_barrier_pre`
    - C1 `G1BarrierSetC1::pre_barrier`
    - C2 `G1BarrierSetC2::pre_barrier`

- `写后barrier`，为了维护记忆集。
  - 把对应对象指针放到队列（叫`dirty card queue`DCQ）中，然后让GC线程**根据该队列**把卡表对应位置置为`dirty`。
  - 具体代码
    - C++代码 `G1BarrierSet::AccessBarrier::oop_store_in_heap`、`G1BarrierSet::write_ref_field_post`、`G1BarrierSet::write_ref_field_post_slow`
    - 模板解释器 `ModRefBarrierSetAssembler::store_at`、`G1BarrierSetAssembler::oop_store_at`、`G1BarrierSetAssembler::g1_write_barrier_post`
    - C1 `G1BarrierSetC1::post_barrier`
    - C2 `G1BarrierSetC2::post_barrier`

相关代码（主要是每项的第一个，后面的一般是它的父类）
- C++代码 `G1BarrierSet`、`CardTableBarrierSet`、`ModRefBarrierSet`、`BarrierSet`、
- 模板解释器 `G1BarrierSetAssembler`、`ModRefBarrierSetAssembler`、`BarrierSetAssembler`
- C1 `G1BarrierSetC1`、`ModRefBarrierSetC1`、`BarrierSetC1`
- C2 `G1BarrierSetC2`、`ModRefBarrierSetC2`、`BarrierSetC2`
- runtime库 `G1BarrierSetRuntime`


### 无分代ZGC
并发标记`mark`时用递增更新（increment update）的读barrier，和G1不同。在读barrier中完成标记操作(gc线程也在标记)。
并发转移`relocate`时使用`tospace invariant`，保证没有`tospace`指向`fromspace`的指针，也是在读barrier中完成（gc线程也在转移）。

- `读barrier`，为了标记`mark`、转移`reloate`被读的对象、remap对象指针
  - 并发标志阶段，每个对象被读之后，如果其`DecoratorSet`的`AS_NO_KEEPALIVE`为`0`，则对其进行标记。**把白色对象置为灰色，破坏了上文提到的`并发收集失败的条件1`。**
    - 注意: 这里不管`ON_STRONG_OOP_REF`是否为0（即非强可达），都需要标记。和G1不一样，相当于G1的`写前barrier`和`读barrier`合并在一起了。
  - 转移阶段，转移被保护的区域`fromspace`的对象。转移阶段，转移对象成功后，remap指针。
  - 并发标记和remap阶段，remap上一次GC的指针
  - 这些需要改变的弱引用的对象具体为: 它的`DecoratorSet`的`ON_STRONG_OOP_REF`为0（即非强可达），`AS_NO_KEEPALIVE`为`0`（即可以存活）。
  - 具体代码
    - C++代码 `XBarrierSet::AccessBarrier::oop_load_in_heap`、`XBarrierSet::AccessBarrier::load_barrier_on_oop_field_preloaded`
    - 模板解释器 `XBarrierSetAssembler::load_at`
    - C1 `XBarrierSetC1::load_at_resolved`、`XBarrierSetC1::load_barrier`
    - C2 `XBarrierSetC2::load_at_resolved`

相关代码（主要是每项的第一个，后面的一般是它的父类）
- C++代码 `XBarrierSet`、`BarrierSet`
- 模板解释器 `XBarrierSetAssembler`、`XBarrierSetAssemblerBase`、`BarrierSetAssembler`
- C1 `XBarrierSetC1`、`BarrierSetC1`
- C2 `XBarrierSetC2`、`BarrierSetC2`
- runtime库 `XBarrierSetRuntime`、`XBarrier`


### 分代ZGC
并发标记`mark`时使用SATB的写barrier，和G1相同。在写barrier中完成标记操作(gc线程也在标记)。
并发转移`relocate`时使用`tospace invariant`，保证没有`tospace`指向`fromspace`的指针，无分代ZGC一样。在读barrier中完成操作(gc线程也在转移对象)。

- `读barrier`，转移`relocate`对象、映射`remap`指针、标记被读的**弱引用对象**
  - 转换着色指针为无着色地址
  - 并发标记阶段，每个弱引用的对象（弱可达）被读之后，会变成强可达，所以需要标记。这些需要改变的弱引用的对象具体为: 
    - `DecoratorSet`的`ON_STRONG_OOP_REF`为0（即非强可达，也就是`ON_WEAK_OOP_REF`或者`ON_PHANTOM_OOP_REF`为1）
    - `AS_NO_KEEPALIVE`为`0`（即可以存活）。这里和G1一样，和无分代ZGC不一样。
  - 下一次并发标记阶段，remap上一次GC的指针。
  - 并发转移阶段，转移relocate被保护的区域`from space`的对象
  - 并发转移阶段，转移对象成功后，remap指针。
  - 具体代码
    - C++代码 `ZBarrierSet::AccessBarrier::oop_load_in_heap`、`ZBarrierSet::AccessBarrier::load_barrier`
    - 模板解释器 `ZBarrierSetAssembler::load_at`
    - C1 `ZBarrierSetC1::load_at_resolved`、`ZBarrierSetC1::load_barrier`
    - C2 `ZBarrierSetC2::load_at_resolved`

- `写前barrier`，为了标记写前的对象和维护记忆集。
  - 转换无着色地址为着色指针
  - 标记写前的对象。**也就是保留灰色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件2`。**
    - 把写前的对象放到`ZStoreBarrierBuffer`中，让GC线程进行标记。`ZStoreBarrierBuffer::add`
    - `ZStoreBarrierBuffer`不存在时，mutator线程直接处理。`ZBarrier::mark`
  - 处理记忆集
    - 把对应对象指针放到`ZStoreBarrierBuffer`中，让GC线程修改记忆集。`ZStoreBarrierBuffer::add`
    - `ZStoreBarrierBuffer`不存在时，mutator线程直接处理。 `ZBarrier::remember`
  - 具体代码
    - C++代码 `ZBarrierSet::AccessBarrier::oop_store_in_heap`、`ZBarrierSet::AccessBarrier::store_barrier_heap_without_healing`、`ZBarrier::store_barrier_on_heap_oop_fiel`、`ZBarrier::heap_store_slow_path`
    - 模板解释器 `ZBarrierSetAssembler::store_at`
    - C1 `ZBarrierSetC1::store_at_resolved`、`XBarrierSetC1::store_barrier`
    - C2 `ZBarrierSetC2::store_at_resolved`

相关代码（主要是每项的第一个，后面的一般是它的父类）
- C++代码 `ZBarrierSet`、`BarrierSet`
- 模板解释器 `XBarrierSetAssembler`、`ZBarrierSetAssemblerBase`、`BarrierSetAssembler`
- C1 `ZBarrierSetC1`、`BarrierSetC1`
- C2 `ZBarrierSetC2`、`BarrierSetC2`
- runtime库 `ZBarrierSetRuntime`、`ZBarrier`


### Shenandoah
// TODO


### Jade

下文的copy、标记、修改记忆集/`CRDT`等操作，可能由mutator线程完成，也可能把相关信息放到一个中转位置，由GC线程完成。

- `读barrier`
  - 判断当前是否正在GC，正在GC则：
    - 根据对象头的对应bit，判断对象是否已经被拷贝。如果对象已经拷贝，则修改当前指针（self heal）
    - 年轻代并发copy阶段 或者 老年代并发标记阶段，弱引用的对象被读（且`AS_NO_KEEPALIVE`为`0`），会变成强可达，这时需要copy或标记该弱引用对象。

- `写barrier`
  - 判断当前是否正在GC，正在GC则：
    - 年轻代并发copy阶段 或者 老年代并发标记阶段，copy或标记写前的对象（**SATB**）
    - 根据对象头的对应bit，判断对象是否已经被拷贝。如果对象已经拷贝，则修改当前指针（self heal）
      - 虽然写操作之前有一个读操作（会执行`读barrier`），但是在**读和写**中间，可能对象被拷贝，所以还是要进行self heal判断。
    - 老年代并发标记阶段，遇到跨区域指针，则要修改`CRDT`（`CRDT`实际上只能增加一项，不能删除，因为没有记录`point-out`指针数量）
  - 不管是否正在GC，遇到老年代对象，要修改`old-to-young`记忆集


### 一些注意事项
- 非堆的OOP读写（比如`OopHandle`）有可能会有特殊操作，目前的GC中
  - 非堆的读（比如`IN_NATIVE`）和堆内读（`IN_HEAP`）的barrier一样
  - 非堆的写（比如`IN_NATIVE`）与堆内写（`IN_HEAP`）的barrier相比，少了维护记忆集的工作。其他操作，比如标记操作，则完全相同。

