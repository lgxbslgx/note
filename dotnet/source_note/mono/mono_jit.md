# Mono的JIT编译器

## 代码位置

目录在`src/mono/mono/mini`，相关文件和函数的作用如下：

- 文件`mini/transform.*`：

## 运行流程

// TODO

## 运行栈

```shell
mono_jit_runtime_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/mini-runtime.c:3693)
do_runtime_invoke(MonoMethod * method, void * obj, void ** params, MonoObject ** exc, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:2575)
mono_runtime_invoke_checked(MonoMethod * method, void * obj, void ** params, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:2791)
do_exec_main_checked(MonoMethod * method, MonoArray * args, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:4714)
mono_runtime_exec_main_checked(MonoMethod * method, MonoArray * args, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:4811)
mono_runtime_run_main_checked(MonoMethod * method, int argc, char ** argv, MonoError * error) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/metadata/object.c:4375)
mono_jit_exec_internal(MonoDomain * domain, MonoAssembly * assembly, int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/driver.c:1365)
mono_jit_exec(MonoDomain * domain, MonoAssembly * assembly, int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/driver.c:1310)
main_thread_handler(gpointer user_data) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/driver.c:1441)
mono_main(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/driver.c:2565)
mono_main_with_options(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/main.c:36)
main(int argc, char ** argv) (/home/lgx/source/csharp/runtime-mono/src/mono/mono/mini/main.c:88)
```
