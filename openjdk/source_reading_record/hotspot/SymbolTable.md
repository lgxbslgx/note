## 符号表`SymbolTable`

### `SymbolTable`初始化
方法`universe_init -> SymbolTable::create_table`创建`SymbolTableHash* _local_table`。本质上是一个并发哈系表。
共享表`OffsetCompactHashtable _shared_table`和`OffsetCompactHashtable _dynamic_shared_table`，未仔细看。


### `SymbolTable`提供的接口
- 表的整体操作: `create_table`、`table_size`、gc和并发相关`do_concurrent_work/has_work等`、`rehash_table`等
- 表的查找: `probe`、`lookup`、`lookup_common`、`do_lookup`，根据传入的`字符串`或者`符号Symbol`在哈系表上查找`字符相等`的条目，返回`Symbol* 符号指针`（一个符号`Symbol`里面至少有长度和一个字符数组）
- 表的插入: `new_symbol`、`new_permanent_symbol`、`do_add_if_needed`，先使用`lookup_common`查找是否存在，如果不存在则在哈系表中添加一个条目（该条目里面有一个符号`Symbol`）

- CDS、共享表相关操作: `symbols_do`、`shared_symbols_do`、`serialize_shared_table_header`、`estimate_size_for_archive`、`write_to_archive`  // TODO


### 使用`SymbolTable`的地方
- // TODO 很多，先不写了

