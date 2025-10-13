# 编译流程

编译整体流程如下所示：

- 初始化：`JeandleCompiler::create`、`JeandleCompiler::initialize`
- 编译入口：`JeandleCompiler::compile_method`、`JeandleCompilation::JeandleCompilation`
- 字节码转换成LLVM IR：`JeandleAbstractInterpreter::JeandleAbstractInterpreter`、`JeandleAbstractInterpreter::interpret`
- LLVM IR代码优化：`llvm::jeandle::optimize`，具体内容在LLVM代码仓库
- LLVM IR转换成机器码：`JeandleCompilation::compile_module`
- 安装机器代码：`JeandleCompilation::install_code`

## 初始化

// TODO

## 编译入口

// TODO

## 字节码转换成LLVM IR

// TODO

## LLVM IR代码优化

// TODO

## LLVM IR转换成机器码

// TODO

## 安装机器代码

// TODO
