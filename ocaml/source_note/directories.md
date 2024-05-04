## OCaml各个目录的内容

```shell
ocaml
├── asmcomp native代码编译器和链接器（把AST编译成native代码）
├── boot bootstrap编译器
├── build-aux 构建需要的脚本
├── bytecomp 字节码编译器和链接器（把AST编译成字节码）
├── compilerlibs 编译器库
├── debugger 调试器
├── driver 编译器Driver
├── flexdll git克隆下来的子模块
├── lambda 中间代码`lambda`
├── lex 词法分析器创建器
├── middle_end 编译器中端，代码优化相关内容
├── ocamldoc 文档创建器
├── ocamltest 测试驱动器
├── ocaml-variants.opam
├── otherlibs 拓展库函数
├── parsing 语法分析相关代码（生成AST）
├── runtime 字节码解释器和运行时库函数
├── stdlib 标准库函数
├── testsuite 测试代码
├── tools 各种工具
├── toplevel 互动系统
├── typing 类型系统相关代码（类型检测、AST添加类型）
├── utils 工具库函数
└── yacc 语法分析器创建器
```
