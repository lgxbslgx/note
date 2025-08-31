# Mono各个目录的内容

## 代码位置

- [仓库dotnet/runtime的目录src/mono](https://github.com/dotnet/runtime/tree/main/src/mono)

## 各个目录详情

```shell
├── browser 浏览器环境（WebAssembly）的运行时支持
│   ├── build 构建脚本和配置
│   ├── debugger 浏览器调试器集成
│   └── runtime 浏览器专属的运行时适配
├── cmake 构建系统配置文件
├── llvm 集成LLVM编译器框架，用于AOT编译优化
├── mono Mono runtime核心目录
│   ├── arch 硬件平台相关的代码
│   ├── cil 公共中间语言（CIL）的处理逻辑，包括字节码解析和验证
│   ├── component 模块化组件（如日志、配置），支持运行时动态扩展
│   ├── eglib 基础工具库，为跨平台抽象层提供基础支持（轻量级GLib实现）
│   ├── eventpipe 跨平台事件管道系统，用于诊断和性能分析
│   ├── metadata 程序集元数据管理（程序集加载、反射、类型系统等）
│   ├── mini JIT编译器的核心实现
│   ├── minipal 最小化平台抽象层（Platform Abstraction Layer）
│   ├── offsets 和runtime内部数据结构偏移相关（生成给调试器/GC用的偏移表）
│   ├── profiler 性能分析和诊断的工具接口
│   ├── sgen 分代式垃圾回收器（Simple Generational GC）
│   ├── tests runtime的测试
│   ├── unit-tests 单元测试
│   └── utils 内部工具类
├── msbuild 工具链与构建系统
│   ├── android 安卓平台特定的构建支持
│   ├── apple IOS平台特定的构建支持
│   └── common 共享的构建逻辑
├── nuget NuGet包管理目录，包含各平台工作负载的SDK和工具链
│   ├── Microsoft.NETCore.BrowserDebugHost.Transport
│   ├── Microsoft.NET.Runtime.Android.Sample.Mono
│   ├── Microsoft.NET.Runtime.iOS.Sample.Mono
│   ├── Microsoft.NET.Runtime.LibraryBuilder.Sdk
│   ├── Microsoft.NET.Runtime.MonoAOTCompiler.Task AOT编译的MSBuild任务
│   ├── Microsoft.NET.Runtime.MonoTargets.Sdk
│   ├── Microsoft.NET.Runtime.wasm.Sample.Mono
│   ├── Microsoft.NET.Runtime.WebAssembly.Sdk WASM应用的构建工具链
│   ├── Microsoft.NET.Runtime.WebAssembly.Wasi.Sdk
│   ├── Microsoft.NET.Runtime.WorkloadTesting.Internal
│   ├── Microsoft.NET.Sdk.WebAssembly.Pack
│   ├── Microsoft.NET.Workload.Mono.Toolchain.Current.Manifest
│   ├── Microsoft.NET.Workload.Mono.Toolchain.net6.Manifest 不同.NET版本（net6~net9）的运行时清单
│   ├── Microsoft.NET.Workload.Mono.Toolchain.net7.Manifest 
│   ├── Microsoft.NET.Workload.Mono.Toolchain.net8.Manifest
│   └── Microsoft.NET.Workload.Mono.Toolchain.net9.Manifest
├── sample 平台示例代码
│   ├── Android 安卓平台示例
│   ├── HelloWorld 基础示例
│   ├── iOS iOS平台示例
│   ├── iOS-NativeAOT
│   ├── mbr Mono-based Runtime 示例
│   ├── wasi WebAssembly示例
│   └── wasm WebAssembly示例
├── System.Private.CoreLib .NET核心基础库源码
│   └── src
├── tests 全局测试套件
│   └── HwIntrinsics 硬件指令集（如 SIMD）测试
├── tools
│   └── jitdiff JIT编译器性能对比工具，用于优化前后代码生成分析
├── wasi WASI（WebAssembly系统接口）支持
│   ├── build WASM编译脚本和依赖配置
│   ├── mono-include 头文件
│   ├── runtime WASI标准兼容的运行时
│   ├── testassets 测试所需的静态资源文件
│   └── Wasi.Build.Tests
└── wasm WebAssembly平台支持
    ├── build 构建配置
    ├── data
    ├── host WASM运行时宿主（如V8引擎集成）
    ├── sln
    ├── symbolicator WASM符号解析（堆栈跟踪映射）
    ├── templates WASM项目模板
    ├── testassets 测试所需的静态资源文件
    └── Wasm.Build.Tests 构建测试
```
