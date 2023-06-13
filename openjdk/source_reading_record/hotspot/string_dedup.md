本文描述`字符串去重`相关内容。

## 使用情况
所有GC都有字符串去重功能，主要看是否有`StringDedup::Requests`对象。

有`StringDedup::Requests`对象的具体类如下:
- `Serial GC`: `DefNewGeneration`、`MarkSweep`
- `Parellel GC`: `PSPromotionManager`、`ParCompactionManager`
- `G1 GC`: `G1FullGCMarker`
- `Shenandoah GC`: `ShenandoahConcurrentMarkingTask::work`、`ShenandoahFinalMarkingTask::work`、`ShenandoahSTWMark::finish_mark`
- `ZGC`: `ZMarkContext`、`XMarkContext`


## 查找字符串
查找去重的字符串，要满足至少3个条件：
- 启动字符串去重，参数`UseStringDeduplication`控制。 `StringDedup::is_enabled`
- 是`String`对象。 `java_lang_String::is_instance`
- 是年轻代对象或者老年代对象年龄大于参数`StringDeduplicationAgeThreshold`。 `G1StringDedup::is_candidate_from_mark`

查找到后，调用`StringDedup::Requests::add`把字符串加入`StringDedup::Requests`的`_buffer`。


## 去重具体操作
// TODO


## `去重`和`String::intern`区别
`String::intern`只是单纯地把`String`对象加到`StringTable`，之后重用。但是它不能消除已经存在的`String`对象。
`去重`是查看现存的`String`对象，消除相同的对象。
