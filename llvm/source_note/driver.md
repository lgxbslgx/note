### Driver流程

- 解析参数
  driver.cpp的main函数前面绝大部分，Driver::BuildCompilation的绝大部分。解析结果放在Compilation的InputArgList *Args和DerivedArgList *TranslatedArgs中。(ArgList\Arg\Option\types::ID\InputList\InputTy)
  - 初始化target信息，放在静态变量TargetRegistry::FirstTarget链表中。
  - 初始化target，把target相关的优化pass放到PassRegistry::PassRegistryObj。
  - 处理一些特殊的参数，比如参数文件展开(@file-name)、还有很多参数处理。
  - Driver::ParseArgStrings构造InputArgList，Driver::TranslateInputArgs根据InputArgList构建DerivedArgList，最终的参数在它们的父类ArgList中
  - 根据InputArgList获取ToolChain(Linux)
  - 根据InputArgList、DerivedArgList、ToolChain构造Compilation
  - 根据DerivedArgList构造输入文件列表InputList，InputList是一个元素InputTy的list，每个InputTy是2元组types::ID、Arg。

- 构造编译管道（Pipeline，各个Action）-ccc-print-phases
  Driver::BuildCompilation调用方法BuildActions或BuildUniversalActions,ConstructPhaseAction。结果存放在Compilation的ActionList Actions和AllActions中。（Action\JobAction\ActionList）
  - BuildActions特殊处理几个参数
  - BuildActions调用handleArguments，处理一些特殊的编译阶段。根据每个输入文件类型，getCompilationPhases在Types.def中获取该文件类型对应的编译阶段Phase，然后去除LastPhase后面的阶段phase，获取其中特殊的阶段，构造编译任务。
  - BuildActions继续根据输入文件类型，使用types::getCompilationPhases在Types.def中获取该文件类型对应的编译阶段Phases。之后先对每个文件构造一个InputAction，再对每个编译阶段Phase调用ConstructPhaseAction构建Action。
  - ConstructPhaseAction根据Phase的类型调用Compilation::MakeAction方法来构建Action，并放到Compilation::AllActions中。BuildActions在某个文件的所有阶段ConstructPhaseAction返回后，自行将该文件最后阶段的action放到Compilation::Actions中。即Actions放的是文件的最后Action，并可以在类外可见，AllActions存放所有Action，类外不可见。Action的字段ActionList Inputs包含了该Action依赖的Action，所以ActionList Actions列表可以表示全部的action。


- 根据action找到对应工具 -ccc-print-bindings
  Driver::BuildCompilation调用方法BuildJobs，BuildJobsForAction，BuildJobsForActionNoCache，Tool::ConstructJob，Tool::ConstructJobMultipleOutputs。结果存放在Compilation的JobList Jobs中。（Tool及其子类Clang等）
  - BuildJobs先特殊处理一些关于AIX、mach0等的问题，先忽略
  - 遍历每一个action，使用方法BuildJobsForAction构建工具
  - 先从CachedResults里面找，看有没有，没有则调用BuildJobsForActionNoCache进行构造
  - BuildJobsForActionNoCache先处理OffloadAction、InputAction、BindArchAction，先忽略
  - 处理JobAction，构建工具选择器ToolSelector，调用方法ToolSelector::getTool获取工具
    - ToolSelector::getTool先构造一个ActionChain，里面有该JobAction及其依赖的所有Action
    - ToolSelector::getTool调用combineAssembleBackendCompile、combineAssembleBackend、combineBackendCompile、ToolChain::SelectTool选择工具
    - ToolChain::SelectTool调用ToolChain::getTool，根据Action的种类Kind,即ActionClass，来获取相关工具Tool。假设获取到Clang工具。


- 构造工具的参数和命令(Command\CC1Command\JobList) -###
  Tool::ConstructJob构造Job(比如Clang::ConstructJob)，Clang::ConstructJob内容太多，一个方法将近3000行代码，先不细看了。
  - Driver::BuildJobsForActionNoCache调用Tool::ConstructJob和ConstructJobMultipleOutputs构造命令Command
  - Tool::ConstructJob最终通过Compilation::addCommand添加命令(Command)到Compilation::JobList Jobs中
  

- 依次执行命令
  Driver::ExecuteCompilation调用Compilation::ExecuteJobs，Compilation::ExecuteCommand，Command::Execute

执行的第一个命令很可能是 `clang -cc1 其他参数`，调用过程在clang.md中。

