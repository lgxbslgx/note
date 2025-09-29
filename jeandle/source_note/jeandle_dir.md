# jeandle目录内容

目录内容在：src/hotspot/share/jeandle

## 各个子目录或文件的内容

```shell
├── jeandleAbstractInterpreter.*pp 抽象解释器（前端）
    ├── 类JeandleVMState：状态信息（栈和局部变量等）
    ├── 类JeandleBasicBlock：基本块信息
    ├── 类BasicBlockBuilder：基本块构造器
    └── 类JeandleAbstractInterpreter：把字节码转换成LLVM IR（LLVM指令、基础块、控制流图）
├── jeandleAssembler.*pp 宏汇编器。具体内容在对应的架构目录，比如`src/hotspot/cpu/x86/jeandleAssembler_x86.cpp`
├── jeandleCallVM.*pp 生成调用运行时库函数的蹦床代码（trampoline）。被jeandleRuntimeRoutine.*pp使用
├── jeandleCompilation.*pp 编译整体流程
├── jeandleCompiledCall.hpp 编译后的机器代码的调用点处理。具体内容在对应的架构目录，比如`src/hotspot/cpu/x86/jeandleCompiledCall_x86.cpp`
├── jeandleCompiledCode.*pp 编译后的机器代码的处理。处理 重定向、stackmap、oopmap、代码安装等。一些内容在对应的架构目录，比如`src/hotspot/cpu/x86/jeandleCompiledCode_x86.cpp`
├── jeandleCompiler.*pp 编译入口（包含TargetMachine等）
├── jeandle_globals.hpp 参数配置
├── jeandleReadELF.*pp ELF文件的读取和查找操作
├── jeandleRegister.hpp 寄存器内容（通用寄存器、栈指针、线程指针等）。具体内容在对应的架构目录，比如`src/hotspot/cpu/x86/jeandleRegister_x86.cpp`
├── jeandleResourceObj.*pp 资源对象基类。用于实现place new操作。
├── jeandleRuntimeRoutine.*pp 运行时库函数（C/C++、汇编代码）。一些内容在对应的架构目录，比如`src/hotspot/cpu/x86/jeandleRuntimeRoutine_x86.cpp`
├── jeandleType.*pp 类型和常量相关操作（被JeandleAbstractInterpreter使用）
├── jeandleUtils.*pp 工具类
└── templatemodule 运行时库函数（Java代码，以LLVM IR的形式定义）
    ├── jeandleRuntimeDefinedJavaOps.*pp 运行时库函数（Java代码，以LLVM IRBuilder的形式定义）
    └── template.ll 运行时库函数（Java代码，以LLVM IR文本的形式定义）
```
