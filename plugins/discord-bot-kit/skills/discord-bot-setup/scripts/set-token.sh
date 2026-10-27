#!/usr/bin/env bash
# discord-bot-kit · 봇 토큰 넣기 (토큰등록.command 가 부른다). 토큰은 화면에 보이지 않는다.
STATE_DIR="${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord}"
ENV_FILE="$STATE_DIR/.env"
PERMS=274878008384

echo ""
echo "디스코드 봇 토큰 넣기"
echo "Developer Portal → Bot → Reset Token 으로 복사한 토큰을 붙여 넣습니다 (⌘V). 글자는 보이지 않아도 들어갑니다."
echo ""
for try in 1 2 3; do
  printf '토큰: '; read -rs TOKEN; echo ""
  TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]"'\''')"; TOKEN="${TOKEN#Bot}"
  if [ "$(printf '%s' "$TOKEN" | awk -F. '{print NF}')" != 3 ]; then echo "토큰 모양이 아닙니다. 다시 붙여 넣어 주세요."; continue; fi
  R="$(curl -s -m 15 -w '\n%{http_code}' -H "Authorization: Bot $TOKEN" https://discord.com/api/v10/users/@me)"
  CODE="$(printf '%s' "$R" | tail -1)"
  if [ "$CODE" = 401 ]; then echo "디스코드가 이 토큰을 거절했습니다. Reset Token 으로 새로 받아 주세요."; continue; fi
  mkdir -p "$STATE_DIR"
  printf 'DISCORD_BOT_TOKEN=%s\n' "$TOKEN" > "$ENV_FILE"; chmod 600 "$ENV_FILE"
  echo "저장했습니다 · $ENV_FILE"
  if [ "$CODE" = 200 ]; then
    BODY="$(printf '%s' "$R" | sed '$d')"
    echo "봇 이름 · $(printf '%s' "$BODY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["username"])')"
    BOT_ID="$(printf '%s' "$BODY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
    G="$(curl -s -m 15 -H "Authorization: Bot $TOKEN" https://discord.com/api/v10/users/@me/guilds | python3 -c 'import json,sys; print(", ".join(g["name"] for g in json.load(sys.stdin)))' 2>/dev/null)"
    if [ -n "$G" ]; then echo "들어간 서버 · $G"
    else
      URL="https://discord.com/oauth2/authorize?client_id=$BOT_ID&scope=bot&permissions=$PERMS"
      echo "아직 서버에 없습니다. 아래 주소를 브라우저로 열어 내 서버에 초대합니다."; echo "$URL"
      printf '%s' "$URL" | pbcopy 2>/dev/null && echo "(주소를 복사해 두었습니다)"
    fi
  fi
  echo ""; echo "채팅창으로 돌아가 «토큰 넣었어» 라고 칩니다."
  exit 0
done
echo "세 번 모두 실패했습니다. 채팅창에 «토큰이 안 들어가» 라고 칩니다."
exit 1
