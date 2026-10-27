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

echo ""
echo "봇을 켭니다 · $PROJECT"
echo "디스코드에서 봇 이름 옆에 초록 점이 뜨면 켜진 것입니다. 이 창은 닫지 않습니다."
echo ""
exec claude --channels plugin:discord@claude-plugins-official --permission-mode acceptEdits
