# CoreCLR各个目录的内容

## 代码位置

- [仓库dotnet/runtime的目录src/coreclr](https://github.com/dotnet/runtime/tree/main/src/coreclr)

## 各个目录详情

```shell
├── binder 程序集加载与绑定逻辑
│   └── inc
├── classlibnative 核心库本地（Native）方法
│   ├── bcltype
│   ├── float
│   └── inc
├── debug 调试基础设施
│   ├── createdump 生成崩溃转储（crash dump）文件的工具
│   ├── daccess 调试器数据访问层
│   ├── dbgutil 调试工具
│   ├── debug-pal
│   ├── di 调试接口
│   ├── ee 执行引擎的调试支持
│   ├── inc
│   ├── runtimeinfo 运行时版本、信息输出
│   └── shared
├── dlls 关键动态库
│   ├── clretwrc CLR事件写入
│   ├── mscordac 诊断数据访问组件（DAC）
│   ├── mscordbi CLR调试接口
│   ├── mscoree CLR宿主接口（启动托管入口）
│   ├── mscorpe 元数据工具
│   └── mscorrc 错误消息资源
├── gc 垃圾回收器实现
│   ├── env 处理环境交互
│   ├── sample
│   ├── unix unix相关的内存管理
│   ├── vxsort 优化GC的向量化排序算法
│   └── windows windows相关的内存管理
├── gcdump 转储GC堆的工具
│   └── i386
├── gcinfo GC元数据（JIT和GC交互）
├── hosts 运行时宿主程序
│   ├── corerun 轻量级执行引擎（默认宿主，启动.NET应用）
│   ├── coreshim 兼容层（支持旧版API）
│   └── inc
├── ilasm IL汇编器（生成PE文件）
│   ├── GrammarExtractor 提取语法
│   └── prebuilt 预构建工具
├── ildasm IL反汇编器（解析PE文件）
│   └── exe
├── inc
│   ├── clr
│   ├── CrstTypeTool
│   ├── genheaders
│   ├── llvm
│   └── mpl
├── interop 托管与非托管代码互操作
│   └── inc
├── interpreter 解释器
├── jit JIT编译器的核心逻辑（RyuJIT）
│   ├── jitstd JIT内部使用的标准库封装
│   └── static 静态编译支持
├── md 管理程序集元数据
│   ├── ceefilegen PE文件生成器
│   ├── compiler 处理IL元数据生成
│   ├── datasource
│   ├── enc Edit-and-Continue支持
│   ├── heaps
│   ├── inc
│   ├── runtime
│   ├── staticmd
│   └── tables 管理元数据表结构
├── minipal 轻量级PAL实现
│   ├── Unix
│   └── Windows
├── nativeaot AOT编译器
│   ├── Bootstrap 启动引导程序
│   ├── BuildIntegration
│   ├── Common
│   ├── docs
│   ├── Runtime
│   ├── Runtime.Base 基础AOT运行时
│   ├── System.Private.CoreLib
│   ├── System.Private.Reflection.Execution
│   ├── System.Private.StackTraceMetadata
│   ├── System.Private.TypeLoader 动态类型加载
│   └── Test.CoreLib 测试库
├── nativeresources 本地化资源文件（支持多语言错误信息报告）
├── pal 平台抽象层
│   ├── inc
│   ├── prebuilt
│   ├── src
│   ├── tests
│   └── tools
├── runtime 运行时支持，子目录存放不同CPU架构的特定代码
│   ├── amd64
│   ├── arm
│   ├── arm64
│   ├── i386
│   ├── loongarch64
│   └── riscv64
├── scripts 构建和测试脚本
│   └── emitUnitTests
├── System.Private.CoreLib 基础类库
│   └── src
├── tools 工具集
│   ├── aot
│   ├── AssemblyChecker
│   ├── cdac-build-tool
│   ├── Common
│   ├── dotnet-pgo PGO（Profile Guided Optimization）工具
│   ├── GCLogParser
│   ├── ILVerification/ILVerify IL代码验证器
│   ├── metainfo
│   ├── PdbChecker
│   ├── r2rdump Ready-to-Run镜像解析工具
│   ├── r2rtest
│   ├── runincontext
│   ├── SOS 调试扩展 (Son of Strike)
│   ├── SuperFileCheck
│   ├── superpmi 性能监控工具，收集JIT数据来调试
│   └── tieringtest
├── unwinder 栈展开
│   ├── amd64
│   ├── arm
│   ├── arm64
│   ├── i386
│   ├── loongarch64
│   ├── ppc64le
│   ├── riscv64
│   └── s390x
├── utilcode 通用工具库
└── vm 虚拟机核心实现（执行引擎Execution Engine），子目录存放不同CPU架构的特定代码
    ├── amd64
    ├── arm
    ├── arm64
    ├── eventing 事件追踪系统
    ├── i386
    ├── loongarch64
    ├── riscv64
    ├── wasm WebAssembly运行时支持
    └── wks 工作站GC相关实现
```
