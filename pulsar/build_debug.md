# 构建源码和调试

## 构建
构建默认profile(main)
```shell
mvn install -DskipTests
或者
mvn install -Dmaven.test.skip=true
```

只构建core-modules，不构建main。
```shell
mvn install -Pcore-modules,-main -DskipTests
或者
mvn install -Pcore-modules,-main -Dmaven.test.skip=true
```

main比core-modules多出的模块
```
<module>pulsar-broker-shaded</module>
<module>pulsar-client-shaded</module>
<module>pulsar-client-1x-base</module>
<module>pulsar-client-admin-shaded</module>
<module>pulsar-client-all</module>
<module>pulsar-broker-auth-athenz</module>
<module>pulsar-client-auth-athenz</module>
<module>pulsar-sql</module>
<module>structured-event-log</module>
<module>kafka-connect-avro-converter-shaded</module>
<module>jclouds-shaded</module>
<module>docker</module>
<module>tests</module>
```

## 测试
单元测试
```shell
mvn -pl pulsar-client test -Dtest=ConsumerBuilderImplTest
```
也可以直接在IDE上运行。

运行一个包的测试
```shell
mvn test -pl pulsar-broker -Dinclude=org/apache/pulsar/**/*.java
```

## PR里面重新运行失败的单元测试
```shell
/pulsarbot run-failure-checks
```

## 调试
调试standalone
```shell
PULSAR_EXTRA_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,address=*:5005,suspend=y" bin/pulsar standalone
```

调试其他命令
```
PULSAR_EXTRA_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,address=*:5005,suspend=y" bin/pulsar <Pulsar子命令名>
```

