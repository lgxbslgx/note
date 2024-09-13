## 流程
- 构建未指定`--stage`，则默认构建stage1的内容。
- 测试未指定`--stage`，则默认使用stage2的内容，stage2没有则使用stage1，以此类推。
- 安装未指定`--stage`，则默认使用stage2的内容，stage2没有则使用stage1，以此类推。

### Stage 0
- 下载现有的beta版本的编译器和库到本地，称为stage0编译器
- 使用stage0编译器来构建库，称为stage0库

### Stage 1
- 使用stage0编译器和stage1库来构建编译器，称为stage1编译器
- 使用stage1编译器来构建库，称为stage1库

### Stage 2
- 使用stage1编译器和stage1库来构建编译器，称为stage2编译器
- 使用stage2编译器来构建库，称为stage2库

## 构建

```shell
# 清理所有内容
rm -rf build
# 清理config.toml
rm config.toml
# 清理除了llvm的所有内容
./x.py clean

# 配置，生成文件config.toml。（选择compiler，生成vscode的项目文件）
./x.py setup

# 默认构建stage1编译器和库
./x.py build

# 使用stage0编译器构建stage0库（修改库函数，不修改编译器的时候，可以使用这个命令快速构建库）
./x.py build --stage 0 library

# 默认构建stage1库（包括stage1编译器）
./x.py build library

# 构建stage2库（包括了stage2编译器）
./x.py build library --stage 2

# 构建stage2编译器和库
./x.py build --stage 2

# 使用刚刚构建的内容（注意: 输出的版本内容以`-dev`结尾）
./build/x86_64-unknown-linux-gnu/stage1/bin/rustc -vV

# 创建工具链
rustup toolchain link stage0 build/host/stage0-sysroot
rustup toolchain link stage1 build/host/stage1
rustup toolchain link stage2 build/host/stage2

# 使用刚刚添加的stage1工具链
rustc +stage1 -vV

# 打包stage2的内容到`dist`目录
./x.py dist

# 安装stage2的内容到指定目录（一般都是创建工具链即可，不需要安装）
./x.py install
```


## 测试
注意测试默认使用

```shell
# 运行所有测试
./x.py test

# 运行某个目录或文件的测试`./x.py test <directory/file>`，例子如下
# 运行标准库的测试
./x.py test library/std
# 运行测试目录下ui目录的测试
./x.py test tests/ui
# 运行ui目录下const-generics目录的测试
./x.py test tests/ui/const-generics
# 运行const-generics目录下const-arg-in-fn.rs文件的测试
./x.py test tests/ui/const-generics/const-arg-in-fn.rs

# 目录前缀如果为`compiler`、`library`、`src/tools`则可以省略。例子如下
# 标准库`library/std`可以写成`std`
./x.py test std
# 工具tidy`src/tools/tidy`可以写成`tidy`
./x.py test tidy
```

