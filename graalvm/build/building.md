## 构建GraalVM

### 基本设置

```shell
# 下载mx
git clone https://github.com/graalvm/mx.git

# 设置path
export PATH=/home/lgx/install/mx:$PATH

# 设置JAVA_HOME（使用`make graal-builder-image`构建的JDK才行）
export JAVA_HOME=/home/lgx/source/java/jdk22u/build/linux-x86_64-server-release/images/graal-builder-jdk

# 下载GraalVM
git clone git@github.com:oracle/graal.git

# 进入目录
cd graal

# 构建substratevm
mx -p substratevm build

# 创建Intellij IDEA需要的元数据（substratevm项目）
mx -p substratevm ideclean
mx -p substratevm intellijinit

# 根据子目录的README文档来进行构建
```


### 构建Graal发行包（distribution）

```shell
# 进入graal/vm子目录
cd vm

# 使用配置文件 mx.vm/ce 进行构建
mx --env ce build
```


### 构建SubstrateVM

```shell
# 进入graal/substratevm子目录
cd substratevm

# 构建
mx build

# 运行，相当于`java`命令，只是对应的`java`命令是我们构建的，并指定了一些特殊参数
mx vm
```


### 构建JIT编译器

```shell
# 进入graal/compiler子目录
cd compiler

# 构建
mx build

# 运行，相当于`java`命令，只是对应的`java`命令是我们构建的，并指定了一些特殊参数
mx vm
```
