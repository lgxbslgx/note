### GC barrier

按barrier所在的位置划分
- 读barrier
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


### Serial GC 和 Parallel GC

- `写后barrier`，为了维护记忆集。
  - 把卡表对应位置置为`dirty`。
  - 具体代码在`CardTableBarrierSet::write_ref_field_post`。

相关代码在`BarrierSet`、`ModRefBarrierSet`、`CardTableBarrierSet`。


### G1 GC

- `读barrier`，为了标记被读的弱引用对象。
  - 每个弱引用的对象（弱可达）被读之后，会变成强可达，所以需要标记。
  - 只在并发标记的时候才需要该barrier，因为只有并发的情况，mutator才会修改引用。
  - 具体代码在`G1BarrierSet::AccessBarrier::oop_load_in_heap`、`G1BarrierSet::enqueue_preloaded_if_weak`。
- `写前barrier`，为了标记写前的对象。**也就是保留灰色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件2`。**
  - 把写前的对应对象指针放到队列（叫`satb mark queue`）中，然后让其他线程递归标记这些对象。
  - 具体代码在`G1BarrierSet::write_ref_field_pre`、`G1BarrierSet::enqueue`。
- `写后barrier`，为了维护记忆集。
  - 把对应对象指针放到队列（叫`dirty card queue`DCQ）中，然后让其他线程**根据该队列**把卡表对应位置置为`dirty`。
  - 具体代码在`G1BarrierSet::write_ref_field_post`、`G1BarrierSet::write_ref_field_post_slow`。

相关代码在`BarrierSet`、`ModRefBarrierSet`、`CardTableBarrierSet`、`G1BarrierSet`。


### 无分代ZGC

- `读barrier`，为了标记被读的对象（当然也包括弱引用对象）。
  - 每个对象被读之后，对其进行标记。**把白色对象置为灰色，也就等于删除黑色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件1`。**
  - 只在并发标记的时候才需要该barrier，因为只有并发的情况，mutator才会修改引用关系。
  - 具体代码在`XBarrierSet::AccessBarrier::oop_load_in_heap`、`XBarrierSet::AccessBarrier::load_barrier_on_oop_field_preloaded`。

相关代码在`BarrierSet`、`XBarrierSet`。


### 分代ZGC

- `读barrier`，为了标记被读的对象（当然也包括弱引用对象）。
  - 每个对象被读之后，对其进行标记。**把白色对象置为灰色，也就等于删除黑色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件1`。**
  - 只在并发标记的时候才需要该barrier，因为只有并发的情况，mutator才会修改引用关系。
  - 具体代码在`ZBarrierSet::AccessBarrier::oop_load_in_heap`、`ZBarrierSet::AccessBarrier::load_barrier`。
- `写前barrier`，为了标记对象和维护记忆集。
  - 如果对象需要保持活跃（这里具体的代码不太懂），则对其进行标记。**把白色对象置为灰色，也就等于删除黑色对象指向白色对象的边。破坏了上文提到的`并发收集失败的条件1`。**
  - 处理记忆集。
  - 具体代码在`ZBarrierSet::AccessBarrier::oop_store_in_heap`、`ZBarrierSet::store_barrier_on_heap_oop_field`、`ZBarrierSet::heap_store_slow_path`、`ZBarrier::remember`。


相关代码在`BarrierSet`、`ZBarrierSet`。

