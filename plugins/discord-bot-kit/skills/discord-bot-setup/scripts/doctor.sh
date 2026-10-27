#!/usr/bin/env bash
# discord-bot-kit · 맥 점검 · 수리
# 사용 · bash doctor.sh [--fix] [--project <폴더>]
# --fix 없이 돌리면 보기만 한다.

FIX=0
PROJECT="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done

unset CLAUDECODE
MARKET="claude-plugins-official"
PLUGIN_ID="discord@$MARKET"
STATE_DIR="${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord}"
ENV_FILE="$STATE_DIR/.env"
PERMS=274878008384
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

ROWS=""
FAILS=0; TODOS=0
add() { # id 이름 상태 내용 할일
  ROWS="$ROWS$1	$2	$3	$4	$5
"
  [ "$3" = fail ] && FAILS=$((FAILS+1))
  [ "$3" = todo ] && TODOS=$((TODOS+1))
  return 0
}
has() { command -v "$1" >/dev/null 2>&1; }
pyjson() { python3 -c "$1" 2>/dev/null; }

# 1 · 내 컴퓨터
add os "맥 버전" ok "macOS $(sw_vers -productVersion 2>/dev/null)" ""
case "$PROJECT" in
  *"Mobile Documents"*|*iCloud*) add icloud "실습 폴더 위치" warn "iCloud 동기화 폴더 안 ($PROJECT)" "대부분 그대로 된다. 파일이 늦게 보이면 동기화를 잠시 끈다" ;;
  *) add icloud "실습 폴더 위치" ok "$PROJECT" "" ;;
esac

# 2 · Claude CLI
if has claude; then
  V="$(claude --version 2>/dev/null | head -1)"
  if printf '%s' "$V" | awk '{split($1,a,"."); exit !((a[1]>2)||(a[1]==2&&(a[2]>1||(a[2]==1&&a[3]>=80))))}'; then
    add claude "Claude CLI" ok "$V" ""
  elif [ $FIX = 1 ]; then claude update >/dev/null 2>&1; add claude "Claude CLI" fixed "$V → claude update" "안티그래비티를 껐다 켠다"
  else add claude "Claude CLI" fail "$V (2.1.80 이상 필요)" "claude update"; fi
else
  add claude "Claude CLI" fail "찾을 수 없다" "과제 1 · curl -fsSL https://claude.ai/install.sh | bash"
fi

# 3 · Git
if has git && git --version >/dev/null 2>&1; then add git "Git" ok "$(git --version)" ""
else add git "Git" fail "찾을 수 없다" "xcode-select --install"; fi

# 4 · Bun
if ! has bun && [ $FIX = 1 ]; then curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1; export PATH="$HOME/.bun/bin:$PATH"; BUN_NEW=1; fi
if has bun; then
  if [ "${BUN_NEW:-0}" = 1 ]; then add bun "Bun" fixed "$(bun --version) 설치" "안티그래비티를 껐다 켠다"
  else add bun "Bun" ok "$(bun --version) · $(command -v bun)" ""; fi
else add bun "Bun" fail "설치되지 않았다" "--fix 로 설치"; fi

# 5 · 마켓플레이스 · 플러그인
INSTALL_PATH=""
if has claude; then
  if claude plugin marketplace list --json 2>/dev/null | pyjson "import json,sys; d=json.load(sys.stdin); sys.exit(0 if any(m.get('name')=='$MARKET' for m in d) else 1)"; then
    [ $FIX = 1 ] && claude plugin marketplace update "$MARKET" >/dev/null 2>&1
    add market "공식 마켓플레이스" ok "$MARKET" ""
  elif [ $FIX = 1 ]; then
    if claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1; then add market "공식 마켓플레이스" fixed "추가함" ""
    else add market "공식 마켓플레이스" fail "추가하지 못했다" "Git · 네트워크 확인"; fi
  else add market "공식 마켓플레이스" fail "없다" "--fix 로 추가"; fi

  plugin_info() { claude plugin list --json 2>/dev/null | pyjson "import json,sys
d=json.load(sys.stdin)
for p in d:
  if p.get('id')=='$PLUGIN_ID': print(p.get('version','')+'\t'+str(p.get('enabled')).lower()+'\t'+p.get('installPath',''))"; }
  INFO="$(plugin_info)"
  if [ -z "$INFO" ] && [ $FIX = 1 ]; then
    claude plugin install "$PLUGIN_ID" --scope user >/dev/null 2>&1
    INFO="$(plugin_info)"
    [ -n "$INFO" ] && add plugin "디스코드 플러그인" fixed "설치함 v$(printf '%s' "$INFO" | cut -f1)" "" || add plugin "디스코드 플러그인" fail "설치하지 못했다" "claude plugin marketplace update $MARKET 뒤 다시"
  elif [ -n "$INFO" ]; then
    if [ "$(printf '%s' "$INFO" | cut -f2)" = true ]; then add plugin "디스코드 플러그인" ok "v$(printf '%s' "$INFO" | cut -f1)" ""
    elif [ $FIX = 1 ]; then claude plugin enable "$PLUGIN_ID" >/dev/null 2>&1; add plugin "디스코드 플러그인" fixed "꺼져 있던 것을 켬" ""
    else add plugin "디스코드 플러그인" warn "꺼져 있다" "--fix 로 켠다"; fi
  else add plugin "디스코드 플러그인" fail "설치되지 않았다" "--fix 로 설치"; fi
  INSTALL_PATH="$(printf '%s' "$INFO" | cut -f3)"
fi

# 6 · 봇 부품 미리 받기
if [ -n "$INSTALL_PATH" ] && [ -d "$INSTALL_PATH" ]; then
  if [ -d "$INSTALL_PATH/node_modules/discord.js" ]; then add deps "봇 부품 (discord.js)" ok "미리 받아 둠" ""
  elif [ $FIX = 1 ] && has bun; then
    (cd "$INSTALL_PATH" && bun install --no-summary >/dev/null 2>&1)
    [ -d "$INSTALL_PATH/node_modules/discord.js" ] && add deps "봇 부품 (discord.js)" fixed "미리 받음" "" || add deps "봇 부품 (discord.js)" fail "받지 못했다" "네트워크 확인"
  else add deps "봇 부품 (discord.js)" warn "아직 안 받음" "--fix 로 미리 받는다"; fi
fi

# 7 · 토큰 파일
TOKEN=""
if [ -f "$ENV_FILE" ]; then
  BOM=""
  [ "$(head -c3 "$ENV_FILE" | xxd -p)" = "efbbbf" ] && BOM="UTF-8 BOM"
  TOKEN="$(LC_ALL=C sed -e 's/^\xEF\xBB\xBF//' "$ENV_FILE" | grep -E '^[[:space:]]*DISCORD_BOT_TOKEN[[:space:]]*=' | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//; s/^Bot //')"
  if [ -n "$BOM" ] && [ -n "$TOKEN" ]; then
    if [ $FIX = 1 ]; then printf 'DISCORD_BOT_TOKEN=%s\n' "$TOKEN" > "$ENV_FILE"; chmod 600 "$ENV_FILE"; add envfile "토큰 파일 (.env)" fixed "$BOM → 고쳐 씀" ""
    else add envfile "토큰 파일 (.env)" fail "$BOM 때문에 봇이 토큰을 못 읽는다" "--fix 로 고쳐 쓴다"; fi
  elif [ -n "$TOKEN" ]; then add envfile "토큰 파일 (.env)" ok "$ENV_FILE" ""
  else add envfile "토큰 파일 (.env)" fail "DISCORD_BOT_TOKEN 줄이 없다" "토큰등록.command 를 다시"; fi
else add envfile "토큰 파일 (.env)" todo "아직 없다" "토큰등록.command 로 토큰을 넣는다"; fi
[ -n "${DISCORD_BOT_TOKEN:-}" ] && add envvar "환경 변수 DISCORD_BOT_TOKEN" warn "설정돼 있어 .env 보다 먼저 읽힌다" "봇켜기.command 는 이 값을 비우고 켠다"

# 8 · 디스코드에 직접 물어보기
if [ -n "$TOKEN" ]; then
  api() { curl -s -m 15 -w '\n%{http_code}' -H "Authorization: Bot $TOKEN" -A 'DiscordBot (discord-bot-kit, 0.1)' "https://discord.com/api/v10$1"; }
  R="$(api /users/@me)"; CODE="$(printf '%s' "$R" | tail -1)"; BODY="$(printf '%s' "$R" | sed '$d')"
  if [ "$CODE" = 200 ]; then
    BOT_NAME="$(printf '%s' "$BODY" | pyjson "import json,sys; print(json.load(sys.stdin)['username'])")"
    BOT_ID="$(printf '%s' "$BODY" | pyjson "import json,sys; print(json.load(sys.stdin)['id'])")"
    add token "토큰" ok "봇 이름 · $BOT_NAME" ""
    A="$(api /applications/@me | sed '$d')"
    INTENT="$(printf '%s' "$A" | pyjson "import json,sys; f=int(json.load(sys.stdin).get('flags',0)); print('on' if f&(1<<19) or f&(1<<18) else 'off')")"
    PUBLIC="$(printf '%s' "$A" | pyjson "import json,sys; print(str(json.load(sys.stdin).get('bot_public')).lower())")"
    if [ "$INTENT" = on ]; then add intent "Message Content Intent" ok "켜짐" ""
    else add intent "Message Content Intent" fail "꺼짐 · 봇이 메시지를 못 읽는다" "Developer Portal → Bot → Message Content Intent 켜고 Save Changes"; fi
    [ "$PUBLIC" = true ] && add public "Public Bot" warn "켜짐 · 아무나 이 봇을 자기 서버에 넣을 수 있다" "Developer Portal → Bot → Public Bot 끄기 (권장)"
    G="$(api /users/@me/guilds | sed '$d' | pyjson "import json,sys; print(', '.join(g['name'] for g in json.load(sys.stdin)))")"
    if [ -n "$G" ]; then add guild "봇이 들어간 서버" ok "$G" ""
    else add guild "봇이 들어간 서버" fail "아직 아무 서버에도 없다" "이 주소를 브라우저로 열어 내 서버에 초대 · https://discord.com/oauth2/authorize?client_id=$BOT_ID&scope=bot&permissions=$PERMS"; fi
  elif [ "$CODE" = 401 ]; then add token "토큰" fail "디스코드가 거절했다 (401)" "Developer Portal → Bot → Reset Token → 토큰등록.command 다시"
  else add token "토큰" fail "디스코드에 닿지 않는다 ($CODE)" "와이파이 확인 · 휴대폰 핫스팟으로 다시"; fi
fi

# 9 · 페어링
ACC="$STATE_DIR/access.json"
if [ -f "$ACC" ]; then
  P="$(pyjson "import json; a=json.load(open('$ACC')); print(str(len(a.get('allowFrom',[])))+'\t'+a.get('dmPolicy','pairing'))")"
  N="$(printf '%s' "$P" | cut -f1)"; POL="$(printf '%s' "$P" | cut -f2)"
  if [ "${N:-0}" -gt 0 ] && [ "$POL" = allowlist ]; then add pair "페어링" ok "허용 $N 명 · allowlist 로 잠김" ""
  elif [ "${N:-0}" -gt 0 ]; then add pair "페어링" warn "허용 $N 명 · 정책 $POL" "봇 세션에서 /discord:access policy allowlist"
  else add pair "페어링" todo "아직 아무도 없다" "봇에 DM → /discord:access pair <코드>"; fi
else add pair "페어링" todo "아직 안 함" "봇을 켠 뒤 봇에 DM → /discord:access pair <코드>"; fi

# 10 · 실습 폴더에 실행 파일 · 권한 설정
if [ $FIX = 1 ] && [ -d "$PROJECT" ]; then
  mkdir -p "$PROJECT/.claude/bot"
  cp "$SCRIPT_DIR/start-bot.sh" "$SCRIPT_DIR/set-token.sh" "$PROJECT/.claude/bot/"
  printf '#!/bin/bash\nbash "$(dirname "$0")/.claude/bot/start-bot.sh"\n' > "$PROJECT/봇켜기.command"
  printf '#!/bin/bash\nbash "$(dirname "$0")/.claude/bot/set-token.sh"\n' > "$PROJECT/토큰등록.command"
  chmod +x "$PROJECT/봇켜기.command" "$PROJECT/토큰등록.command"
  SP="$PROJECT/.claude/settings.local.json"
  python3 - "$SP" <<'PY'
import json, os, sys
p = sys.argv[1]
s = {}
if os.path.exists(p):
    try: s = json.load(open(p))
    except Exception: s = {}
allow = s.setdefault('permissions', {}).setdefault('allow', [])
if 'mcp__plugin_discord_discord' not in allow:
    allow.append('mcp__plugin_discord_discord')
json.dump(s, open(p, 'w'), ensure_ascii=False, indent=2)
PY
  add launcher "봇켜기 · 토큰등록 (.command)" fixed "$PROJECT" ""
elif [ -f "$PROJECT/봇켜기.command" ]; then add launcher "봇켜기 · 토큰등록 (.command)" ok "$PROJECT" ""
else add launcher "봇켜기 · 토큰등록 (.command)" todo "아직 없다" "--fix 로 실습 폴더에 만든다"; fi

# 보고
echo ""
echo "디스코드 봇 점검 결과"
echo "─────────────────────"
printf '%s' "$ROWS" | while IFS='	' read -r id name st detail todo; do
  case "$st" in ok) m="✅";; fixed) m="🔧";; warn) m="⚠️";; fail) m="❌";; *) m="⬜";; esac
  echo "$m $name · $detail"
  [ -n "$todo" ] && echo "    → $todo"
done
echo ""
echo "막힘 $FAILS · 할 일 $TODOS"
printf '%s' "$ROWS" | python3 -c "
import json,sys
items=[dict(zip(['id','name','status','detail','todo'],l.split('\t'))) for l in sys.stdin.read().splitlines() if l]
print('DOCTOR_JSON '+json.dumps({'os':'mac','fix':$FIX==1,'fails':$FAILS,'todos':$TODOS,'items':items},ensure_ascii=False))"
