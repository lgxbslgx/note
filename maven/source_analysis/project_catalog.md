## maven源代码 目录结构
[源代码获取地址](https://maven.apache.org/scm.html)

### 各个分组
- [core](https://maven.apache.org/ref/3.8.2/000) 核心部分
- misc 各种无法归类的杂项仓库
- [plugins](https://maven.apache.org/plugins/) 各种插件
- sisu // TODO
- sources 各个仓库列表在sources仓库里面，sources仓库就是信息汇总的聚合模块。
- svn // TODO
- [doxia](https://maven.apache.org/doxia/doxia/) 负责内容创建
- [plexus](https://codehaus-plexus.github.io/) plexus框架代码，这是外部的框架，应该不归maven管，但是也可以给它贡献代码
- [shared](https://maven.apache.org/shared/) 各种共享的组件，被其他模块使用
- site 就是maven官网的代码
- [studies](https://maven.apache.org/studies/) // TODO


### core组, 目录为: maven/core
项目核心部分
- maven-3仓库
  maven3的代码
- maven仓库
  maven主线代码，当前是maven4
- resolver-ant-tasks仓库
  使得ant可以使用maven的resolver来解析构件依赖、部署构件。
- its仓库
  maven集成测试代码，即maven-integration-testing
- resolver仓库
  maven构件的依赖解析，即maven-resolver
- maven-wrapper-plugin仓库
  // TODO

### doxia组, 目录为: maven/doxia
负责内容创建
- doxia仓库
  内容创建框架，用于创建静态、动态资源，支持多种标志语言。
- sitetools仓库
  站点和文档工具，渲染站点和文档。
- tools目录
    - converter仓库
      转换文档，从一个doxia支持的格式到另一个doxia支持的格式
    - doxia-book-renderer仓库
      // TODO
    - doxia-book-maven-plugin仓库
      // TODO
    - linkcheck仓库
      验证html文档中的链接
- site仓库
  // TODO

### plugins组, 目录为: maven/plugins
各种各样的插件
- core目录
  用于生命周期核心阶段的插件
    - maven-deploy-plugin仓库
      部署构件到远程仓库
    - maven-resources-plugin仓库
      拷贝资源到输出目录
    - maven-install-plugin仓库
      按照构件到本地仓库
    - maven-clean-plugin仓库
      清理构件
    - maven-site-plugin仓库
      为当前项目创建站点
    - surefire仓库
      运行单元测试
    - maven-verifier-plugin仓库
      验证状态。用于集成测试
    - maven-compiler-plugin仓库
      编译java代码
- tools目录
  各种杂项（未归类）工具
    - maven-jdeprscan-plugin仓库
      运行jdepr扫描工具
    - maven-pdf-plugin仓库
      创建项目文档的pdf版本
    - maven-assembly-plugin仓库
      构建自定义的分发包。构建源代码和/或二进制文件的程序集
    - release仓库
      发布项目，项目管理。
    - maven-scripting-plugin仓库
      脚本插件，封装JSR223的脚本api
    - maven-antrun-plugin仓库
      运行ant任务，注意和resolver-ant-tasks不同
    - maven-scm-publish-plugin仓库
      发布站点到scm路径
    - maven-dependency-plugin仓库
      依赖操作、依赖分析
    - maven-help-plugin仓库
      获取环境、项目的帮助信息
    - enforcer仓库
      环境约束检测、用户自定义规则执行
    - maven-patch-plugin仓库
      使用gnu的patch工具来给源代码打补丁
    - maven-toolchains-plugin仓库
      运行在插件间共享配置
    - maven-gpg-plugin仓库
      创建gpg签名
    - plugin-tools仓库
      // TODO
    - maven-jarsigner-plugin仓库
      签署或者验证构件
    - maven-artifact-plugin仓库
      管理构建任务
    - maven-invoker-plugin仓库
      负责maven插件的测试。运行maven项目并验证输出。
    - scm仓库
      集成版本控制系统
    - maven-stage-plugin仓库
      协助发布分期和推广
    - maven-remote-resources-plugin仓库
      复制远程资源到输出目录
    - archetype仓库
      创建项目骨架（原型）
- reporting目录
    - maven-changes-plugin仓库
      从问题跟踪器或更改文档生成报告
    - maven-pmd-plugin仓库
      创建pmd报告（代码分析报告）
    - maven-jdeps-plugin仓库
      运行jdk的jdeps工具
    - jxr仓库
      创建源代码查看站点，生成源码交叉引用文档
    - maven-linkcheck-plugin仓库
      链接检查报告
    - maven-doap-plugin仓库
      创建项目描述报告
    - maven-project-info-reports-plugin仓库
      标准项目报告
    - maven-docck-plugin仓库
      文档检测器报告
    - maven-changelog-plugin仓库
      变更记录报告
    - maven-javadoc-plugin仓库
      创建javadoc
    - maven-checkstyle-plugin仓库
      样式检测报告
- packaging目录
    - maven-jmod-plugin仓库
      构建java的jmod文件
    - maven-jlink-plugin仓库
      构建java运行时镜像
    - maven-shade-plugin仓库
      构建Uber-JAR，构建包含依赖的jar包。
    - maven-acr-plugin仓库
      // TODO
    - maven-jar-plugin仓库
      构建jar文件
    - maven-rar-plugin仓库
      构建rar文件
    - maven-ejb-plugin仓库
      构建ejb文件
    - maven-source-plugin仓库
      构建source-JAR
    - maven-war-plugin仓库
      构建war文件
    - maven-ear-plugin仓库
      构建EAR文件

### shared组, 目录为: maven/shared
共享组件
- shared-resources仓库
  maven项目模板集合
- jarsigner仓库
  签名和验证组件
- filtering仓库
  过滤资源组件
- artifact-transfer仓库
  按照、发布、解析构件的api
- script-interpreter仓库
  解析和执行脚本的工具
- verifier仓库
  验证工具
- reporting-impl仓库
  报告创建的工具类
- invoker仓库
  在新的 JVM 中启动 Maven 构建
- dependency-analyzer仓库
  依赖分析工具
- project-utils仓库
  // TODO
- mapping仓库
  映射工具
- reporting-exec仓库
  管理报告插件准备的api
- shared-jar仓库
  识别jar包的内容，类分析、maven元数据分析
- reporting-api仓库
  管理报告创建的api
- file-management仓库
  文件管理，利用include/exclude规则来收集文件
- shared-utils仓库
  maven内部共享的工具方法
- shared-io仓库
  共享的io支持，日记、下载、文件扫描等api
- common-artifact-filters仓库
  构件实例的过滤器
- archiver仓库
  管理包的工具
- dependency-tree仓库
  构建项目依赖树的工具
- shared-incremental仓库
  支持增量构建的工具

### svn组, 目录为: maven/svn
// TODO
- resources仓库
- sandbox仓库
- doxia-ide仓库
- repository-tools仓库

### studies组, 目录为: maven/studies
// TODO
- master仓库
- maven-default-plugins仓库
- maven-ci-extension仓库
- maven-extension-demo仓库
- consumer-pom仓库
- maven-basedir-filesystem仓库
- maven-eventsound-extension仓库
- maven-xml仓库

### sources组, 目录为: maven/sources
- sources仓库
  各个仓库列表在sources仓库里面，sources仓库就是信息汇总的聚合模块。

### sisu组, 目录为: maven/sisu
// TODO
- mojos仓库
- inject仓库
- plexus仓库

### site组, 目录为: maven/site
- site仓库
  maven官方网站的代码

### misc组, 目录为: maven/misc
各种杂项仓库
- wagon仓库
- indexer仓库
- skins目录
    - fluido仓库
    - default仓库
- dist-tool仓库
- pom目录
    - apache仓库
    - maven仓库
- plugin-testing仓库
- archetypes仓库
- jenkins目录
    - lib仓库
    - env仓库

### plexus组, 目录为: maven/plexus
- utils仓库
- codehaus-plexus.github.io仓库
- pom目录
    - components仓库
    - plexus仓库
- modello仓库
- classworlds仓库
- plexus-containers仓库
- components目录
    - resources仓库
    - digest仓库
    - cli仓库
    - velocity仓库
    - interpolation仓库
    - compiler仓库
    - io仓库
    - swizzle仓库
    - sec-dispatcher仓库
    - languages仓库
    - interactivity仓库
    - cipher仓库
    - archiver仓库
    - i18n仓库

