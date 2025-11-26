# 使用LLVM、Clang、ld.lld编译jeandle-jdk时遇到的问题

## 方法声明和定义不一致

```shell
/home/lgx/source/java/jeandle-jdk/src/hotspot/share/memory/allocation.cpp:114:15: error: exception specification in declaration does not match previous declaration
  114 | void* AnyObj::operator new(size_t size, Arena *arena) throw() {
      |               ^
/home/lgx/source/java/jeandle-jdk/src/hotspot/share/memory/allocation.hpp:504:9: note: previous declaration is here
  504 |   void* operator new(size_t size, Arena *arena);
      |         ^
1 error generated.
```

原因：
方法声明中没有`throw()`，但是方法定义中却使用了`throw()`。

解决办法：
声明和定义保持一致，删掉方法定义中不必要的`throw()`。OpenJDK主线已经删除了`throw()`，详见issue [JDK-8317132](https://bugs.openjdk.org/browse/JDK-8317132)。

## 不允许使用register指示符

```shell
home/user/source/jeandle-jdk/src/hotspot/os_cpu/linux_riscv/vm_version_linux_riscv.cpp:87:20: error: ISO C++17 does not allow 'register' storage class specifier [-Wregister]
   87 |   return (uint32_t)read_csr(CSR_VLENB);
      |                    ^
/home/user/source/jeandle-jdk/src/hotspot/os_cpu/linux_riscv/vm_version_linux_riscv.cpp:77:9: note: expanded from macro 'read_csr'
   77 |         register unsigned long __v;                             \
      |         ^
1 error generated
```

原因：
RISCV架构代码中使用`register`关键字修饰变量。`GCC`编译时只会报告一个警告信息，但是`Clang`编译时会报告一个错误信息，从而编译失败。

解决办法：
去掉相关代码中的`register`关键字。OpenJDK主线已经去掉了`register`，详见issue [JDK-8319440](https://bugs.openjdk.org/browse/JDK-8319440)。

## ld.lld链接时找不到一些符号

```shell
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTV14ZObjectClosureIZN7ZVerify17before_relocationEP11ZForwardingE3$_0E' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVN12_GLOBAL__N_112JeandleRelocE' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVN12_GLOBAL__N_115JeandleOopRelocE' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVN12_GLOBAL__N_116JeandleCallRelocE' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVN12_GLOBAL__N_117JeandleConstRelocE' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZ21WB_HandshakeWalkStackE16TraceSelfClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZ24WB_HandshakeReadMonitorsE19ReadMonitorsClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZ26WB_AsyncHandshakeWalkStackE16TraceSelfClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZL20reinitialize_itablesvE18ReinitTableClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZL28verify_empty_dirty_card_logsvE8Verifier' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN12JvmtiEnvBase27check_for_periodic_clean_upEvE28ThreadInsideIterationClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN14ClassLoaderExt20process_module_tableEP10JavaThreadP16ModuleEntryTableE19ModulePathsGatherer' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN14G1HeapVerifier19verify_bitmap_clearEbE19G1VerifyBitmapClear' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN15ClassLoaderData19demote_strong_rootsEvE25TransitionRootsOopClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN15G1CollectedHeap36verify_region_attr_remset_is_trackedEvE22VerifyRegionAttrRemSet' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN15G1RemSetSummary6updateEvE11CollectData' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN16DefNewGeneration26remove_forwarding_pointersEvE22ResetForwardedMarkWord' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN16SATBMarkQueueSet18dump_active_statesEbE22DumpThreadStateClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN16SATBMarkQueueSet20verify_active_statesEbE25VerifyThreadStatesClosure' failed: symbol not defined
ld: error: version script assignment of 'SUNWprivate_1.1' to symbol '_ZTVZN16SATBMarkQueueSet22set_active_all_threadsEbbE22SetThreadActiveClosure' failed: symbol not defined
ld: error: too many errors emitted, stopping now (use --error-limit=0 to see all errors)
clang++: error: linker command failed with exit code 1 (use -v to see invocation)
gmake[3]: *** [lib/CompileJvm.gmk:162: /home/user/source/jeandle-jdk/build/linux-riscv64-server-slowdebug/support/modules_libs/java.base/server/libjvm.so] Error 1
gmake[2]: *** [make/Main.gmk:252: hotspot-server-libs] Error 2
```

原因：

- `JvmMapfile.gmk`：使用`nm`命令获取目标文件（`.o`结尾）的符号信息，放到`hotspot/variant-server/libjvm/symbols-objects`中
- `JvmMapfile.gmk`：把上一步的符号信息和`make/data/hotspot-symbols`目录的符号信息进行合并，放到`hotspot/variant-server/libjvm/symbols`中
- `JvmMapfile.gmk`：根据`hotspot/variant-server/libjvm/symbols`的符号信息生成给链接器使用的版本文件
  - 版本文件存储在`hotspot/variant-server/libjvm/mapfile`
  - 版本文件的内容主要是定义**公共符号和本地符号的版本信息**
- `CompileJvm.gmk`、`JdkNativeCompilation.gmk`、`NativeCompilation.gmk`：给链接器添加参数`-Wl,-version-script=<file>`，链接器会根据这个文件设置符号的版本信息
  - 前面第一步使用`nm`提取符号信息时，一些本地符号也被提取了，然后版本文件的公共符号部分包含了本地符号
  - GCC的链接器`ld`在遇到不符合规定的本地符号时，会忽略这个信息，使得链接可以成功
  - Clang使用的链接器`ld.lld`则不能忽略这些错误，会直接报错

解决方法：

- 方法1：在`hotspot/variant-server/libjvm/mapfile`中删除所有本地符号（删除报错的符号）
  - 优点：快速解决，不需要修改代码
  - 缺点：每次新的构建都要删除对应符号
- 方法2：在`JvmMapfile.gmk`提取的时候，只提取公共符号。把`nm`添加参数`--extern-only`。
  - 优点：永久解决该问题，不需要每次都删除版本文件中的本地符号
  - 缺点：需要修改代码和提交补丁
- 方法3：不使用版本文件和`-Wl,-version-script=<file>`，使用`__attribute__((visibility("default")))`控制可见性
  - OpenJDK主线已经不使用mapfile，详见issue [JDK-8017234](https://bugs.openjdk.org/browse/JDK-8017234)
  - `__attribute__((visibility("default")))`的内容详见`src/java.base/unix/native/include/jni_md.h`等文件
