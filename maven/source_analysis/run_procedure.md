### maven主要运行过程

#### 整体流程 
Launcher->
MavenCli->
DefaultMaven->
LifecycleStarter->
Builder(SingleThreadedBuilder、MultiThreadedBuilder)->
LifecycleModuleBuilder->
MojoExecutor->
BuildPluginManager->
执行具体的Mojo


#### 具体流程
- 从plexus开始启动（maven的bin和boot目录）
  boot目录的plexus-classworlds包添加到classpath， 使用java命令，启动主类plexus-classworlds-2.6.0.jar!/org/codehaus/plexus/classworlds/launcher/Launcher

- 获取更多包和配置（即获取maven的conf和lib目录）
  根据bin/m2.conf的配置，设置conf、conf/logging、lib、lib/ext目录，同时获取ClassRealm和主类org.apache.maven.cli.MavenCli，构建ClassWorld（包含ClassRealm和ClassWorldListener)。

- 跳到maven的主类
  调用主类（org.apache.maven.cli.MavenCli）的main方法，传入上一步构建的ClassWorld

- maven实际操作
  构建CliRequest（里面是各种配置信息，包含ClassWorld），执行MavenCli对象的doMain方法
  
- 初始化CliRequest
  initialize方法初始化一些目录，cli方法初始化CLIManager（参数集）和初始化命令行参数，properties方法初始化各种属性，logging方法初始化日记输出设置。

- 输出帮助和版本信息
  informativeCommands方法和version方法。

- 构建PlexusContainer和配置MavenCli
  container方法。PlexusContainer包含maven的各个构件和包，使用它来配置MavenCli的字段。

- 输出日记配置情况
  commands方法。

- 执行配置处理器
  configure方法。执行ConfigurationProcessor的proess方法。获取用户（-s参数，默认~/.m2/setting.xml）和全局(-gs，默认maven/conf/setting.xml)的setting.xml文件，分析文件内容，存放在`CliRequest`的字段`MavenExecutionRequest request`中。

- 配置工具链
  toolchains方法。获取工具链配置文件（用户-t参数，默认maven/conf/toolchains.xml，全局-gt参数，默认~/.m2/toolchains.xml)。解析文件，放在`CliRequest.MavenExecutionRequest request.toolchains`中。

- 解析命令行参数
  populateRequest方法。解析命令行参数，根据参数内容修改和补全`CliRequest`和`CliRequest.MavenExecutionRequest request`。

- 加密处理
  encryption方法。处理`-emp`和`ep`参数，处理完直接返回。

- 设置遗留本地仓库
  repository方法。设置`CliRequest.MavenExecutionRequest request`的内容。

- 执行maven请求（即之前创建和配置的CLiRequest）
  execute方法。
  使用默认配置再次补全CLiRequest。
  执行DefaultMaven的execute和doExecute方法。

- 执行具体操作前的准备工作
  根据配置信息，创建RepositorySystemSession、MavenSession等

- 开始发现项目ProjectDiscoveryStarted
  构建项目依赖图ProjectDependencyGraph。获取项目映射关系`Map<String, MavenProject>`。构建ChainedWorkspaceReader。

- 开始maven生命周期（使用MavenSession）
  // TODO
