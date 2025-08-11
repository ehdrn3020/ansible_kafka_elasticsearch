# flink_kafka_dynamic_session
flink를 이용한 kafka topic data에 동적인 session 값 적용

#### **Deploy Command:**
```
# 공통 설정
ansible-playbook -i inventory/hosts playbooks/main.yml --tags "common"

# Zookeeper 클러스터
ansible-playbook -i inventory/hosts playbooks/main.yml --tags "zookeeper"

# Kafka 클러스터
ansible-playbook -i inventory/hosts playbooks/main.yml --tags "kafka"
```


#### **Zookeeper:**
```
# 서비스 상태
systemctl status zookeeper

# 클러스터 상태
/rnd/zookeeper/bin/zkServer.sh status

# 클라이언트 접속
/rnd/zookeeper/bin/zkCli.sh -server localhost:2181
```

#### **Kafka:**
```bash
systemctl status kafka

# 토픽 목록
/rnd/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# 토픽 생성 예제
/rnd/kafka/bin/kafka-topics.sh --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
```