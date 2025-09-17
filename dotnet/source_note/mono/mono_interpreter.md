# Mono解释器

## 命令

运行`mono`的命令需要添加参数`--interpreter`。

## 代码位置

目录在`src/mono/mono/mini`、`src/mono/mono/cil`和`src/mono/mono/mini/interp`，相关文件和函数的作用如下：

- 文件`cil/*opcode.*`：CIL操作码
- 文件`mini/interp/interp-internals.*`：解释器内部数据结构
- 文件`mini/interp/interp-intrins.*`：库函数、解释器操作码的intrinsics（内部实现）
- 文件`mini/interp/interp-pgo.*`：profile guided optimization
- 文件`mini/interp/interp-simd*`：SIMD操作的实现（intrinsics等）
- 文件`mini/interp/interp.*`：解释器的核心实现
  - 函数`interp_entry`、`interp_runtime_invoke`：解释器入口
  - 函数`mono_interp_exec_method`：解释执行对应方法
  - 函数`method_entry`：调用函数`do_transform_method`和`mono_interp_transform_method`，转换CIL为微操作码
- 文件`mini/interp/jiterpreter.*`：解释器到JIT编译器的接口（**只适用于WebAssembly后端**）
- 文件`mini/interp/mintops.*`：微操作码（解释器执行的指令，也叫虚拟机指令）
- 文件`mini/interp/tiering.*`：分层优化操作码和微操作码
  - 函数`tier_up_method`、`patch_interp_data_items`：在对应位置添加`INTERP_IMETHOD_IS_TAGGED`，用于拆箱操作
- 文件`mini/interp/transform.*`、`transform-opt.*`： CIL到微操作码的转换代码
  - 函数`mono_interp_transform_method`、`generate`、`generate_code`：CIL到微操作码的具体转换逻辑

## 解释器运行流程

- 函数`method_entry`：调用函数`do_transform_method`和`mono_interp_transform_method`，转换CIL为微操作码
- 函数`mono_interp_exec_method`：解释执行方法，循环遍历上一步生成的微操作码，进行对应操作（while + switch）

## 运行栈

```shell
mono_interp_exec_method(InterpFrame * frame, ThreadContext * context, FrameClauseArgs * clause_args) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/interp/interp.c:6460)
interp_runtime_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/interp/interp.c:2271)
mono_jit_runtime_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/mini-runtime.c:3479)
do_runtime_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:2575)
mono_runtime_try_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:2732)
mono_runtime_try_invoke_handle(MonoMethod * method, MonoObjectHandle obj, void ** params, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:2740)
ep_rt_mono_init_finish() (/home/lgx/source/csharp/runtime-mono/src/mono/mono/eventpipe/ep-rt-mono.c:760)
ep_rt_init_finish() (/home/lgx/source/csharp/runtime-mono/src/mono/mono/eventpipe/ep-rt-mono.h:403)
ep_finish_init() (/home/lgx/source/csharp/runtime-mono/src/native/eventpipe/ep.c:1520)
mini_init(const char * filename) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/mini-runtime.c:4899)
mono_main(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/driver.c:2464)
mono_main_with_options(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/main.c:36)
main(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/main.c:88)
```
