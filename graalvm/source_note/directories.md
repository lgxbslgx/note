## 各个目录的内容

```shell
graal
├── compiler 编译器（把字节码编译成native代码），JIT编译（替代HotSpot的C2、被使用truffle框架的解释器调用）、被SubstrateVM用来做AOT编译。
├── espresso 基于truffle框架的Java字节码解释器，该解释器运行在JVM之上。
├── java-benchmarks 基准测试
├── regex 正则表达式引擎
├── sdk 内部或外部使用的库函数
├── substratevm 将Java代码编译成native代码
├── sulong 基于truffle框架的LLVM bitcode解释器，该解释器运行在JVM之上。使得使用LLVM进行编译的语言都可以运行在JVM中。
├── tools 基于truffle框架实现一个解释器时要用到的工具
├── truffle 解释器实现**框架**，提供解释器的开发框架接口。方便移植旧语言到GraalVM和实现新语言。还提供了剖析和编译接口。
├── visualizer 理想图可视化器Ideal Graph Visualizer (IGV)
├── vm 用于构建GraalVM发行版（distribution）
└── wasm 基于truffle框架的WebAssembly解释器，该解释器运行在JVM之上。使得支持WebAssembly的语言都可以运行在JVM中。
```
