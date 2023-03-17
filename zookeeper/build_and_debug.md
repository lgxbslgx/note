### 构建
```shell
mvn clean install -DskipTests
```

### 测试
单元测试
```shell
mvn -pl pulsar-client test -Dtest=NameTest
```
也可以直接在IDE上运行。

运行一个包的测试
```shell
mvn test -Dinclude=org/apache/zookeeper/**/*.java
```

### 调试
直接在ide上启动主类QuorumPeerMain

