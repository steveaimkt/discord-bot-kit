#!/usr/bin/env bash
# discord-bot-kit · 봇 켜기 (봇켜기.command 가 부른다). 이 창이 열려 있는 동안만 봇이 답한다.
PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT" || exit 1
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
unset DISCORD_BOT_TOKEN CLAUDECODE
export MCP_TIMEOUT=120000
STATE_DIR="${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord}"

P=""
command -v claude >/dev/null || P="$P\n · Claude CLI 를 찾을 수 없습니다"
command -v bun >/dev/null || P="$P\n · bun 을 찾을 수 없습니다"
[ -f "$STATE_DIR/.env" ] || P="$P\n · 봇 토큰이 없습니다 (토큰등록.command)"
[ -d "$HOME/.claude/plugins/cache/claude-plugins-official/discord" ] || P="$P\n · 디스코드 플러그인이 설치되지 않았습니다"
if [ -n "$P" ]; then
  printf '\n봇을 켜기 전에 고칠 것이 있습니다.%b\n\n안티그래비티 채팅창에 «디스코드 봇 점검해줘» 라고 칩니다.\n' "$P"
  exit 1
fi

# 켜기 직전 정리 · 인증 캐시의 디스코드 실패 기록 (claude-code#80822) · .env 의 BOM · CRLF
AC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/mcp-needs-auth-cache.json"
[ -f "$AC" ] && python3 -c "
import json,sys;p=sys.argv[1];d=json.load(open(p))
if d.pop('plugin:discord:discord',None) is not None: json.dump(d,open(p,'w')); print('인증 캐시에 남은 디스코드 실패 기록을 지웠습니다.')" "$AC" 2>/dev/null
python3 -c "
import sys;p=sys.argv[1];b=open(p,'rb').read();c=b.lstrip(b'\xef\xbb\xbf').replace(b'\r',b'')
if c!=b: open(p,'wb').write(c); print('토큰 파일(.env)의 줄바꿈 · BOM 을 고쳤습니다.')" "$STATE_DIR/.env" 2>/dev/null

echo ""
echo "봇을 켭니다 · $PROJECT"
echo "디스코드에서 봇 이름 옆에 초록 점이 뜨면 켜진 것입니다. 이 창은 닫지 않습니다."
echo "2분이 지나도 초록 점이 없으면 채팅창에 «디스코드 봇 점검해줘»."
echo ""
# 디스코드 플러그인은 평소엔 꺼 두고, 이 세션에서만 켠다
exec claude --settings '{"enabledPlugins":{"discord@claude-plugins-official":true}}' --channels plugin:discord@claude-plugins-official --permission-mode acceptEdits
