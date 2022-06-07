# Pulsar 分布式 发布-订阅 消息平台

## 整体流程
生产者（producer）发送数据到pulsar topic（主题、通道）
生产者（consumer）从topic里面获取数据

topic需要分类，pulsar主要把topic按2层的树状分类（property(tenant)、namespace）。
一个property(tenant)包含多个namespace，一个namespace包含多个topic。
很多配置都是在namespace这个层级进行。


## 订阅模型
一个订阅（subscription）就是一个消费者组。
一个topic有多个订阅。也就是发布订阅pub-sub模型。每个订阅有下面的模型:
- 独享（exclusive）也就是流（stream）模型。多个独享订阅组成发布订阅模型。
- 共享（shared）也就是队列（queue）模型（在发布订阅里面模拟出一个队列模型）
- 失效备援（failover）具有消费者备份的独享

## 数据分区
一个topic的数据可以进行分区保存，分布在多台机器（一个机器称为一个节点？）上。
一个分区主题有多个节点，一个节点有一个bloker进程，管理该节点的多个分区。

消息路由策略:
- 单个分区: 生产者挑选一个分区。每次都把数据写到该分区。
- 轮询分区: 生产者通过轮询把数据平均分布到分区中。
- 哈系分区: 每个消息都带上一个键，通过键的hash值决定写入哪个分区。
- 自定义分区: 生产者自定义函数生成分区对应的数值，然后写入该分区。

## pulsar整体设计
### 第一层: 消息（message）、主题（topic）、订阅（subscription）、游标（cursor），叫使用层？

消息在topic里面有一个偏移量。每个订阅有一个游标。
默认情况下，所有订阅的游标都超过一个消息偏移量之后（也叫消费确认），就可以把该消息从队列中删除。
也可以自定义（在namespace层设置）数据保留策略，消费确认的消息在超过保留阈值（存储大小、保留时间）之后才被删除。

### 第二层: Logical Storage Architecture、Broker、Cursor Tracking，叫服务层？
逻辑存储架构:
bookkeeper的每个节点叫bookie。
一个topic有多个ledger（账簿、总账），一个ledger有多个Fragment，一个fragment有多个entry。
ledger是bookkeeper最小的删除单元。每个fragment的数据（entry）在不同的bookie中存在副本，不一定是完整fragment副本。
Ledgers和Fragments是在Zookeeper中维护和跟踪的逻辑结构。

可以在topic层设置fragment的配置:
Ensemble Size (E) 将要写入的Bookies总数量
Write Quorum Size (Qw) 将要写入的实际的Bookies数量
Ack Quorum Size (Qa) 确认写入Bookies的数量

Broker:
生产者（这里也叫pulsar的客户端）发生某主题的消息给broker，broker对该topic当前fragment使用的bookie进行存储。不成功则新建fragment（使用新的bookie），再重试。当bookie的确认数超过Qa时，则向客户端返回确认信息。
消费者（也叫客户端）发送读取请求给broker，broker根据偏移量从对应的bookie中获取数据，如果失败，则获取该fragment其他bookie的数据，获取后返回给客户端。

Cursor Tracking游标跟踪:
前面说每个订阅都有一个游标，而这个游标则存储在bookkeeper的ledger中。

### 第三层 Bookie Architecture、Broker Caching，叫存储层？
Bookie存储:

写操作: bloker调用bookie的写接口，bookie写一条预写日记（WAL）到日记文件，然后把message放到写缓存（write cache），之后即可返回确认信息。
之后bookie异步地把写缓存中的数据写到磁盘的日记文件（Log Entry files）中进行持久化，同时添加一条（LedgerId, EntryId)到（EntryLogId文件偏移量)的映射 到RocksDB中。

读操作: blocker调用bookie的读接口，bookie先看写缓存（write cache）里面有没有对应数据，没有则看读缓存（read cache）里面有没有对应数据。
也没有则从RocksDB中获取对应条目（即获取EntryLogId文件偏移量），再从日记文件中获取对应的消息。获取消息之后，把该消息存到读缓存供后续使用，最后返回该消息。

Broker缓存:
Broker也会缓存数据在自己的内存中，如果缓存数据存在，读操作直接从broker返回数据，不用通过bookie来获取。


## 资料
- [中文资料汇总](https://blog.51cto.com/u_15278282/2933568)
- [官网](https://pulsar.apache.org/zh-CN/)
- [代码](https://github.com/apache/pulsar)

