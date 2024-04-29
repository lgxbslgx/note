## graal调试

构建内容在[building.md](/graalvm/build/building.md)

### 调试JIT编译器

```shell
# 进入graal/compiler目录
cd compiler

# 设置JAVA_HOME
export JAVA_HOME=/home/lgx/source/java/jdk22u/build/linux-x86_64-server-release/images/graal-builder-jdk

# 使用mx -d 或者 mx --dgb 开启调试
mx -d -v vm \
--class-path=/home/lgx/source/java/test-graalvm \
-Djvmci.Compiler=graal \
-XX:CompileCommand=compileonly,HelloWorld::test \
-XX:CompileCommand=PrintCompilation,HelloWorld::test \
-XX:CompileThreshold=1 \
-XX:-BackgroundCompilation \
-XX:-TieredCompilation \
-XX:+PrintCommandLineFlags \
HelloWorld

# IDEA打断点，点击调试按钮（远程调试），详见[java-remote-debug](/openjdk/debug/java_remote_debug.md)
# 代码入口在`graal/compiler/src/jdk.graal.compiler/src/jdk/graal/compiler/hotspot/HotSpotGraalCompiler.java::main`
```


### 调试SubstrateVM

```shell
# 进入graal/substratevm目录
cd substratevm

# 设置JAVA_HOME
export JAVA_HOME=/home/lgx/source/java/jdk22u/build/linux-x86_64-server-release/images/graal-builder-jdk

# 调试Driver（注意参数`-d`）
mx -d -v native-image \
--class-path=/home/lgx/source/java/test-graalvm \
--verbose \
HelloWorld

# 调试native-image-configure（注意参数`-d`）
mx -v -d native-image-configure \
generate \
--input-dir=/home/lgx/source/java/test-graalvm/META-INF/native-image \
--output-dir=/home/lgx/source/java/test-graalvm/META-INF/native-image

# 调试静态编译器（注意参数`--debug-attach`）
mx -v native-image \
--class-path=/home/lgx/source/java/test-graalvm \
--verbose \
--debug-attach \
HelloWorld

# IDEA打断点，点击调试按钮（远程调试），详见[java-remote-debug](/openjdk/debug/java_remote_debug.md)
# Driver代码入口在`graal/substratevm/src/com.oracle.svm.driver/src/com/oracle/svm/driver/NativeImage.java::main`
# native-image-configure代码入口在`graal/substratevm/src/com.oracle.svm.configure/src/com/oracle/svm/configure/ConfigurationTool.java::main`
# 静态编译器代码入口在`graal/substratevm/src/com.oracle.svm.hosted/src/com/oracle/svm/hosted/NativeImageGeneratorRunner.java::main`
```
