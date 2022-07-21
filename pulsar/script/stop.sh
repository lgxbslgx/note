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
