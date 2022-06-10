# pulsar部署

## 单体部署
正常运行
```shell
// start
bin/pulsar standalone

Ctrl-C to stop the server
```

后台运行
```shell
// start
bin/pulsar-daemon start standalone

// stop
bin/pulsar-daemon stop standalone

// restart
bin/pulsar-daemon restart standalone
```

## 集群部署
- [集群部署-官网](https://pulsar.apache.org/docs/next/deploy-bare-metal)
- [集群部署-详细](https://huangzhongde.cn/post/Linux/Pulsar_Cluster_Deploy/)
- [集群部署-差不多](https://www.freesion.com/article/14141334205/)
- [单机搭建集群](https://blog.51cto.com/u_13491808/3125508)

一台机器部署zookeeper、bookkeeper、broker集群方法：

单机部署zookeeper集群
```shell
// 创建目录
cd /home/lgx/install/pulsar-cluster
mkdir -p zk1/data
mkdir -p zk2/data
mkdir -p zk3/data
mkdir -p zk1/log
mkdir -p zk2/log
mkdir -p zk3/log

// 复制配置文件
cp apache-pulsar/conf/ zk1 -r
cp apache-pulsar/conf/ zk2 -r
cp apache-pulsar/conf/ zk3 -r

// 修改配置文件
vim zk1/conf/zookeeper.conf
dataDir=/home/lgx/install/pulsar-cluster/zk1/data
metricsProvider.httpPort=8000
clientPort=2181
admin.serverPort=9990
server.1=127.0.0.1:2888:3888
server.2=127.0.0.1:2889:3889
server.3=127.0.0.1:2890:3890

// zk2修改配置文件
vim zk2/conf/zookeeper.conf
dataDir=/home/lgx/install/pulsar-cluster/zk2/data
metricsProvider.httpPort=8001
clientPort=2182
admin.serverPort=9991
server.1=127.0.0.1:2888:3888
server.2=127.0.0.1:2889:3889
server.3=127.0.0.1:2890:3890

// zk3修改配置文件
vim zk3/conf/zookeeper.conf
dataDir=/home/lgx/install/pulsar-cluster/zk3/data
metricsProvider.httpPort=8002
clientPort=2183
admin.serverPort=9992
server.1=127.0.0.1:2888:3888
server.2=127.0.0.1:2889:3889
server.3=127.0.0.1:2890:3890

// 指定节点id
echo 1 > zk1/data/myid
echo 2 > zk2/data/myid
echo 3 > zk3/data/myid

// 启动zookeeper
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk1/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk1/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk1/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start zookeeper

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk2/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk2/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk2/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start zookeeper

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk3/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk3/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk3/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start zookeeper

// 初始化集群元数据
/home/lgx/source/java/pulsar/bin/pulsar initialize-cluster-metadata \
  --cluster pulsar-cluster-zk \
  --metadata-store 127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183 \
  --configuration-metadata-store 127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183 \
  --web-service-url http://127.0.0.1:8880,127.0.0.1:8881,127.0.0.1:8882 \
  --web-service-url-tls https://127.0.0.1:8443,127.0.0.1:8444,127.0.0.1:8445 \
  --broker-service-url pulsar://127.0.0.1:6650,127.0.0.1:6651,127.0.0.1:6652 \
  --broker-service-url-tls pulsar+ssl://127.0.0.1:6750,127.0.0.1:6751,127.0.0.1:6752

// 查看状态
/home/lgx/source/java/pulsar/bin/pulsar zookeeper-shell -timeout 5000 -server 127.0.0.1:2181
ls /

// 停止zookeeper
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk1/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk1/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk1/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop zookeeper

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk2/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk2/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk2/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop zookeeper

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/zk3/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/zk3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/zk3/conf/log4j2.yaml \
PULSAR_ZK_CONF=/home/lgx/install/pulsar-cluster/zk3/conf/zookeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop zookeeper
```

单机部署bookkeeper集群
```shell
// 创建目录
cd /home/lgx/install/pulsar-cluster
mkdir -p bk1/data
mkdir -p bk2/data
mkdir -p bk3/data
mkdir -p bk1/log
mkdir -p bk2/log
mkdir -p bk3/log

// 复制配置文件
cp apache-pulsar/conf/ bk1 -r
cp apache-pulsar/conf/ bk2 -r
cp apache-pulsar/conf/ bk3 -r

// bk1修改配置文件
vim bk1/conf/bookkeeper.conf
bookiePort=3182
prometheusStatsHttpPort=8080
httpServerPort=8080
advertisedAddress=127.0.0.1
journalDirectory=/home/lgx/install/pulsar-cluster/bk1/data/journal
ledgerDirectories=/home/lgx/install/pulsar-cluster/bk1/data/ledgers
zkServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183

// bk2修改配置文件
vim bk2/conf/bookkeeper.conf
bookiePort=3183
prometheusStatsHttpPort=8081
httpServerPort=8081
advertisedAddress=127.0.0.1
journalDirectory=/home/lgx/install/pulsar-cluster/bk2/data/journal
ledgerDirectories=/home/lgx/install/pulsar-cluster/bk2/data/ledgers
zkServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183

// bk3修改配置文件
vim bk3/conf/bookkeeper.conf
bookiePort=3184
prometheusStatsHttpPort=8082
httpServerPort=8082
advertisedAddress=127.0.0.1
journalDirectory=/home/lgx/install/pulsar-cluster/bk3/data/journal
ledgerDirectories=/home/lgx/install/pulsar-cluster/bk3/data/ledgers
zkServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183

// 启动bookkeeper
BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk1/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start bookie

BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk2/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk2/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk2/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start bookie

BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk3/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk3/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk3/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start bookie

// 查看状态
BOOKIE_LOG_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/log4j2.yaml \
BOOKIE_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/bookkeeper shell bookiesanity

BOOKIE_LOG_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/log4j2.yaml \
BOOKIE_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/bookkeeper shell simpletest \
--ensemble 3 --writeQuorum 2 --ackQuorum 2

// 停止bookkeeper
BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk1/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk1/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop bookie

BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk2/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk2/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk2/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop bookie

BOOKIE_LOG_DIR=/home/lgx/install/pulsar-cluster/bk3/log \
BOOKIE_PID_DIR=/home/lgx/install/pulsar-cluster/bk3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/bk3/conf/log4j2.yaml \
PULSAR_BOOKKEEPER_CONF=/home/lgx/install/pulsar-cluster/bk3/conf/bookkeeper.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop bookie
```

单机部署broker集群
```shell
// 创建目录
cd /home/lgx/install/pulsar-cluster
mkdir -p broker1/data
mkdir -p broker2/data
mkdir -p broker3/data
mkdir -p broker1/log
mkdir -p broker2/log
mkdir -p broker3/log

// 复制配置文件
cp apache-pulsar/conf/ broker1 -r
cp apache-pulsar/conf/ broker2 -r
cp apache-pulsar/conf/ broker3 -r

// broker1修改配置文件
vim broker1/conf/broker.conf
clusterName=pulsar-cluster-zk
loadBalancerOverrideBrokerNicSpeedGbps=0.8
zookeeperServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
configurationStoreServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
brokerServicePort=6650
brokerServicePortTls=6750
webServicePort=8880
webServicePortTls=8443

// broker2修改配置文件
vim broker2/conf/broker.conf
clusterName=pulsar-cluster-zk
loadBalancerOverrideBrokerNicSpeedGbps=0.8
zookeeperServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
configurationStoreServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
brokerServicePort=6651
brokerServicePortTls=6751
webServicePort=8881
webServicePortTls=8444

// broker3修改配置文件
vim broker3/conf/broker.conf
clusterName=pulsar-cluster-zk
loadBalancerOverrideBrokerNicSpeedGbps=0.8
zookeeperServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
configurationStoreServers=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
brokerServicePort=6652
brokerServicePortTls=6752
webServicePort=8882
webServicePortTls=8445

// 启动broker
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker1/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker1/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker1/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start broker

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker2/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker2/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker2/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start broker

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker3/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker3/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker3/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon start broker

// 查看状态
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/client/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-admin brokers list pulsar-cluster

// 停止broker
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker1/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker1/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker1/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker1/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop broker

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker2/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker2/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker2/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker2/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop broker

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/broker3/log \
PULSAR_PID_DIR=/home/lgx/install/pulsar-cluster/broker3/data \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/broker3/conf/log4j2.yaml \
PULSAR_BROKER_CONF=/home/lgx/install/pulsar-cluster/broker3/conf/broker.conf \
/home/lgx/source/java/pulsar/bin/pulsar-daemon stop broker
```

client和admin验证
```shell
// 创建目录
cd /home/lgx/install/pulsar-cluster
mkdir -p client/data
mkdir -p client/log

// 复制配置文件
cp apache-pulsar/conf/ client -r

// client修改配置文件
vim client/conf/client.conf
webServiceUrl=http://127.0.0.1:8880/

// 运行admin
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-admin brokers list pulsar-cluster

// 运行client
// 生产者
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-client produce \
persistent://public/default/test -n 1 -m "Hello Pulsar"

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-client produce my-topic --messages "hello-pulsar"

// 消费者
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-client consume \
persistent://public/default/test -n 1 -s "consumer-test" -t "Exclusive"

PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/client/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/client/conf/log4j2.yaml \
PULSAR_CLIENT_CONF=/home/lgx/install/pulsar-cluster/client/conf/client.conf \
/home/lgx/source/java/pulsar/bin/pulsar-client consume my-topic -s "first-subscription"
```

Pulsar SQL 运行
```shell
// 创建目录
cd /home/lgx/install/pulsar-cluster
mkdir -p sql

// 复制配置文件
cp apache-pulsar/conf/ sql -r

// 修改配置文件
vim sql/conf/presto/catalog/pulsar.properties
pulsar.web-service-url=http://127.0.0.1:8880,127.0.0.1:8881,127.0.0.1:8882
pulsar.zookeeper-uri=127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
vim sql/conf/presto/config.properties
http-server.http.port=8085
discovery.uri=http://localhost:8085

// 运行sql-worker
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/sql/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/sql/conf/log4j2.yaml \
PULSAR_PRESTO_CONF=/home/lgx/install/pulsar-cluster/sql/conf/presto \
/home/lgx/source/java/pulsar/bin/pulsar sql-worker run

// 运行sql
PULSAR_LOG_DIR=/home/lgx/install/pulsar-cluster/sql/log \
PULSAR_LOG_CONF=/home/lgx/install/pulsar-cluster/sql/conf/log4j2.yaml \
PULSAR_PRESTO_CONF=/home/lgx/install/pulsar-cluster/sql/conf/presto \
/home/lgx/source/java/pulsar/bin/pulsar sql

```

## 多集群部署
// TODO
[多集群部署](https://pulsar.apache.org/docs/next/deploy-bare-metal-multi-cluster/)
