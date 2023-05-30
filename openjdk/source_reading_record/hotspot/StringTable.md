## 字符串表`StringTable`

### `StringTable`初始化
方法`universe_init -> StringTable::create_table`创建`StringTableHash* _local_table`。本质上是一个支持并发的哈系表。
共享表`SharedStringTable _shared_table`，未仔细看。


### `StringTable`提供的接口
- 表的整体操作: `create_table`、`table_size`、gc和并发相关`do_concurrent_work/has_work等`、`rehash_table`等
- 表的查找: `lookup`、`do_lookup`，根据传入的`字符串`在哈系表上查找`字符相等`的条目，返回该条目的`OOP`（该`OOP`指向堆中的一个`String`对象）
- 表的插入: `intern`、`do_intern`，先使用`do_lookup`查找是否存在，如果不存在则在哈系表中添加一个条目（并且在堆上添加一个`String`对象，该条目指向该对象，注意`String`对象里面有一个字节数组`value`表示字符串）

- CDS、共享表相关操作: `init_shared_table`、`lookup_shared`、`serialize_shared_table_header`、`allocate_shared_strings_array`等 // TODO


### 使用`StringTable`的地方
- 调用Java方法`String::intern`
- 调用字节码`ldc`
- // TODO

