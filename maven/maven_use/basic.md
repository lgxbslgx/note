### maven基础概念汇总

- 坐标
- 依赖（depedency）、依赖范围（Scope）、依赖传递
- 仓库（repository）、插件仓库（pluginRepository）、镜像（mirror）
- 生命周期（lifecycle）、阶段（phase）
- 插件（plugin）、目标（goal）、插件的目标和生命周期的阶段绑定(和打包类型有关)
- 生命周期和阶段是固定的。有些插件和目标（大概8个）被默认添加。大部分的插件和目标有默认绑定的阶段。

- mvn [options] [<goal(s)>] [<phase(s)>]  即：mvn可以单独执行目标，也可以执行生命周期绑定的目标。因为有些目标不适合绑定到生命周期。
- 插件解析机制。官方插件默认gouldId: org.apache.maven.plugins。每个官方插件都有一个前缀（缩写名），在maven-metadata-central.xml里面，比如全名是maven-缩写名-plugin。版本号省略则选择最新的发行版本（非快照）。
- 聚合（多模块），为了快速构建。聚合模块的打包方式packaging必须是pom。<modules><module>写的是目录名，不是模块名。
- 继承，为了减少重复配置。<parent><relativePath>是相对路径名，默认是../pom.xml。可为父子目录，也可为平行目录。
- 一个模块可以同时是聚合模块和父模块。
- 依赖管理。只配置依赖，子模块按需导入依赖。推荐使用<dependencyManagement>。依赖范围是import时，类型一定要是pom，表示将目标pom的dependencyManagement导入并合并到当前pom。
- 插件管理。只配置插件，子模块按需导入。
- 约定大于配置
- 反应堆。构建顺序。
- 部署管理。<distrubutionManagement>设置部署的目标地址。可能要修改setting.xml里面的server配置帐号密码。
- 使用maven进行测试。surefire插件。mvn test。-Dmaven.test.skip=true,-DskipTests
- 使用maven部署web应用。war包和maven各个目录的对应关系。packaging为war
- 使用maven进行版本管理（不是版本控制）。maven release 插件

- maven属性。内置属性（basedir、version）、POM属性（和POM节点对应，例如project.groupId）、自定义属性（properties标签）、setting属性（setting.xml里面的pom节点，例如settings。localRepository）、Java系统属性(例如user.home)、环境变量属性(例如env.JAVA_HOME)
- 资源过滤。可以在资源文件中使用maven属性。resources插件和war插件。
- 灵活配置，根据不同场景使用不同配置。profile标签。命令参数使用-P，例如mvn install -Pdev,test 。多种激活profile的方法，<activation>标签。

- 站点生成。site插件。
- 各种报告生成。项目信息：projet-info-reports。java文档：javadoc插件。源代码查看：jxr插件。代码规范检查：checkstyle插件。代码分析：pmd插件。变更记录报告：changelog插件。测试覆盖率报告：cobertura插件。

- 编写maven插件plugin。maven-archetype-plugin。继承AbstrackMojo类，重写execute方法。各种参数。使用maven-invoker-plugin插件进行测试。
- 编写maven项目原型archetype。
