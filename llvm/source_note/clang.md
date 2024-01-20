### clang编译基本流程

调用过程:
driver.cpp::main
driver.cpp::ExecuteCC1Tool
cc1_main.cpp::cc1_main
  - 初始化target信息，放在静态变量TargetRegistry::FirstTarget链表中。
  - 初始化target，把target相关的优化pass放到PassRegistry::PassRegistryObj。
  - 初始化汇编器、反汇编器信息，放到Target中。
  - CompilerInvocation::CreateFromArgs 从参数中构造CompilerInvocation
    - CompilerInvocation.cpp::RoundTrip 先获取假的CompilerInvocation，调用它来创建命令行参数，再继续执行下面代码来创建真的CompilerInvocation
    - CompilerInvocation::CreateFromArgsImpl 创建CompilerInvocation，里面保存各种参数？
ExecuteCompilerInvocation.cpp::ExecuteCompilerInvocation
  - ExecuteCompilerInvocation.cpp::CreateFrontendAction
    - CreateFrontendBaseAction 根据CompilerInvocation的ActionKind ProgramAction获取FrontendAction
CompilerInstance.cpp::ExecuteAction  执行上一步获取的FrontendAction
  - CompilerInstance::createTarget 很奇怪，前面已经初始化Target信息了，不知道为什么还要创建Target
  - FrontendAction::PrepareToExecute 如果子类没有override则返回true
    - FrontendAction::PrepareToExecuteAction
  - FrontendAction::isModelParsingAction 如果子类没有override则返回false
  - FrontendAction::BeginSourceFile 一些准备、初始化操作，很多内容
    - FrontendAction::BeginInvocation
    - FrontendAction::BeginSourceFileAction 初始化action
    - FrontendAction::CreateWrappedASTConsumer 创建一个AST处理器，也就是创建 中间代码产生器BackendConsumer
      - FrontendAction::CreateASTConsumer
  - FrontendAction::Execute
    - FrontendAction.cpp::CodeGenAction::ExecuteAction
      - ASTFrontendAction::ExecuteAction
        - CompilerInstance::createSema 创建语义分析器Sema，放到CompilerInstance中。CompilerInstance在FrontendAction中，也就是在ASTFrontendAction、CodeGenAction中。
        - ParseAST.cpp::ParseAST 具体的编译器操作，看下一部分的内容
  - FrontendAction::EndSourceFile 收尾操作
    - FrontendAction::EndSourceFileAction
  

### 具体编译步骤 ParseAST.cpp::clang::ParseAST

#### 初始化
从Sema中获取Preprocessor，使用Sema和Prepeocessor构建Parser。
Preprocessor::EnterMainSourceFile 未认真看
Parser.cpp::Initialize Parser初始化，同时初始化Sema，获取第一个token(CompilerInstance里面有Sema和Preprocessor，但是没有Parser，很奇怪)

#### 编译 (-dump-raw-tokens) 预处理（-E）、词法(-dump-tokens)、语法(-ast-dump)、语义分析(没有找到参数)
编译结果(AST)放在局部变量Parser::DeclGroupPtrTy ADecl中，中间代码生成阶段继续使用该变量。

Parser::ParseFirstTopLevelDecl 做一些开始处理，中间要调用Parser.cpp::ParseTopLevelDecl获取一个顶层的Decl(声明或定义)。
  - Sema::ActOnStartOfTranslationUnit 没懂
  - Parser.cpp::ParseTopLevelDecl
  - 没有顶层定义，在某些条件下会报错

Parser.cpp::ParseTopLevelDecl 一个递归下降的Parser实现，根据当前token执行对应方法进行parse。
  - Parser::ParseExternalDeclaration 如果当前token没有对应方法，则调用该方法parse外部定义？
    - Parser::ParseDeclaration 继续递归下降

Parser.cpp在语法分析时，使用Sema &Actions的各种方法进行语义分析。

#### 中间代码生成
中间代码（LLVM IR）生成(-emit-llvm -S 生成LLIR汇编文件.ll) （-emit-llvm -c 生成LLIR字节码文件.bc）
生成的AST、LLVM IR放在模块Module中(CodeGeneratorImpl里的std::unique_ptr<llvm::Module> M)

CodeGenAction.cpp::BackendConsumer::HandleTopLevelDecl
  - ModuleBuilder.cpp::CodeGeneratorImpl::HandleTopLevelDecl
    - CodeGenModule.cpp::CodeGenModule::EmitTopLevelDecl
      - EmitGlobal\EmitGlobalDefinition\EmitGlobalFunctionDefinition
        - CodeGenFunction.cpp::GenerateCode\EmitFunctionBody


#### 代码优化和目标代码生产
CodeGenAction.cpp::BackendConsumer::HandleTranslationUnit
  - ModuleBuilder.cpp::CodeGeneratorImpl::HandleTranslationUnit 好像没做什么...
  - BackendUtil.cpp::EmbedBitcode 生成bitcode到"__LLVM,__bitcode"段
  - BackendUtil.cpp::EmitBackendOutput 开始具体操作
    - BackendUtil.cpp::EmitAssemblyHelper::EmitAssembly
      - BackendUtil.cpp::EmitAssemblyHelper::RunOptimizationPipeline 优化。
        PassBuilder PB负责分类别构建、注册(保存)Pass和AnalysisManager(里面也是各种Pass)。
        ModulePassManager MPM负责最终执行的优化的注册和执行,按注册顺序执行。ModulePassManager也就是PassManager<Module>。
        PassBuilder保存Pass和AnalysisManager后，调用它的build*方法，根据对应的优化类型(build*方法名)，获得一个Pass排好顺序的PassManager。PassManager也可自行添加一些Pass。
        之后调用PassManager::run，即可逐个按顺序运行PassManager的所有Pass。
      - BackendUtil.cpp::EmitAssemblyHelper::RunCodegenPipeline 目标代码生成
        使用旧的PassManager，添加一些生成代码Pass，调用run方法。

问题:
最开始注册的target相关的优化在哪里被调用？很多地方都用到，没认真看;

