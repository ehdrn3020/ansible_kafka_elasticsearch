# DataNode Rolling Restart

`datanode_rolling_restart.sh`는 입력받은 DataNode 호스트를 하나씩 순차 처리하면서 Hadoop DataNode rolling restart를 수행하는 스크립트이다.

## 전제 조건

- 스크립트 실행 서버에서 대상 DataNode로 `k3` 계정 SSH 접속이 가능해야 한다.
- 대상 DataNode 서버에서 아래 명령이 실행 가능해야 한다.

```bash
oop/default/bin/hdfs dfsadmin -report
/hadoop/path/bin/hdfs dfsadmin -shutdownDatanode <host>:9867
/hadoop/path/bin/hdfs --daemon start datanode
jps
```

- 현재 스크립트는 Hadoop 명령을 모두 대상 DataNode에 SSH로 접속해서 실행한다.
- DataNode IPC 포트는 `9867`을 사용한다.

## 주요 설정값

스크립트 상단에서 공통 설정값을 관리한다.

```bash
SSH_USER="k3"
HDFS_BIN="/hadoop/path/bin/hdfs"
DATANODE_IPC_PORT="9867"
WAIT_RETRY=12
WAIT_INTERVAL_SECONDS=5
```

대기 시간은 최대 `WAIT_RETRY * WAIT_INTERVAL_SECONDS`초이다. 현재 설정 기준으로 최대 60초 대기한다.

## 실행 방법

```bash
/bin/bash datanode_rolling_restart.sh
```

실행하면 재시작할 DataNode 목록을 공백으로 입력한다.

```text
1) 재시작할 데이터 노드들을 입력하세요. ex) hostname_1 hostname_2 hostname_3
-> 입력값 : svlxstoragedn01 svlxstoragedn02
```

쉼표 구분은 사용하지 않는다. 공백으로만 구분한다.

## 처리 순서

각 DataNode는 입력된 순서대로 하나씩 처리된다.

1. SSH 연결 확인
2. 현재 DataNode 프로세스 실행 여부 확인
3. graceful shutdown 요청
4. DataNode 프로세스 종료 대기
5. DataNode start 요청
6. DataNode 프로세스 기동 대기
7. NameNode Live 상태 확인
8. 다음 DataNode 진행

중간 단계에서 실패하면 스크립트는 즉시 중단된다.

## 단계별 실행 명령

모든 원격 명령은 `remote_exec()`를 통해 실행되며, 실행 직전에 실제 SSH 명령이 로그로 출력된다.

### SSH 연결 확인

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@<host> "true"
```

### DataNode 프로세스 확인

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@<host> "jps | grep -w DataNode"
```

이 명령은 두 곳에서 사용된다.

- restart 시작 전: 성공해야 정상
- shutdown 이후 종료 대기: 실패해야 종료 완료
- start 이후 기동 대기: 성공해야 기동 완료

### graceful shutdown 요청

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@<host> "/hadoop/path/bin/hdfs dfsadmin -shutdownDatanode <host>:9867"
```

예시:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@svlxstoragedn01 "/hadoop/path/bin/hdfs dfsadmin -shutdownDatanode svlxstoragedn01:9867"
```

### DataNode start

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@<host> "/hadoop/path/bin/hdfs --daemon start datanode"
```

### NameNode Live 상태 확인

```bash
ssh -o BatchMode=yes -o ConnectTimeout=3 k3@<host> "/hadoop/path/bin/hdfs dfsadmin -report | grep -wq 'Hostname: <host>'"
```

`dfsadmin -report` 출력에 대상 host가 `Hostname: <host>` 형태로 나타나면 Live 상태로 판단한다.

## 성공 기준

한 DataNode의 rolling restart 성공 기준은 다음과 같다.

- SSH 연결 성공
- restart 전 `jps`에서 `DataNode` 확인
- graceful shutdown 요청 성공
- shutdown 이후 `jps | grep -w DataNode` 실패 확인
- start 요청 성공
- start 이후 `jps | grep -w DataNode` 성공 확인
- `dfsadmin -report`에서 `Hostname: <host>` 확인

모든 입력 대상이 위 조건을 만족하면 전체 완료 로그가 출력된다.

```text
전체 DataNode rolling restart 완료
```

## 실패 시 동작

아래 상황에서는 에러 로그를 출력하고 즉시 중단한다.

- SSH 연결 실패
- restart 전 DataNode 프로세스 미확인
- graceful shutdown 요청 실패
- DataNode 종료 대기 timeout
- DataNode start 요청 실패
- DataNode 실행 대기 timeout
- NameNode Live 상태 확인 timeout

현재 스크립트는 실패 시 다음 DataNode로 넘어가지 않는다.

## 주의 사항

- `dfsadmin -report`와 `shutdownDatanode`는 대상 DataNode 서버에서 실행된다. 따라서 대상 DataNode 서버에 Hadoop client 설정이 정상적으로 잡혀 있어야 한다.
- `jps` 확인은 프로세스 존재 여부만 확인한다.
- `dfsadmin -report` 확인은 클러스터 관점에서 Live DataNode로 다시 등록됐는지 확인하기 위한 단계이다.
- `hdfs --daemon stop datanode`는 기본 플로우에 포함하지 않는다.
