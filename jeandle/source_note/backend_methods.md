# jeandle-jdk特有的后端方法解析

## 文件`jeandleAssembler_<arch>.cpp`

### 方法`JeandleAssembler::emit_static_call_stub`

生成静态调用（对应字节码`invokedynamic`、`invokestatic`、`invokespecial`）相关的存根代码（`stub`）。

常用调用路径：

```shell
JeandleAssembler::emit_static_call_stub
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::patch_static_call_site`

设置静态调用（对应字节码`invokedynamic`、`invokestatic`、`invokespecial`）的目标地址，生成重定向信息。
如果目标地址离当前地址太远，则会生成跳床`trampoline`存根代码，用于长跳转（长调用）。
这个目标地址指向runtime方法`resolve_static_call`或`resolve_opt_virtual_call`的入口地址。
常用调用路径：

```shell
JeandleAssembler::patch_static_call_site
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::patch_stub_C_call_site`

设置当前调用的返回地址到`JavaFrameAnchor::_last_Java_pc`，以便于栈遍历和异常处理。设置runtime方法调用C/C++的目标地址
（已编译方法`nmethod`不能直接调用C/C++方法，需要一个runtime方法来调用C/C++方法）。
注意X86架构不需要实现该方法，因为它的`call`指令会自动把返回地址压入栈中，不需要额外保存返回地址。
常用调用路径：

```shell
JeandleAssembler::patch_stub_C_call_site
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::patch_routine_call_site`

设置调用runtime方法的目标地址，生成重定向信息。**目标地址本来就存在，所以这里主要是用于生成重定向信息。**
如果目标地址离当前地址太远，则会生成跳床`trampoline`存根代码，用于长跳转（长调用）。
常用调用路径：

```shell
JeandleAssembler::patch_routine_call_site
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::patch_ic_call_site`

设置 动态调用（对应字节码`invokevirtual`、`invokeinterface`）时、receiver类型和缓存的类型（inline cache）相同时 对应的目标地址。
这个目标地址指向runtime方法`resolve_virtual_call`的入口地址。
`ic`是`inline cache`的缩写。
常用调用路径：

```shell
JeandleAssembler::patch_ic_call_site
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::emit_ic_check`

生成 判断动态调用（对应字节码`invokevirtual`、`invokeinterface`）的receiver类型是否为缓存的类型（inline cache） 的代码。
receiver类型和缓存的类型不相同则调用runtime方法`ic_miss_stub`进行处理。
`ic`是`inline cache`的缩写。
常用调用路径：

```shell
JeandleAssembler::emit_ic_check
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

综合`JeandleAssembler::patch_ic_call_site`和`JeandleAssembler::emit_ic_check`：
如果receiver类型和缓存的类型（inline cache）相同，则直接调用`resolve_virtual_call`，否则调用`ic_miss_stub`。

### 方法`JeandleAssembler::emit_verified_entry`

生成一个空指令。后面会patch成一个跳转指令，跳转到用于验证的代码。
常用调用路径：

```shell
JeandleAssembler::emit_verified_entry
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::interior_entry_alignment`

方法入口需要对齐的字节数。注意：对齐前，有inline cache的检测代码。
常用调用路径：

```shell
JeandleAssembler::interior_entry_alignment
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::emit_exception_handler`

生成 **调用**异常处理器 的代码，放到`CodeOffsets`的`Exceptions`段。
异常处理器的代码在方法`JeandleRuntimeRoutine::generate_exception_handler`中生成（下文有该方法的说明）。
虚拟机**内部发生异常**时，会使用`Exceptions`中的代码，从而调用异常处理器。
常用调用路径：

```shell
JeandleAssembler::emit_exception_handler
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::emit_const_reloc`

生成常量地址的重定向信息。
常用调用路径：

```shell
JeandleAssembler::emit_exception_handler
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::emit_oop_reloc`

生成OOP的重定向信息。
常用调用路径：

```shell
JeandleAssembler::emit_oop_reloc
JeandleOopReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::fixup_routine_call_inst_offset`

获取 调用runtime方法指令 末尾的地址。即下一条指令的地址、也是调用的返回地址

常用调用路径：

```shell
JeandleAssembler::fixup_routine_call_inst_offset
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::is_oop_reloc_kind`

判断链接图（LinkGraph）的边类型是否为OOP的重定向类型。
常用调用路径：

```shell
JeandleAssembler::is_oop_reloc_kind
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::is_routine_call_reloc_kind`

判断链接图（LinkGraph）的边类型是否为runtime方法调用的重定向类型。
常用调用路径：

```shell
JeandleAssembler::is_routine_call_reloc_kind
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

### 方法`JeandleAssembler::is_const_reloc_kind`

判断链接图（LinkGraph）的边类型是否为常量的重定向类型。
常用调用路径：

```shell
JeandleAssembler::is_const_reloc_kind
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
```

## 文件`jeandleCompiledCall_<arch>.cpp`

### 方法`JeandleCompiledCall::call_site_size`

调用相应类型的方法时，所使用指令（可能是多个指令）的总字节数。
常用调用路径：

```shell
JeandleCompiledCall::call_site_size
JeandleCallReloc::JeandleCallReloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::JeandleCompilation8
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

```shell
JeandleCompiledCall::call_site_size
JeandleCallReloc::inst_end_offset
JeandleCallReloc::process_oop_map
JeandleCallReloc::emit_reloc
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

### 方法`JeandleCompiledCall::call_site_patch_size`

调用相应类型的方法时，需要修正的指令（可能是多个指令）的字节数。（对应类`JeandleAssembler`里面`patch_`开头的方法）。
常用调用路径：

```shell
JeandleCompiledCall::call_site_patch_size
JeandleCallVM::generate_call_VM
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

```shell
JeandleCompiledCall::call_site_patch_size
JeandleAbstractInterpreter::invoke
JeandleAbstractInterpreter::interpret_block
JeandleAbstractInterpreter::interpret
JeandleAbstractInterpreter::JeandleAbstractInterpreter
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
JeandleCompiler::compile_method
CompileBroker::invoke_compiler_on_method
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

## 文件`jeandleCompiledCode_<arch>.cpp`

### 方法`JeandleCompiledCode::setup_frame_size`

从ELF的`.stack_sizes`段中获取方法的栈帧大小。
常用调用路径：

```shell
JeandleCompiledCode::setup_frame_size
JeandleCompiledCode::finalize
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
JeandleCompiler::compile_method
CompileBroker::invoke_compiler_on_method
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

## 文件`jeandleRegister_<arch>.hpp`

### 方法`JeandleRegister::get_stack_pointer`

获取栈指针寄存器。
常用调用路径：

```shell
JeandleRegister::get_stack_pointer
JeandleCallVM::generate_call_VM
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

### 方法`JeandleRegister::get_current_thread_pointer`

获取线程指针寄存器。
常用调用路径：

```shell
JeandleRegister::get_current_thread_pointer
JeandleCallVM::generate_call_VM
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

### 方法`JeandleRegister::is_stack_pointer`

判断寄存器是否是栈指针寄存器。
常用调用路径：

```shell
JeandleRegister::is_stack_pointer
resolve_vmreg
JeandleCompiledCode::build_oop_map
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

### 方法`JeandleRegister::decode_dwarf_register`

获取DWARF调试寄存器映射信息。
常用调用路径：

```shell
JeandleRegister::decode_dwarf_register
resolve_vmreg
JeandleCompiledCode::build_oop_map
JeandleCompiledCode::resolve_reloc_info
JeandleCompiledCode::finalize
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

## 文件`jeandleRuntimeRoutine_<arch>.cpp`

### 方法`JeandleRuntimeRoutine::install_exceptional_return`

用于向上层方法抛出异常，即用于**实现向上展开unwind操作**。
当方法抛出异常时，会检查当前方法的异常处理表，判断是否捕获了该异常，如果没有捕获，则要向上层抛出异常。
向上抛出异常时，`install_exceptional_return`负责设置异常返回地址（也设置了原调用的返回地址和异常类型到`JavaThread`中），
使得当前返回地址为异常返回代码的地址（而不是原调用的返回地址）。

### 方法`JeandleRuntimeRoutine::generate_exceptional_return`

生成异常返回代码，细节如下：

- 设置栈结构（return address、frame pointer等）
- 调用方法`JeandleRuntimeRoutine::get_exception_handler`，获取异常处理器
- 跳转到异常处理器代码

常用调用路径：

```shell
JeandleRuntimeRoutine::generate_exceptional_return
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

### 方法`JeandleRuntimeRoutine::generate_exception_handler`

生成异常处理器代码。

- 设置栈结构（return address、frame pointer等）
- 调用方法`JeandleRuntimeRoutine::search_landingpad`，检查异常处理表中，该抛出异常的位置对应的处理代码地址
- 跳转到处理代码

常用调用路径：

```shell
JeandleRuntimeRoutine::generate_exception_handler
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

## 文件`jeandleUtils_<arch>.cpp`

### 方法`JeandleFuncSig::setup_description`

设置方法的描述信息（调用约定、GC、各种属性等）。
常用调用路径：

```shell
JeandleFuncSig::setup_description
JeandleCallVM::generate_call_VM
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

```shell
JeandleFuncSig::setup_description
JeandleFuncSig::create_llvm_func
JeandleAbstractInterpreter::JeandleAbstractInterpreter
JeandleCompilation::compile_java_method
JeandleCompilation::JeandleCompilation
JeandleRuntimeRoutine::generate
JeandleCompiler::initialize
CompileBroker::init_compiler_runtime
CompileBroker::compiler_thread_loop
CompilerThread::thread_entry
```

## 文件`relocInfo_<arch>.cpp`

### 方法`Relocation::pd_set_jeandle_data_value`

修改已编译方法（`nmethod`）中使用的可重定向的数据。常用于GC完成后，更新`nmethod`使用的OOP。
常见调用路径：

```shell
Relocation::pd_set_jeandle_data_value
DataRelocation::set_value
oop_Relocation::fix_oop_relocation
nmethod::fix_oop_relocations
G1CodeBlobClosure::do_evacuation_and_fixup # GC相关代码
```
