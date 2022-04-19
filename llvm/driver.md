### 启动流程

- 解析参数
  driver.cpp的main函数前面绝大部分，Driver::BuildCompilation的绝大部分。解析结果放在Compilation的InputArgList *Args和DerivedArgList *TranslatedArgs中。(ArgList\Arg\Option\types::ID\InputList\InputTy)

- 构造编译管道（Pipeline，各个Action）-ccc-print-phases
  Driver::BuildCompilation调用方法BuildActions或BuildUniversalActions,ConstructPhaseAction。结果存放在Compilation的ActionList Actions和AllActions中。（Action\JobAction\ActionList）

- 根据action找到对应工具 -ccc-print-bindings
  Driver::BuildCompilation调用方法BuildJobs，BuildJobsForAction，BuildJobsForActionNoCache，Tool::ConstructJob，Tool::ConstructJobMultipleOutputs。结果存放在Compilation的JobList Jobs中。（Tool\Command\Job\JobList）

- 构造工具的参数和命令（还没找到具体方法）-###
  

- 依次执行命令
  Driver::ExecuteCompilation调用Compilation::ExecuteJobs，Compilation::ExecuteCommand，Command::Execute

执行的第一个命令很可能是 `clang -cc1 其他参数`。调用过程:
driver.cpp::main
driver.cpp::ExecuteCC1Tool
cc1_main.cpp::cc1_main
ExecuteCompilerInvocation.cpp::ExecuteCompilerInvocation
CompilerInstance.cpp::ExecuteAction
FrontendAction.cpp::Execute
FrontendAction.cpp::ASTFrontendAction::ExecuteAction
ParseAST.cpp::ParseAST
Parse.cpp::ParseTopLevelDecl 词法、语法、语义分析
CodeGenAction.cpp::HandleTopLevelDecl 中间代码（LLVM IR）生成
  ModuleBuilder.cpp::HandleTopLevelDecl
  CodeGenModule.cpp::EmitTopLevelDecl\EmitGlobal\EmitGlobalDefinition\EmitGlobalFunctionDefinition
    CodeGenFunction.cpp::GenerateCode\EmitFunctionBody
CodeGenAction.cpp::HandleTranslationUnit 代码优化和目标代码生产
  BackendUtil.cpp::EmitBackendOutput\EmitAssembly
    BackendUtil.cpp::RunOptimizationPipeline 优化
    BackendUtil.cpp::RunCodegenPipeline 目标代码生成

