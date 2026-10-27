---
name: discord-bot-setup
description: Claude Code 공식 디스코드 채널(discord@claude-plugins-official)을 안티그래비티 + Claude Code 확장 환경에서 설치하고 켠다. 윈도우에서 자주 막히는 bun 경로 · 플러그인 설치 · 첫 실행 시간 초과 · .env 인코딩 · TLS · Message Content Intent · 서버 초대를 스크립트로 찾아 고친다. «디스코드 봇 세팅하자» «디스코드 봇 설치» «디스코드 봇 점검해줘» «봇이 답을 안 해» «봇이 안 켜져» «토큰 넣었어» 같은 말에 쓴다.
---

# 디스코드 봇 세팅 · 점검

휴대폰 디스코드에서 봇에게 DM 을 보내면, 내 PC 의 실습 폴더에서 Claude 가 일하고 디스코드로 답한다.
공식 안내(code.claude.com/docs/ko/channels#discord)와 같은 순서를 밟되, 손으로 치던 것은 스크립트가 한다.

## 어디서 무엇을 하나

| 자리 | 하는 일 |
|---|---|
| 안티그래비티 **Claude Code 확장 채팅창** (지금 여기) | 점검 · 자동 수리 · 안내 · 페어링 확인 |
| 안티그래비티 **아래쪽 터미널** (`Ctrl + \``) | `.\봇켜기.cmd` 로 봇 세션 하나만 띄운다 |
| 브라우저 | Developer Portal 에서 봇 만들기 · 서버 초대 |
| 휴대폰 디스코드 | 봇에 DM · 페어링 코드 받기 · 일 시키기 |

`--channels` 로 여는 봇 세션은 확장 채팅창에서 켤 수 없다. 그래서 봇 켜기만 터미널에서 한다.

### 윈도우에서 막히는 곳과 설계 (2026-10-27 · 맥에서 재현 확인)

| 막히는 곳 | 근거 | 이 스킬이 하는 일 |
|---|---|---|
| 봇 서버가 오류 없이 안 뜸 | claude-code#42769 · #80822 · 재현 | 디스코드 플러그인을 **평소엔 꺼 두고**(채팅창이 토큰 없이 서버를 띄웠다 실패하며 `mcp-needs-auth-cache.json` 을 오염시키지 않게) 봇 세션만 `--settings` 로 켠다. 켜기 직전 캐시의 `plugin:discord:discord` 를 지운다 |
| DM 은 오는데 답장이 「not allowlisted」 | claude-plugins-official#6768 (윈도우 · 0.0.4) | 받은 DM 의 보낸 사람이 허용 목록에 있으면 답장을 통과시키는 3줄 패치 (원본 `server.ts.orig`) · 그래도 막히면 서버 채널로 전환 (`-Channel`) |
| 토큰을 못 읽음 | 공식 서버가 `\n` 으로만 나눔 · #6271 | `.env` 의 BOM · CRLF 를 걷어 낸다 |
| 켜졌는데 무반응 | 채널 기능 「사용 불가」 #105326 | 켠 뒤 디스코드 MCP 로그로 판정 (접속 · 사용 불가 · 토큰 · bun) |
| 그래도 안 됨 | 서버 쪽 | 갈래 B · Remote Control (확장 입력칸 `/remote-control` · 휴대폰 Claude 앱) |

**`claude -p` 를 이 흐름에서 쓰지 않는다.** 토큰 없이 도는 세션이 디스코드 서버를 띄웠다 실패하면 같은 캐시가 오염된다.

## 진행 규칙

- 한 번에 한 단계만 진행하고, 단계 끝에서 멈춰 「됐나요?」를 묻는다. 「됐어」면 다음 단계, 막히면 그 자리에서 푼다
- 토큰은 채팅창에 붙여 넣지 않게 한다. 사용자가 붙여 넣으면 쓰지 말고 «Reset Token 으로 새로 받아 토큰등록.cmd 로 넣어 주세요» 라고 답한다. 대화 기록에 남기 때문이다
- 스크립트 출력 맨 끝 `DOCTOR_JSON` 줄로 판정한다. 사용자에게는 ✅ · 🔧 · ⚠️ · ❌ · ⬜ 표만 보여 주고, ❌ 줄의 «→» 할 일을 그대로 안내한다
- 관리자 권한이 필요한 일(백신 예외 등)은 스크립트가 하지 않는다. 필요할 때만 사용자에게 명령을 보여 준다

## 스크립트 부르는 법

먼저 OS 를 본다. 이 스킬 폴더는 `${CLAUDE_SKILL_DIR}` 이다. 실습 폴더는 지금 열린 폴더다.

**윈도우** · Bash 도구(Git Bash)에서

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/doctor.ps1" -Fix -Project "$(pwd -W)"
```

PowerShell 도구만 있으면

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\scripts\doctor.ps1" -Fix -Project (Get-Location).Path
```

**맥**

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/doctor.sh" --fix --project "$(pwd)"
```

`-Fix` · `--fix` 없이 부르면 보기만 한다. 처음에는 `-Fix` 로 부른다. 스크립트가 고치는 것:

- bun 설치 · 사용자 PATH 에 넣기
- 공식 마켓플레이스 추가 · 디스코드 플러그인 설치 (`claude plugin` 명령. `/plugin` 화면이 필요 없다) · **사용자 범위에서 꺼 두기**(격리)
- 인증 캐시의 디스코드 실패 기록 지우기
- DM 답장 우회 패치 (`-NoPatch` 로 건너뜀 · `-Unpatch` 로 되돌림)
- 봇 부품(discord.js) 미리 받기. 봇 첫 기동에서 시간 초과가 나지 않게 한다
- BOM · CRLF 가 붙은 `.env` 고쳐 쓰기
- 실습 폴더에 `봇켜기.cmd` · `토큰등록.cmd` (맥은 `.command`) 와 `.claude/bot/` 스크립트 놓기
- `.claude/settings.local.json` 에 디스코드 답장 도구 허용 한 줄 넣기

---

## 1단계 · 점검과 자동 수리

스크립트를 `-Fix` 로 돌리고 표를 보여 준다.

- ❌ 가 Claude CLI · Git 이면 과제 1 로 돌려보낸다. 안티그래비티를 완전히 종료하고 다시 켠 뒤 다시 돌린다
- 🔧 로 bun · Git 을 새로 깔았으면 «안티그래비티를 완전히 종료하고 다시 켜 주세요. 그다음 «디스코드 봇 점검해줘» 라고 쳐 주세요» 라고 안내한다. 확장이 새 PATH 를 읽어야 플러그인이 bun 을 찾는다
- 토큰 · Intent · 서버 줄이 ⬜ 인 것은 정상이다. 아직 봇을 안 만들었다

묻는다 · «표에서 ❌ 가 Claude CLI · Git · Bun · 마켓플레이스 · 플러그인 줄에 없나요?»

## 2단계 · 봇 만들기 (브라우저 · 5분)

디스코드 서버가 없으면 먼저 만든다 · 디스코드 왼쪽 「+」 → 직접 만들기 → 나와 친구들을 위한 서버 → 이름 「내 봇 서버」.

[discord.com/developers/applications](https://discord.com/developers/applications) 에서

1. 오른쪽 위 **New Application** → 이름 (예 · 「홍길동 비서」) → 동의 → **Create**
2. 왼쪽 **Bot** → **Reset Token** → **Yes, do it!** → **Copy**. 토큰은 이때 한 번만 보인다. 채팅창에 붙여 넣지 않는다
3. 같은 화면 아래 **Privileged Gateway Intents** → **Message Content Intent** 켜기 → 맨 아래 **Save Changes**
4. (권장) 같은 화면 **Public Bot** 끄기 → Save Changes. 남이 이 봇을 자기 서버에 넣지 못한다

서버 초대(OAuth2 URL Generator)는 지금 하지 않는다. 3단계에서 스크립트가 초대 주소를 만들어 준다.

묻는다 · «토큰을 복사했고, Message Content Intent 를 켜고 Save Changes 를 눌렀나요?»

## 3단계 · 토큰 넣기와 서버 초대

1. 실습 폴더의 **토큰등록.cmd** 를 연다 (안티그래비티 왼쪽 파일 목록에서 오른쪽 클릭 → 「파일 탐색기에 표시」 → 두 번 클릭. 또는 터미널에서 `.\토큰등록.cmd`). 맥은 터미널에서 `bash 토큰등록.command`
2. 「토큰」 칸에 마우스 오른쪽 버튼 한 번으로 붙여 넣고 Enter. 글자는 보이지 않는다
3. 창에 봇 이름 · Intent · 서버가 나온다. 「아직 서버에 없습니다」면 나온 주소를 브라우저에 붙여 넣고 → 내 서버 고르기 → **승인** → 캡차

사용자가 «토큰 넣었어» 라고 하면 스크립트를 다시 돌린다 (`-Fix`). 토큰 · Intent · 서버 줄이 ✅ 여야 한다.

- 토큰 ❌ (401) · Reset Token 으로 새로 받아 다시 넣는다
- Intent ❌ · 2단계 3번. **Save Changes** 를 안 누른 경우가 가장 많다
- 서버 ❌ · 표의 초대 주소로 초대

묻는다 · «토큰 · Message Content Intent · 서버 세 줄이 모두 ✅ 인가요?»

## 4단계 · 봇 켜기 (안티그래비티 터미널)

1. 안티그래비티 위 메뉴 **터미널 → 새 터미널** (또는 `Ctrl + \``). 아래에 터미널이 열린다. 폴더가 실습 폴더인지 본다
2. 윈도우 `.\봇켜기.cmd` · 맥 `bash 봇켜기.command` 를 치고 Enter
3. 처음이면 «이 폴더를 신뢰하나요» 가 뜬다 → 신뢰. 로그인 화면이 뜨면 claude.ai 유료 계정으로 로그인
4. 1~2분 안에 디스코드 서버 멤버 목록에서 봇 이름 옆에 **초록 점**이 뜬다

이 터미널은 닫지 않는다. 닫으면 봇도 꺼진다. 확장 채팅창은 그대로 써도 된다.

안 켜질 때

| 보이는 것 | 할 일 |
|---|---|
| 「고칠 것이 있습니다」 | 채팅창에서 이 스킬 1단계를 다시 돈다 |
| `claude` · `bun` 을 찾을 수 없음 | 안티그래비티를 완전히 종료하고 다시 켠다 |
| 시작 화면에 channels 경고 · 「not on the approved allowlist」 | 회사(Team · Enterprise) 계정이다. 관리자가 Channels 를 켜야 한다. 개인 Pro · Max 계정으로 로그인한다 |
| 초록 점이 안 뜬다 (3분 넘게) | 터미널에서 `/mcp` 를 쳐 discord 가 connected 인지 본다. failed 면 채팅창에 «디스코드 봇 점검해줘» |
| 회사 와이파이 | discord.com 이 막혀 있을 수 있다. 휴대폰 핫스팟으로 바꾼다 |

2분이 지나도 초록 점이 없으면 스크립트를 보기 모드로 돌린다. 맨 아래 「마지막 봇 세션」 줄이 원인을 짚는다.

| 「마지막 봇 세션」 | 할 일 |
|---|---|
| ✅ 접속 · 채널 등록 | 디스코드 앱을 껐다 켜서 초록 점을 다시 본다 |
| ❌ 채널 기능이 꺼져 있다 | 개인 Pro · Max 계정인지 본다. 회사 계정이면 관리자가 Channels 를 켠다. 아니면 갈래 B |
| ❌ 토큰을 못 읽었다 | 토큰등록.cmd 다시 → `-Fix` → 봇 터미널 `/exit` → 봇켜기.cmd |
| ❌ bun 을 찾지 못했다 | 안티그래비티를 완전히 종료하고 다시 켠 뒤 봇켜기.cmd |
| ⬜ 아직 켠 적 없음 | 봇 세션이 서버를 안 띄웠다. `-Fix` (격리 · 캐시) → 봇 터미널 `/exit` → 봇켜기.cmd |

묻는다 · «디스코드에서 봇 이름 옆에 초록 점이 보이나요?»

## 5단계 · 페어링 (휴대폰 → 터미널)

1. 휴대폰 디스코드 → 내 서버 → 멤버 목록에서 봇 → **메시지 보내기** → 아무 말 (예 · 「안녕」)
2. 봇이 6자리 코드로 답한다
3. 안티그래비티 **터미널의 봇 세션**에 친다

```
/discord:access pair 받은코드
/discord:access policy allowlist
```

`policy allowlist` 는 나 말고는 아무도 봇에 말을 걸지 못하게 잠그는 줄이다. 꼭 친다.

페어링 사용자가 끝냈다고 하면 스크립트를 보기 모드로 돌려 페어링 줄이 ✅ (allowlist 로 잠김) 인지 본다.

묻는다 · «페어링 줄이 ✅ 인가요?»

## 갈래 A2 · DM 답장이 막힐 때 · 서버 채널로 받기

봇이 DM 을 받는데(터미널에 들어옴) 답장이 「channel … is not allowlisted」 로 실패하면

1. 우회 패치가 들어갔는지 본다 (스크립트 「DM 답장 우회 패치」 줄). 들어갔는데 봇을 그 전에 켰다면 봇 터미널 `/exit` → 봇켜기.cmd
2. 그래도 막히면 서버 채널로 바꾼다. 디스코드 내 서버에 글 채널 「봇」 을 만든다 (채널 만들기 → 비공개로 하지 않아도 된다. 나와 봇만 있는 서버라서)
3. 스크립트를 `-Fix -Channel 봇` 으로 돌린다 (맥은 `--fix --channel 봇`). access.json 에 그 채널이 들어가고, 멘션 없이 내 메시지에만 답한다
4. 휴대폰에서 DM 대신 #봇 채널에 쓴다. 이 경로는 #6768 에서 답장이 된다고 보고됐다

## 갈래 B · 채널이 끝내 안 될 때 · Remote Control

디스코드 없이 휴대폰에서 같은 실습 폴더 세션을 부리는 공식 기능이다. bun · 토큰 · 터미널이 필요 없다.

1. 봇 터미널은 닫는다. 안티그래비티 **Claude Code 확장 입력칸**에 `/remote-control` → **Enable Remote Control**
2. 휴대폰 Claude 앱 → **Code** → 초록 점이 있는 컴퓨터 세션을 연다 (앱이 없으면 확장에서 `/mobile` 의 QR)
3. 4 · 5 · 6교시 휴대폰 문장을 Claude 앱에서 그대로 보낸다. 사진 · 파일 첨부도 된다
4. 예약 알림은 확장에서 `/config` → **Push when Claude decides** 를 켜고, 예약 문장 끝에 «끝나면 휴대폰으로 알려줘» 를 붙인다
5. 회사(Team · Enterprise) 계정은 관리자가 Remote Control 을 켜야 한다

## 6단계 · 첫 대화

휴대폰에서 봇에게

```
지금 폴더에 무엇이 있는지 알려줘
```

- 봇 답장은 디스코드로 온다. 터미널에는 도구 호출과 「sent」만 보인다
- 허용 창이 뜨면 PC 터미널에서 누른다. 디스코드 답장 도구는 이미 허용해 두었다
- 30초 넘게 답이 없으면 터미널을 본다. 허용 창에서 멈춰 있는 경우가 가장 많다

끝나면 이렇게 알린다 · «봇 세팅 끝 · 이 터미널이 켜져 있는 동안 휴대폰에서 일을 시킬 수 있습니다. 실습 폴더의 CLAUDE.md · 스킬 · 에이전트를 봇도 그대로 씁니다.»

---

## 막혔을 때 한눈에

| 증상 | 원인 | 할 일 |
|---|---|---|
| 봇이 오프라인 | 봇 세션이 꺼졌거나 `--channels` 없이 켰다 | `.\봇켜기.cmd` 로 다시 |
| 봇이 온라인인데 DM 에 답이 없다 | Message Content Intent 꺼짐 · 페어링 안 됨 · 허용 창 대기 | 스크립트 점검 → 터미널 확인 |
| DM 은 들어오는데 답장이 「not allowlisted」 | 공식 플러그인 #6768 | 우회 패치 확인 → 갈래 A2 서버 채널 |
| 봇 터미널은 켜졌는데 서버가 안 뜸 (`/mcp` 에 discord 없음 · bun 프로세스 없음) | 인증 캐시 오염 #80822 · 플러그인 격리 안 됨 | `-Fix` → 봇 터미널 `/exit` → 봇켜기.cmd |
| 로그에 「channels feature is not currently available」 | 계정 쪽 채널 기능 꺼짐 #105326 | 개인 계정 확인 → 갈래 B |
| 확장이 시작하자마자 꺼진다 (윈도우 · 2.1.310) | claude-code#105175 Bun 오류 | 확장 → 톱니 → 「다른 버전 설치」 로 한 단계 아래 버전 · 또는 터미널 `claude` 로 진행 |
| 페어링 코드가 안 온다 | 봇과 같은 서버에 있지 않다 · Intent 꺼짐 | 서버 초대 · Intent 확인 |
| 첫 기동에서 discord 가 failed | discord.js 받기가 늦었다 | 점검 스크립트 `-Fix` 가 미리 받는다 → 다시 켠다 |
| 토큰을 넣었는데 「토큰 없음」 | `.env` 에 BOM · 옛 환경 변수 | 점검 스크립트 `-Fix` 가 고친다. 봇켜기.cmd 는 옛 환경 변수를 비우고 켠다 |
| `claude plugin` 이 github 를 못 받는다 | Git 없음 · 회사망 | Git 설치 · 핫스팟 |
| 「이 시스템에서 스크립트를 실행할 수 없으므로」 | 실행 정책 | `.cmd` 로 켠다. 점검 스크립트가 내 계정 정책을 RemoteSigned 로 바꾼다 |
| 백신이 bun 을 막는다 | Defender 실시간 검사 | 관리자 PowerShell 에서 `Add-MpPreference -ExclusionPath "$env:USERPROFILE\.bun"` (강사와 함께) |
| 노트북 덮개를 닫으면 꺼진다 | 절전 | 수업 중에는 덮개를 열어 둔다. 전원 설정에서 절전 안 함 |

## 지키는 것

- 토큰은 `.env` 에만 둔다. 채팅 · 화면 공유 · 깃허브에 올리지 않는다. 새어 나갔으면 Reset Token → 토큰등록.cmd
- `policy allowlist` 로 잠근다. 페어링한 사람은 봇 세션의 허용 창도 승인할 수 있다
- `--dangerously-skip-permissions` 는 쓰지 않는다
