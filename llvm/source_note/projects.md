# LLVM各个子项目和runtime的含义

## bolt

Binary Optimization and Layout Tool 二进制优化与布局工具、后二进制优化器，对已编译的二进制文件进行优化，改进代码布局，提高指令缓存命中率等。

## clang

C语言家族（C、C++、Objective-C、Objective-C++等语言）的编译器前端。

## clang-tools-extra

Clang的额外工具集合

- 代码分析和检查
  - clang-tidy：静态代码分析工具
  - clang-query：交互式AST查询工具
- 代码重构
  - clang-apply-replacements：读取clang-tidy等工具输出的修改建议文件，并自动应用到源代码。
  - clang-format：代码格式化工具
  - clang-move：重构工具，用于移动类定义和成员函数
  - clang-reorder-fields：重构工具，用于重排字段顺序
  - clang-change-namespace：重构工具，用于修改命名空间
  - include-cleaner：用于静态分析头文件包含关系，清理不必要的头文件
- 开发辅助工具
  - clangd：语言服务器协议（LSP）实现，提供语法高亮、代码补全、定义跳转、引用查找等功能
  - pp-trace：跟踪预处理过程中的每一步（如宏展开、文件包含）
  - clang-include-fixer：自动修复缺失的头文件
  - modularize：创建模块化头文件
  - clang-doc：从C++代码生成文档

tool-template目录：创建新Clang工具的模板

## cross-project-tests

跨项目集成测试用例集合，确保不同LLVM子项目之间的兼容性和正确交互。

## lld

LLVM的链接器。

## lldb

LLVM Debugger LLVM调试器。

## mlir

Multi-Level Intermediate Representation 多层中间表示框架，支持编译器中间表示的设计、重用、扩展，适用于机器学习编译器、领域特定语言编译器。

## polly

Polyhedral Loop Optimizer 多面体优化框架，基于多面体模型的循环优化、自动向量化、自动并行化、数据局部性优化。

## flang

Fortran语言编译器前端。

## compiler-rt

编译器运行时库。

## libcxx

C++标准库实现。

## libcxxabi

libc++的C++ ABI库。

## libunwind

栈展开库，用于异常处理（如C++异常）的栈展开功能。

## libc

LLVM C标准库。

## openmp

OpenMP运行时库，支持OpenMP并行编程模型。

## libclc

OpenCL（开放计算语言）标准库的实现。

## llvm-libgcc

编译器内置函数的替代实现，替换GNU libgcc中的编译器内置函数。

## offload

目标卸载运行时，管理代码到协处理器（如GPU）的卸载。

## flang-rt

Fortran运行时库。

## libsycl

SYCL（单源异构编程模型）运行时库，支持SYCL异构编程模型。

## orc-rt

On-Request Compilation， ORC JIT（即时编译）引擎的运行时库，用于动态代码生成和执行。
