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

# 上面的mx命令最终使用下面的命令开启调试
/home/lgx/source/java/graal/sdk/mxbuild/linux-amd64/GRAALJDK_CE_1602C36D2E_JAVA22/graaljdk-ce-1602c36d2e-java22-24.1.0-dev/bin/java \
-server -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -Djdk.graal.CompilationFailureAction=Diagnose -Djdk.graal.DumpOnError=true \
-Djdk.graal.ShowDumpFiles=true -Djdk.graal.PrintGraph=Network -Djdk.graal.ObjdumpExecutables=objdump,gobjdump \
-Dgraalvm.locatorDisabled=true -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=y -XX:+UseJVMCICompiler \
--class-path=/home/lgx/source/java/test-graalvm -Djvmci.Compiler=graal -XX:CompileCommand=compileonly,HelloWorld::test \
-XX:CompileCommand=PrintCompilation,HelloWorld::test -XX:CompileThreshold=1 -XX:-BackgroundCompilation -XX:-TieredCompilation HelloWorld
```


### 调试SubstrateVM

```shell
# 进入项目目录
cd /home/lgx/source/java/test-graalvm

# 设置JAVA_HOME
export JAVA_HOME=/home/lgx/source/java/jdk22u/build/linux-x86_64-server-release/images/graal-builder-jdk

# 开启调试
/home/lgx/source/java/graal/sdk/mxbuild/linux-amd64/GRAALVM_3AE5F1FE8B_JAVA22/graalvm-3ae5f1fe8b-java22-24.1.0-dev/bin/native-image \
--verbose \
--class-path=/home/lgx/source/java/test-graalvm \
--debug-attach \
HelloWorld

# IDEA打断点，点击调试按钮（远程调试），详见[java-remote-debug](/openjdk/debug/java_remote_debug.md)
# 代码入口在`graal/substratevm/src/com.oracle.svm.driver/src/com/oracle/svm/driver/NativeImage.java::main`
```
