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
