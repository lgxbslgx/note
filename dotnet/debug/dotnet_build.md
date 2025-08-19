# 构建整个.Net

## 相关链接

- [环境准备](https://github.com/dotnet/runtime/blob/main/docs/workflow/requirements/linux-requirements.md)
- [构建过程](https://github.com/dotnet/dotnet/tree/main?tab=readme-ov-file#building)

## 构建

```shell
# 下载代码
git clone  https://github.com/dotnet/dotnet.git
cd dotnet

# 安装依赖
sudo apt install -y cmake llvm lld clang build-essential \
  python-is-python3 curl git lldb libicu-dev liblttng-ust-dev \
  libssl-dev libkrb5-dev ninja-build pigz cpio

# 构建（不成功）
./prep-source-build.sh
./build.sh -sb --clean-while-building

# 构建（也不成功）
./build.sh --clean-while-building

# 解压构建结果
mkdir -p $HOME/dotnet
tar zxf artifacts/assets/Release/dotnet-sdk-10.0.100-[your-RID].tar.gz -C $HOME/dotnet
ln -s $HOME/dotnet/dotnet /usr/bin/dotnet
```
