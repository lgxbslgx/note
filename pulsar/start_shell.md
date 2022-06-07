# pulsar的bin目录的各个启动shell（各个命令）
构建之后，解压缩包，里面的bin、conf、lib目录是代码运行需要的内容，examples、instances、licenses目录暂时没用。
而源码的bin、conf目录则和压缩包中的一样。压缩包的lib目录，源码中使用的类路径(-cp)在本地maven仓库的.m2目录里面获取。

直接看源码bin目录里面的各个脚本最后的代码，即可知道真实运行的主类。

## pulsar命令
日记和输出直接输出到终端（需要自己重定向），不用保存pid，数据默认存在data目录。

命令和主类的对应关系:
```shell
bin/pulsar broker
org.apache.pulsar.PulsarBrokerStarter

bin/pulsar bookie
org.apache.bookkeeper.server.Main

bin/pulsar zookeeper
org.apache.zookeeper.server.quorum.QuorumPeerMain

bin/pulsar global-zookeeper
org.apache.zookeeper.server.quorum.QuorumPeerMain

bin/pulsar standalone
org.apache.pulsar.PulsarStandaloneStarter
```

## pulsar-daemon命令
使用shell的nohub操作来调用pulsar命令，最终要调用上面的pulsar命令。
日记和输出默认存在logs目录，pid默认存在bin目录，数据默认存在data目录。

## pulsar-client命令
模拟消费者、生产者的操作

主类: org.apache.pulsar.client.cli.PulsarClientTool

## pulsar-perf命令
很多子命令，先不管。

## pulsar-admin命令
操作pulsar服务端的命令。
主类: org.apache.pulsar.admin.cli.PulsarAdminTool

## pulsar-managed-ledger-admin命令
未看脚本。

## bookkeeper命令
操作bookkeeper的命令。未具体看。

## function-localrunner命令
未看
