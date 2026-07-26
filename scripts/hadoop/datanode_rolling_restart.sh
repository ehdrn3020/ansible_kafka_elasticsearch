#!/bin/bash

set -uo pipefail

SSH_USER="k3"

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

    done

    log "============================================================"
    log "전체 DataNode 상태 확인 완료"
    log "============================================================"
}

main "$@"
