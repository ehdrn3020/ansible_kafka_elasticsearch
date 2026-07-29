#!/bin/bash

set -uo pipefail

SSH_USER="k3"
HDFS_BIN="/hadoop/path/bin/hdfs"
DATANODE_IPC_PORT="9867"
WAIT_RETRY=12
WAIT_INTERVAL_SECONDS=5

###############################################################################
# 공통 함수
###############################################################################

log()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error()
{
    log "[ERROR] $*" >&2
}

trim()
{
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "${value}"
}

remote_exec()
{
    local host="$1"
    shift

    log "${host}: 실행 명령어: ssh -o BatchMode=yes -o ConnectTimeout=3 ${SSH_USER}@${host} \"$*\""
    ssh -o BatchMode=yes -o ConnectTimeout=3 "${SSH_USER}@${host}" "$@"
}

###############################################################################
# SSH 연결 확인
###############################################################################

check_ssh()
{
    local host="$1"
    log "============================================================"
    log "${host}: SSH 연결 확인 중"
    if ! remote_exec "${host}" "true"; then
        error "${host}: SSH 연결 실패"
        return 1
    fi

    log "${host}: SSH 연결 확인 완료"
    return 0
}

###############################################################################
# DataNode 상태 확인
###############################################################################

check_datanode()
{
    local host="$1"
    log "============================================================"
    log "${host}: DataNode 프로세스 상태 확인 중"
    if ! remote_exec "${host}" "jps | grep -w DataNode"; then
        error "${host}: DataNode 프로세스가 실행 중이 아님"
        return 1
    fi

    log "${host}: DataNode 프로세스 상태 확인 완료"
    return 0
}

###############################################################################
# DataNode graceful shutdown 요청
###############################################################################

shutdown_datanode()
{
    local host="$1"

    log "============================================================"
    log "${host}: DataNode graceful shutdown 요청 중"
    if ! remote_exec "${host}" "${HDFS_BIN} dfsadmin -shutdownDatanode ${host}:${DATANODE_IPC_PORT}"; then
        error "${host}: DataNode graceful shutdown 요청 실패"
        return 1
    fi

    log "${host}: DataNode graceful shutdown 요청 완료"
    return 0
}

###############################################################################
# DataNode 종료 대기
###############################################################################

wait_datanode_stopped()
{
    local host="$1"
    local retry="${WAIT_RETRY}"
    local interval="${WAIT_INTERVAL_SECONDS}"
    local i

    log "============================================================"
    log "${host}: DataNode 종료 대기 시작"

    for ((i=1; i<=retry; i++)); do
        if ! check_datanode "${host}"; then
            log "${host}: DataNode 종료 확인 완료"
            return 0
        fi

        log "${host}: DataNode 아직 실행 중. ${interval}초 후 재확인 (${i}/${retry})"
        sleep "${interval}"
    done

    error "${host}: DataNode 종료 대기 timeout"
    return 1
}

###############################################################################
# DataNode start 요청
###############################################################################

start_datanode()
{
    local host="$1"

    log "============================================================"
    log "${host}: DataNode start 요청 중"
    if ! remote_exec "${host}" "${HDFS_BIN} --daemon start datanode"; then
        error "${host}: DataNode start 요청 실패"
        return 1
    fi

    log "${host}: DataNode start 요청 완료"
    return 0
}

###############################################################################
# DataNode 기동 대기
###############################################################################

wait_datanode_started()
{
    local host="$1"
    local retry="${WAIT_RETRY}"
    local interval="${WAIT_INTERVAL_SECONDS}"
    local i

    log "============================================================"
    log "${host}: DataNode 실행 대기 시작"

    for ((i=1; i<=retry; i++)); do
        if check_datanode "${host}"; then
            log "${host}: DataNode 실행 확인 완료"
            return 0
        fi

        log "${host}: DataNode 실행 대기 중. ${interval}초 후 재확인 (${i}/${retry})"
        sleep "${interval}"
    done

    error "${host}: DataNode 실행 대기 timeout"
    return 1
}

###############################################################################
# NameNode Live DataNode 확인
###############################################################################

wait_datanode_live()
{
    local host="$1"
    local retry="${WAIT_RETRY}"
    local interval="${WAIT_INTERVAL_SECONDS}"
    local i

    log "============================================================"
    log "${host}: NameNode Live 상태 확인 시작"

    for ((i=1; i<=retry; i++)); do
        if remote_exec "${host}" "${HDFS_BIN} dfsadmin -report | grep -wq 'Hostname: ${host}'"; then
            log "${host}: NameNode Live 상태 확인 완료"
            return 0
        fi

        log "${host}: NameNode Live 상태 대기 중. ${interval}초 후 재확인 (${i}/${retry})"
        sleep "${interval}"
    done

    error "${host}: NameNode Live 상태 확인 timeout"
    return 1
}

###############################################################################
# Main
###############################################################################

main()
{
    local input
    local host
    local raw_host
    local hosts=()

    echo "1) 재시작할 데이터 노드들을 입력하세요. ex) hostname_1 hostname_2 hostname_3"
    printf '%s' "-> 입력값 : "
    read -r input

    if [[ -z "$(trim "${input}")" ]]; then
        error "DataNode 목록이 입력되지 않았습니다."
        exit 1
    fi

    read -ra hosts <<< "${input}"
    log "========================대상 DataNode========================"
    log "대상 DataNode"
    for raw_host in "${hosts[@]}"; do
        host="$(trim "${raw_host}")"

        if [[ -z "${host}" ]]; then
            continue
        fi

        echo "  - ${host}"
    done

    for raw_host in "${hosts[@]}"; do
        host="$(trim "${raw_host}")"

        if [[ -z "${host}" ]]; then
            continue
        fi

        if ! check_ssh "${host}"; then
            error "${host}: SSH 연결 확인 실패"
            exit 1
        fi

        if ! check_datanode "${host}"; then
            error "${host}: DataNode 상태 확인 실패"
            exit 1
        fi

        if ! shutdown_datanode "${host}"; then
            error "${host}: DataNode graceful shutdown 실패"
            exit 1
        fi

        if ! wait_datanode_stopped "${host}"; then
            error "${host}: DataNode 종료 확인 실패"
            exit 1
        fi

        if ! start_datanode "${host}"; then
            error "${host}: DataNode start 실패"
            exit 1
        fi

        if ! wait_datanode_started "${host}"; then
            error "${host}: DataNode 실행 확인 실패"
            exit 1
        fi

        if ! wait_datanode_live "${host}"; then
            error "${host}: NameNode Live 상태 확인 실패"
            exit 1
        fi

        log "${host}: DataNode restart 완료"
        sleep 5
    done

    log "============================================================"
    log "전체 DataNode rolling restart 완료"
    log "============================================================"

}

main "$@"
