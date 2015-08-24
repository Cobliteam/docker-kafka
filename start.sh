#!/bin/bash -x

# If a ZooKeeper container is linked with the alias `zookeeper`, use it.
# You MUST set ZOOKEEPER_IP in env otherwise.
[ -n "$ZOOKEEPER_PORT_2181_TCP_ADDR" ] && ZOOKEEPER_IP=$ZOOKEEPER_PORT_2181_TCP_ADDR
[ -n "$ZOOKEEPER_PORT_2181_TCP_PORT" ] && ZOOKEEPER_PORT=$ZOOKEEPER_PORT_2181_TCP_PORT

IP=$(cat /etc/hosts | head -n1 | awk '{print $1}')

cat /kafka/config/server.properties.template \
  | sed "s|{{ZOOKEEPER_IP}}|${ZOOKEEPER_IP}|g" \
  | sed "s|{{ZOOKEEPER_PORT}}|${ZOOKEEPER_PORT:-2181}|g" \
  | sed "s|{{ZOOKEEPER_CHROOT}}|${ZOOKEEPER_CHROOT:-}|g" \
  | sed "s|{{KAFKA_BROKER_ID}}|${KAFKA_BROKER_ID:-0}|g" \
  | sed "s|{{KAFKA_ADVERTISED_HOST_NAME}}|${KAFKA_ADVERTISED_HOST_NAME:-$IP}|g" \
  | sed "s|{{KAFKA_PORT}}|${KAFKA_PORT:-9092}|g" \
  | sed "s|{{KAFKA_ADVERTISED_PORT}}|${KAFKA_ADVERTISED_PORT:-9092}|g" \
   > /kafka/config/server.properties

# Kafka's built-in start scripts set the first three system properties here, but
# we add two more to make remote JMX easier/possible to access in a Docker
# environment:
#
#   1. RMI port - pinning this makes the JVM use a stable one instead of
#      selecting random high ports each time it starts up.
#   2. RMI hostname - normally set automatically by heuristics that may have
#      hard-to-predict results across environments.
#
# These allow saner configuration for firewalls, EC2 security groups, Docker
# hosts running in a VM with Docker Machine, etc. See:
#
# https://issues.apache.org/jira/browse/CASSANDRA-7087
if [ -z $KAFKA_JMX_OPTS ]; then
    KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote=true"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.ssl=false"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME:-$KAFKA_ADVERTISED_HOST_NAME} "
    export KAFKA_JMX_OPTS
fi

echo "Starting kafka"
exec /kafka/bin/kafka-server-start.sh /kafka/config/server.properties
