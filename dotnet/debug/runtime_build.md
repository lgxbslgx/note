# dotnet/runtime代码仓库构建

## 相关链接

- [环境准备](https://github.com/dotnet/runtime/blob/main/docs/workflow/requirements/linux-requirements.md)
- [runtime构建](https://github.com/dotnet/runtime/blob/main/docs/workflow/README.md)
- [CoreCLR构建](https://github.com/dotnet/runtime/blob/main/docs/workflow/building/coreclr/README.md)
- [CoreCLR的NativeAOT构建](https://github.com/dotnet/runtime/blob/main/docs/workflow/building/coreclr/nativeaot.md)
- [Mono构建](https://github.com/dotnet/runtime/tree/main/docs/workflow/building/mono)

## 构建准备

```shell
# 下载代码
git clone  https://github.com/dotnet/runtime.git
cd runtime

# 安装依赖
sudo apt install -y cmake llvm lld clang build-essential \
  python-is-python3 curl git lldb libicu-dev liblttng-ust-dev \
  libssl-dev libkrb5-dev ninja-build pigz cpio

# 安装新版本的LLVM
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo add-apt-repository "deb http://apt.llvm.org/$(lsb_release -sc)/ llvm-toolchain-$(lsb_release -sc)-18 main"
sudo apt update
sudo apt install clang-18 lld-18 clangd-18

# 创建测试集
cd src/mono/sample/HelloWorld
make publish
```

## 构建完整内容

```shell
# 构建完整内容（不包括NativeAOT和Mono）
./build.sh -subset clr+libs+host+packs -c Release

# 构建结果所在目录
artifacts/bin/coreclr/<OS>.<Architecture>.<Configuration>/
artifacts/packages/<Configuration>/Shipping/

# 构建结果实际目录
artifacts/bin/coreclr/linux.x64.Release/
artifacts/packages/Release/Shipping/

# 运行
./artifacts/bin/coreclr/linux.x64.Release/corerun \
./artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll
```

## 构建CoreCLR

```shell
# 构建CoreCLR（不包括NativeAOT）和库
./build.sh -subset clr+libs -c Debug

# 构建结果所在目录
artifacts/bin/coreclr/<OS>.<Architecture>.<Configuration>/

# 构建结果实际目录
artifacts/bin/coreclr/linux.x64.Debug/

# 运行
./artifacts/bin/coreclr/linux.x64.Debug/corerun \
./artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll
```

## 构建NativeAOT

```shell
# 构建NativeAOT和库
./build.sh -subset clr.aot+libs -c Debug /p:WarningsAsErrors=false /p:TreatWarningsAsErrors=false

# 构建结果所在目录
artifacts/bin/coreclr/<OS>.<Architecture>.<Configuration>/ilc/

# 构建结果实际目录
artifacts/bin/coreclr/linux.x64.Debug/ilc/

# 运行
DOTNET_ROOT=.dotnet/ \
./artifacts/bin/coreclr/linux.x64.Debug/ilc/ilc \
../runtime-mono/artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll
```

## 构建Mono

```shell
# 构建Mono和库
./build.sh mono+libs -c Debug /p:KeepNativeSymbols=true /p:MonoEnableLLVM=true
# 构建结果所在目录
artifacts/obj/mono/<OS>.<Architecture>.<Configuration>/out/

# 构建结果实际目录
./artifacts/bin/mono/linux.x64.Debug/

# 运行
MONO_PATH=./artifacts/bin/HelloWorld/x64/Debug/linux-x64 \
./artifacts/obj/mono/linux.x64.Debug/out/bin/mono-sgen \
./artifacts/bin/HelloWorld/x64/Debug/linux-x64/HelloWorld.dll
```

## 构建子集说明（subset）

- clr：CoreCLR + CoreLib
- libs：All the libraries components, excluding their tests.
- packs：The shared framework packs, archives, bundles, installers, and the framework pack tests.
- host：The .NET hosts, packages, hosting libraries, and their tests.
- mono：Mono + CoreLib

## 配置说明

- -runtimeConfiguration (-rc): The CoreCLR build configuration
- -librariesConfiguration (-lc): The Libraries build configuration
- -hostConfiguration (-hc): The Host build configuration
