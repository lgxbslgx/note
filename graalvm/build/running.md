## 使用native-image编译和运行Java程序

### HelloWorld程序

```shell
# 源代码最好用到一些动态功能，比如反射

# 进入目录
cd /home/lgx/source/java/test-graalvm

# 编译
/home/lgx/install/graalvm-22/bin/javac  HelloWorld.java

# 预执行，得到配置文件
/home/lgx/install/graalvm-22/bin/java -cp . -agentlib:native-image-agent=config-output-dir=./META-INF/native-image HelloWorld

# 静态编译，生成native代码
/home/lgx/install/graalvm-22/bin/native-image -cp . HelloWorld

# 运行代码
./helloworld
```

### SpringBoot程序（使用Maven）

详见链接[GraalVM Native Image Support](https://docs.spring.io/spring-boot/docs/current/reference/html/native-image.html)

```shell
# 在 https://start.spring.io/ 中创建一个项目，注意要添加`GraalVM Native Support`依赖

# 进入目录
cd /home/lgx/source/java/test-springboot-graal

# 配置GraalVM的路径
export GRAALVM_HOME=/home/lgx/install/graalvm-22

# 生成native代码
mvn -Pnative native:compile

# 运行代码
./target/test-springboot-graal
```
