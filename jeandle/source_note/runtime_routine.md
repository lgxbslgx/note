# 运行时库函数

运行时库函数主要在目录`templatemodule`和文件`jeandleRuntimeRoutine.*pp`中。

## 目录`templatemodule`

目录`templatemodule`中存放了**以`LLVM IR`形式**定义的运行时库函数。**在“JeandleCompilation::setup_llvm_module”设置并生效。**

### 文件`jeandleRuntimeDefinedJavaOps.*pp`

运行时库函数，以`LLVM IRBuilder`的形式定义。每一个宏`DEF_JAVA_OP`定义一个运行时函数。

### 文件`template.ll`

运行时库函数（Java代码，以`LLVM IR文本`的形式定义）。每个`LLVM IR文本`函数对应一个运行时函数。

## 文件`jeandleRuntimeRoutine.*pp`

### 宏`ALL_JEANDLE_C_ROUTINES`

jeandle自定义的运行时库函数，为**C/C++代码**。其中，宏`GEN_C_ROUTINE_STUB`生成了运行时库函数调用的蹦床代码（trampoline）。宏`DEF_LLVM_CALLEE`是用于生成调用运行时库函数的`LLVM IR`代码。

### 宏`ALL_HOTSPOT_ROUTINES`

**HotSpot已有的**运行时库函数，为**C/C++代码**。其中，宏`DEF_HOTSPOT_ROUTINE_CALLEE`是用于生成调用运行时库函数的`LLVM IR`代码。注意：**HotSpot已有的运行时库函数，HotSpot已经生成蹦床代码（trampoline），jeandle不需要再生成**

### 宏`ALL_JEANDLE_ASSEMBLY_ROUTINES`

jeandle自定义的运行时库函数，为**汇编代码**。注意：具体的实现在对应的架构目录中，比如`src/hotspot/cpu/x86/jeandleRuntimeRoutine_x86.cpp`。
