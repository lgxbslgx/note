# 调试

runtime的构建内容详见[runtime_build.md](./runtime_build.md)。

- [SOS下载](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-sos)
- [修改和调试](https://github.com/dotnet/runtime/blob/main/docs/workflow/editing-and-debugging.md)
- [CoreCLR调试](https://github.com/dotnet/runtime/blob/main/docs/workflow/debugging/coreclr/debugging-runtime.md)

## 前期准备

```shell
# 安装SOS
dotnet tool install -g dotnet-sos
dotnet-sos install

# 创建测试集
cd src/mono/sample/HelloWorld
make publish
```

## LLDB调试CoreCLR

```shell
# 开始调试
lldb -- ./artifacts/bin/coreclr/linux.x64.Debug/corerun \
./artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll

# 启动进程，停止在程序入口
process launch -s

# 忽略信号
process handle -s false SIGUSR1

# 设置断点

# 继续运行
process continue
```

## VS Code调试CoreCLR

```json
// 文件launch.json
{
    "version": "0.2.0",
    "configurations": [
        {
        "name": "My Configuration",
        "type": "cppdbg",
        "request": "launch",
        "program": "/home/lgx/source/csharp/runtime-coreclr/artifacts/bin/coreclr/linux.x64.Debug/corerun",
        "args": ["/home/lgx/source/csharp/runtime-coreclr/artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll"],
        "cwd": ".",
        "stopAtEntry": true,
        }
    ]
}
```

## LLDB调试NativeAOT

// TODO

## VS Code调试NativeAOT

// TODO

## LLDB调试Mono

```shell
# 开始调试
MONO_PATH=./artifacts/bin/HelloWorld/x64/Debug/linux-x64 \
lldb -- ./artifacts/obj/mono/linux.x64.Debug/out/bin/mono-sgen \
./artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll

# 启动进程，停止在程序入口
process launch -s

# 忽略信号
process handle -s false SIGUSR1

# 设置断点

# 继续运行
process continue
```

## VS Code调试Mono

```json
// 文件launch.json
{
  "version": "0.2.0",
  "configurations": [
      {
      "name": "My Configuration",
      "type": "cppdbg",
      "request": "launch",
      "program": "/home/lgx/source/csharp/runtime-mono/artifacts/obj/mono/linux.x64.Debug/out/bin/mono-sgen",
      "args": ["/home/lgx/source/csharp/runtime-mono/artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll"],
      "cwd": ".",
      "stopAtEntry": true,
      "environment": [
        {
          "name": "MONO_PATH",
          "value": "/home/lgx/source/csharp/runtime-mono/artifacts/bin/HelloWorld/x64/Debug/linux-x64"
        }
      ]
      }
  ]
}
```
