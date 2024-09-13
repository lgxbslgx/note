## 构建过程

### 下载和构建bootstrap工具链 `src/bootstrap/bootstrap.py::main`
- 解析参数 `bootstrap.py::parse_args`
- 获取bootstrap工具链 `bootstrap.py::bootstrap -> download_toolchain`
  - 主要有beta版的编译器`rustc`、构建工具`cargo`、基础库`std`
  - 下载压缩包到`build/cache/<date>`目录 `bootstrap.py::download_component`
  - 解压工具链到`build/<target>/stage0`目录 `bootstrap.py::unpack_component`
- 构建`src/bootstrap`目录的rust项目 `bootstrap.py::bootstrap -> build_bootstrap -> build_bootstrap_cmd`
  - 使用`build/<target>/stage0/bin/cargo`命令
  - 构建输出到`build/bootstrap/debug`目录
  - 主要有`bootstrap`、`libbootstrap`、`rustc`、`rustdoc`等命令
- 使用`build/bootstrap/debug/bootstrap`命令运行传入的参数
  - 也就是`./x.py build`变成了`bootstrap build`
  - `./x.py test tests/ui/`即变成`bootstrap test tests/ui/`，以此类推


### 执行`bootstrap`命令运行子命令

- 命令在`build/bootstrap/debug/bootstrap`
- 源码在`src/bootstrap/src/bin/main.rs`

#### 前期准备
代码主要在`src/bootstrap/src/bin/main.rs::main`和`src/bootstrap/src/lib.rs::Build::new`。
- 解析参数
- 查找C++编译器、标准库（使用代码`src/tools/libcxx-version/main.cpp`）等信息
- 获取子模块的最新代码，子模块见`.gitmodules`。
- 获取根项目（对应根目录的`Cargo.toml`）和库函数（对应`library/Cargo.toml`）的包信息
  - 代码在`src/bootstrap/src/core/metadata.rs::build -> workspace_members`
- 建立符号链接`build/host`指向`build/<target>`


#### 下载和构建一些工具
- 下载一些工具
  - 主要有快照版（nightly）的编译器`rustc`、格式化工具`rustfmt`
  - 下载压缩包到`build/cache/<date>`目录
  - 解压工具链到`build/<target>/rustfmt`目录（注意不是`stage0`，并且编译器也解压到`rustfmt`）
- 构建`library/sysroot`目录的rust项目（就是标准库）
  - 使用`build/<target>/stage0/bin/cargo`命令
  - 构建输出到`build/<target>/stage0-std/<target>`目录
  - `library/sysroot`里面没有代码,依赖了库`library/std`、`library/core`，也就是编译这些库的代码
- 构建`compiler/rustc`目录的rust项目
  - 使用`build/<target>/stage0-rustc/bin/cargo`命令
  - 构建输出到`build/<target>/stage0-rustc/<target>`目录
  - 生成`rustc-main`命令
- 构建`src/tools/lld-wrapper`目录的rust项目
  - 使用`build/<target>/stage0-rustc/bin/cargo`命令
  - 构建输出到`build/<target>/stage0-tools/<target>`目录
  - 生成`lld-wrapper`命令
- 构建`library/sysroot`目录的rust项目（就是标准库）
  - 使用`build/<target>/stage0/bin/cargo`命令
  - 构建输出到`build/<target>/stage1-std/<target>`目录（注意不是`stage0-std`）
  - `library/sysroot`里面没有代码,依赖了库`library/std`、`library/core`，也就是编译这些库的代码
- 获取快照版（nightly）的rust开发工具`rust-dev`（llvm等内容）
  - 下载压缩包到`build/cache`目录
  - 解压到`build/<target>/ci-llvm`目录
- 使用`llvm-config`命令进行一些操作（不懂）
- 删除系统根`Removing sysroot /home/lgx/source/rust/rust/build/<target>/stage0-sysroot`（不懂）
- 使用`llvm-config`命令进行一些操作（不懂）
- 使用系统根`using sysroot /home/lgx/source/rust/rust/build/<target>/stage0-sysroot`（不懂）
- 后面还有一些关于`llvm-config`、`sysroot`的内容，直接省略了。

#### 根据子命令和参数进行具体操作

bootstrap子命令`Subcommand`相关内容:
- 子命令`src/bootstrap/src/core/config/flags.rs::Subcommand`
- 命令种类`src/bootstrap/src/core/builder.rs::Kind`
- 子命令`flags.rs::Subcommand`和命令种类`builder.rs::Kind`基本一一对应
- 方法`src/bootstrap/src/core/config/flags.rs::Subcommand::kind`里面有子命令和命令种类的对应关系

bootstrap子命令的步骤`Step`相关内容：
- 实现trait`Step`的结构都是子命令的步骤
  - `Step::DEFAULT`判断步骤是否默认运行，为真则不需要运行`Step::should_run`，直接运行`Step::make_run`。
  - `Step::should_run`根据参数判断步骤是否应该运行，应该运行则调用`Step::make_run`。
  - `Step::make_run`直接或间接运行`Step::run`。做一些参数判断是否运行`run`方法、或者调用多少次`run`方法
  - `Step::run`真正的要运行的代码
- `StepDescription`去除无关信息的步骤描述
  - `StepDescription::should_run`根据参数判断步骤是否应该运行，应该运行则调用`StepDescription::make_run`。`StepDescription::should_run`其实等于`Step::should_run`。
  - `StepDescription::make_run`直接或间接运行`Step::run`。做一些参数判断是否运行`run`方法、或者调用多少次`run`方法。`StepDescription::make_run`其实等于`Step::make_run`。
- 方法`src/bootstrap/src/core/builder.rs/Builder::get_step_descriptions`获取各个子命令包含的步骤

bootstrap运行过程的调用链
```
src/bootstrap/src/bin/main.rs::main ->
src/bootstrap/src/lib.rs::Build::build ->
src/bootstrap/src/lib.rs::Build::execute_cli ->
src/bootstrap/src/lib.rs::Build::run_step_descriptions ->
src/bootstrap/src/lib.rs::StepDescription::run -> 
src/bootstrap/src/core/builder.rs::StepDescription::should_run/maybe_run/run
```

- 获取子命令的所有步骤，用`StepDescription`表示。`src/bootstrap/src/lib.rs::Build::execute_cli -> Builder::get_step_descriptions`
- 调用每个步骤的方法`StepDescription::should_run`（也就是调用`Step::should_run`），判断步骤是否应该运行。`src/bootstrap/src/lib.rs::StepDescription::run(注意这里不是Step::run) -> src/bootstrap/src/lib.rs::StepDescription::should_run`
- 根据参数中的目录信息，来运行操作
  - 如果参数没有目录信息，则根据`StepDescription::default`（也就是`Step::DEFAULT`）来判断是否运行操作。
  - 如果有目录信息中有测试套件目录，则针对这些测试套件目录来运行操作
  - 最后针对剩下的路径来运行操作
  - 具体操作: 运行方法`src/bootstrap/src/core/builder.rs::StepDescription::maybe_run`来获取所有的target后端，每个他target后端都调用方法`src/bootstrap/src/core/builder.rs::StepDescription::make_run`来判断是否运行`run`方法、或者调用多少次`Step::run`方法。最后直接或间接调用`Step::run`方法。

