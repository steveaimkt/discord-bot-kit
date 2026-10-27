# discord-bot-kit

Claude Code 공식 디스코드 채널(`discord@claude-plugins-official`)을 **안티그래비티 + Claude Code 확장** 환경에서 설치하고 켜는 플러그인입니다. 윈도우에서 자주 막히는 곳을 스크립트가 찾아 고칩니다.

공식 안내 · [code.claude.com/docs/ko/channels#discord](https://code.claude.com/docs/ko/channels#discord)

## 설치

실습 폴더를 연 안티그래비티 Claude Code 확장 채팅창에 이렇게 칩니다. 저장소를 클론하고, 클론한 폴더를 마켓플레이스로 등록해 설치합니다.

```txt
터미널 명령으로 아래 세 줄을 차례로 실행해줘. 끝나면 결과만 한 줄씩 알려줘.
git clone https://github.com/steveaimkt/discord-bot-kit.git
claude plugin marketplace add ./discord-bot-kit
claude plugin install discord-bot-kit@discord-bot-kit
```

끝나면 안티그래비티를 완전히 종료하고 다시 켠 뒤 채팅창에 **«디스코드 봇 세팅하자»** 라고 칩니다.

플러그인 설치가 막혀도 클론한 폴더의 스크립트를 바로 돌릴 수 있습니다 (아래 「직접 돌리기」). 새 버전은 클론한 폴더에서 `git pull` 뒤 `claude plugin marketplace update discord-bot-kit` 으로 받습니다.

공식 디스코드 플러그인(`discord@claude-plugins-official`)은 의존성으로 걸지 않았습니다. 공식 마켓플레이스가 아직 없는 PC 에서는 의존성 때문에 이 플러그인 설치까지 실패해, 점검 스크립트를 쓸 수 없게 되기 때문입니다 (2026-10-27 깨끗한 설정 폴더로 확인). 공식 플러그인은 점검 스크립트 `-Fix` 가 설치합니다.

## 하는 일

| 단계 | 어디서 | 무엇을 |
|---|---|---|
| 1 점검 · 수리 | 채팅창 | bun · Git · Claude CLI 버전 · 공식 마켓플레이스 · 디스코드 플러그인 · discord.js 미리 받기 · 실행 파일 놓기 |
| 2 봇 만들기 | 브라우저 | Developer Portal · 토큰 · Message Content Intent |
| 3 토큰 넣기 | `토큰등록.cmd` | 토큰을 화면에 보이지 않게 받아 BOM 없는 `.env` 로 저장 · 디스코드에 직접 물어 Intent · 서버 확인 · 초대 주소 만들기 |
| 4 봇 켜기 | 안티그래비티 터미널 | `.\봇켜기.cmd` |
| 5 페어링 | PC 디스코드 → 채팅창 | «페어링 코드 ○○○○○○» (`pair` 스크립트 · 공식 `/discord:access pair` + `policy allowlist`) |
| 6 첫 대화 | PC 디스코드 | 「지금 폴더에 무엇이 있는지 알려줘」 |

## 윈도우에서 고치는 것

| 막히는 곳 | 고치는 방법 |
|---|---|
| bun 을 깔았는데 플러그인이 못 찾는다 | 사용자 PATH 에 넣고, `봇켜기.cmd` 가 실행 때마다 PATH 앞에 다시 붙인다 |
| 봇 첫 기동에서 discord 서버가 failed | 플러그인 폴더에서 `bun install` 을 미리 돌리고, `MCP_TIMEOUT=120000` 으로 켠다 |
| 토큰을 넣었는데 「토큰 없음」 | PowerShell 이 붙인 BOM 을 지우고 다시 쓴다 · 옛 `DISCORD_BOT_TOKEN` 환경 변수를 비우고 켠다 |
| `Invoke-RestMethod` 가 디스코드에 못 붙는다 | TLS 1.2 를 켠다 (PowerShell 5.1) |
| 「이 시스템에서 스크립트를 실행할 수 없으므로」 | `.cmd` 가 `-ExecutionPolicy Bypass` 로 부른다 · 내 계정 정책을 RemoteSigned 로 |
| 한글 스크립트가 깨진다 | `.ps1` 은 UTF-8 BOM · `.cmd` 는 ASCII 만 |
| `/plugin` 화면이 확장에 없다 | `claude plugin` 터미널 명령으로 설치한다 |
| Message Content Intent 를 안 켰다 | 디스코드 API `applications/@me` 로 직접 확인한다 |
| 서버 초대 URL 을 못 만든다 | 권한 6개를 넣은 초대 주소를 스크립트가 만든다 |
| 답장마다 허용 창 | `.claude/settings.local.json` 에 디스코드 도구 허용 |
| **봇 서버가 오류 없이 안 뜸** (claude-code#42769 · #80822) | 디스코드 플러그인을 사용자 범위에서 꺼 두고 봇 세션만 `--settings` 로 켠다. 켜기 직전 `mcp-needs-auth-cache.json` 의 `plugin:discord:discord` 를 지운다 (맥에서 재현 · 2026-10-27) |
| **DM 은 오는데 답장이 「not allowlisted」** (claude-plugins-official#6768) | `fetchAllowedChannel` 에 3줄 우회 패치 · 원본 `server.ts.orig` · `-Unpatch` 로 되돌림 · 그래도 막히면 `-Channel <이름>` 으로 서버 채널 전환 |
| `.env` 가 CRLF | 공식 서버는 `\n` 으로만 나눠 `\r` 이 토큰에 붙는다 · 걷어 낸다 |
| 켜졌는데 무반응 | 디스코드 MCP 로그로 판정 · 접속 · 「channels feature is not currently available」 · 토큰 · bun |
| 끝내 안 됨 | 대체 경로 · 확장 입력칸 `/remote-control` + 브라우저 claude.ai/code (bun · 디스코드 필요 없음) |

## 직접 돌리기

```powershell
# 윈도우 · 보기만
powershell -NoProfile -ExecutionPolicy Bypass -File plugins\discord-bot-kit\skills\discord-bot-setup\scripts\doctor.ps1 -Project C:\Users\me\Desktop\업무봇
# 고치기까지
... doctor.ps1 -Fix -Project ...
```

```bash
# 맥
bash plugins/discord-bot-kit/skills/discord-bot-setup/scripts/doctor.sh --fix --project ~/Desktop/업무봇
```

출력 맨 끝 `DOCTOR_JSON` 줄은 스킬이 읽는 판정입니다.

## 지키는 것

- 토큰은 `~/.claude/channels/discord/.env` 에만 둡니다. 채팅창에 붙여 넣지 않습니다
- `/discord:access policy allowlist` 로 잠급니다
- `--dangerously-skip-permissions` 는 쓰지 않습니다. 봇은 `--permission-mode acceptEdits` 로 켭니다
