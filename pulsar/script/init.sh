/home/lgx/source/java/pulsar/bin/pulsar initialize-cluster-metadata \
  --cluster pulsar-cluster-zk \
  --metadata-store 127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183 \
  --configuration-metadata-store 127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183 \
  --web-service-url http://127.0.0.1:8880,127.0.0.1:8881,127.0.0.1:8882 \
  --web-service-url-tls https://127.0.0.1:8443,127.0.0.1:8444,127.0.0.1:8445 \
  --broker-service-url pulsar://127.0.0.1:6650,127.0.0.1:6651,127.0.0.1:6652 \
  --broker-service-url-tls pulsar+ssl://127.0.0.1:6750,127.0.0.1:6751,127.0.0.1:6752
