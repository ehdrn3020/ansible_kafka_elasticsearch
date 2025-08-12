# First Example with Datagen

## flink install
```aiignore
# install
wget https://archive.apache.org/dist/flink/flink-1.15.4/flink-1.15.4-bin-scala_2.12.tgz

# tar
tar -xzf flink-*.tgz
```

## jar 다운로드
```aiignore
# Maven Central에서 관련 jar 파일 다운로드 
# - https://central.sonatype.com/
# /lib 경로에 설치
wget https://repo1.maven.org/maven2/org/apache/flink/flink-connector-datagen/1.17.1/flink-connector-datagen-1.17.1.jar
```

## 실행
```aiignore
# flink 실행
./bin/start-cluster.sh
(./bin/stop-cluster.sh)

# 실행 확인
ps aux | grep flink

# flink-sql 실행
./bin/sql-client.sh
```

## sql-client 예제
```aiignore
CREATE TABLE Orders (
  order_id BIGINT,
  price    DOUBLE,
  order_time TIMESTAMP(3),
  WATERMARK FOR order_time AS order_time - INTERVAL '5' SECOND
) WITH (
  'connector' = 'datagen',
  'rows-per-second' = '5',
  'fields.order_id.kind' = 'sequence',
  'fields.order_id.start' = '1',
  'fields.order_id.end' = '1000000',
  'fields.price.min' = '1',
  'fields.price.max' = '1000'
);

CREATE TABLE PrintSink (
  order_id BIGINT,
  price    DOUBLE,
  order_time TIMESTAMP(3)
) WITH (
  'connector' = 'print'
);

# 데이터 생성
SELECT * FROM Orders;
```

## tm 확인
```aiignore
http://{public ip}:8081/#/overview
```
