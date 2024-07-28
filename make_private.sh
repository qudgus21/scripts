#!/bin/bash

# 환경 변수 설정 및 변경 여부를 추적하기 위한 변수
CHANGED=0

# 환경 변수 값 읽기 및 입력
if [ -z "$GITHUB_USER" ]; then
    read -p "GitHub 사용자명을 입력해주세요: " GITHUB_USER
    CHANGED=1
else
    read -p "기존 GitHub 사용자명은 '$GITHUB_USER'입니다. 변경하려면 새 사용자명을 입력하세요 (그렇지 않으면 Enter를 누르세요): " NEW_GITHUB_USER
    if [ -n "$NEW_GITHUB_USER" ]; then
        GITHUB_USER=$NEW_GITHUB_USER
        CHANGED=1
    fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
    read -sp "GitHub Access Token을 입력해주세요: " GITHUB_TOKEN
    echo
    CHANGED=1
else
    read -sp "기존 GitHub Access Token이 설정되어 있습니다. 변경하려면 새 토큰을 입력하세요 (그렇지 않으면 Enter를 누르세요): " NEW_GITHUB_TOKEN
    echo
    if [ -n "$NEW_GITHUB_TOKEN" ]; then
        GITHUB_TOKEN=$NEW_GITHUB_TOKEN
        CHANGED=1
    fi
fi

# 환경 변수를 설정하고 .bash_profile과 .zshrc에 저장
update_profile() {
    local file=$1
    local var=$2
    local value=$3

    if grep -q "^export $var=" "$file"; then
        # 기존 환경 변수가 있는 경우, 값이 변경된 경우에만 업데이트
        if grep -q "^export $var=\"$value\"" "$file"; then
            return
        fi
        # 기존 변수 값을 변경
        perl -i -pe "s/^export $var=.*/export $var=\"$value\"/" "$file"
    else
        # 새로운 변수 추가
        echo "export $var=\"$value\"" >> "$file"
    fi
}

# 업데이트된 환경 변수를 .bash_profile과 .zshrc에 적용
if [ -f ~/.bash_profile ]; then
    update_profile ~/.bash_profile GITHUB_USER "$GITHUB_USER"
    update_profile ~/.bash_profile GITHUB_TOKEN "$GITHUB_TOKEN"
fi

if [ -f ~/.zshrc ]; then
    update_profile ~/.zshrc GITHUB_USER "$GITHUB_USER"
    update_profile ~/.zshrc GITHUB_TOKEN "$GITHUB_TOKEN"
fi

# 변경 사항이 있을 경우에만 알림을 출력
if [ $CHANGED -eq 1 ]; then
    echo
    echo "************************************************************"
    echo "환경 변수가 설정되었습니다. 변경 사항을 적용하려면 다음 단계를 따르세요."
    echo
    # 현재 셸 확인
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            if [ -f ~/.bash_profile ]; then
                echo "1. 현재 터미널 세션에서 변경 사항을 즉시 적용하려면 다음 명령어를 입력하세요: source ~/.bash_profile"
            fi
            echo "2. 또는, 터미널을 새로 열어 변경 사항을 자동으로 적용할 수 있습니다."
            ;;
        zsh)
            if [ -f ~/.zshrc ]; then
                echo "1. 현재 터미널 세션에서 변경 사항을 즉시 적용하려면 다음 명령어를 입력하세요: source ~/.zshrc"
            fi
            echo "2. 또는, 터미널을 새로 열어 변경 사항을 자동으로 적용할 수 있습니다."
            ;;
        *)
            echo "1. 현재 터미널 세션에서 변경 사항을 즉시 적용하려면 셸 설정 파일을 수동으로 적용하세요."
            echo "   일반적으로 다음과 같은 명령어를 사용합니다: source ~/.profile 또는 source ~/.config/shellrc"
            echo "2. 또는, 터미널을 새로 열어 변경 사항을 자동으로 적용할 수 있습니다."
            ;;
    esac
    echo
    echo "변경 사항이 적용된 후에 다시 스크립트를 실행하여 새로운 환경 변수 설정을 사용할 수 있습니다."
    echo "************************************************************"
    echo
fi

# GitHub API 엔드포인트 설정
API_URL="https://api.github.com"
REPOS_URL="$API_URL/user/repos"

# 변경할 레포지토리 이름 입력 받기
read -p "비공개할 레포지토리 이름을 입력하세요 (예: my-repo): " REPO_NAME

# 레포지토리의 전체 이름을 만들기
REPO_FULL_NAME="$GITHUB_USER/$REPO_NAME"

# 레포지토리 확인
REPO_EXISTS=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$API_URL/repos/$REPO_FULL_NAME")

# 레포지토리가 존재하는지 확인
if [[ $(echo "$REPO_EXISTS" | jq -r '.message') == "Not Found" ]]; then
    echo "레포지토리 '$REPO_NAME'이(가) 존재하지 않거나 접근 권한이 없습니다."
    exit 1
fi

# 현재 레포지토리의 공개 상태 확인
IS_PRIVATE=$(echo "$REPO_EXISTS" | jq -r '.private')

# 이미 비공개 레포지토리인 경우
if [[ "$IS_PRIVATE" == "true" ]]; then
    echo "레포지토리 '$REPO_NAME'은(는) 이미 비공개되어 있습니다."
    exit 0
fi

# 사용자에게 확인 받기
read -p "레포지토리 '$REPO_NAME'을(를) 비공개하시겠습니까? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" ]]; then
    echo "잘못된 입력입니다. 'y' 또는 'n'을 입력해주세요."
    exit 1
fi

if [[ "$CONFIRM" == "n" ]]; then
    echo "변경을 취소합니다."
    exit 0
fi

# 레포지토리를 비공개로 변경
UPDATE_RESPONSE=$(curl -s -X PATCH -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -d '{"private": true}' \
    "$API_URL/repos/$REPO_FULL_NAME")

# 변경 확인
if [[ $(echo "$UPDATE_RESPONSE" | jq -r '.private') == "true" ]]; then
    echo "레포지토리 '$REPO_NAME'이(가) 성공적으로 비공개로 변경되었습니다."
else
    echo "레포지토리 '$REPO_NAME'을(를) 비공개로 변경하는 데 실패했습니다."
    echo "$UPDATE_RESPONSE"
fi
