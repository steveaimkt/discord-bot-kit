#!/bin/bash
# 채팅창에서 페어링 · 공식 /discord:access pair <코드> + policy allowlist 와 같은 일을 한다
# 쓰는 법 · bash pair.sh <6자리 코드>     (코드 없이 돌리면 대기 중인 코드만 보여 준다)
# 봇 서버는 메시지마다 access.json 을 새로 읽고 approved/ 폴더를 살펴 「Paired!」 를 보낸다
STATE_DIR="${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord}"
CODE="$1"
python3 - "$STATE_DIR" "$CODE" <<'PY'
import json, os, sys, time
state, code = sys.argv[1], sys.argv[2].strip()
path = os.path.join(state, 'access.json')
try:
    a = json.load(open(path, encoding='utf-8-sig'))
except FileNotFoundError:
    a = {}
except Exception as e:
    print(f"PAIR_FAIL access.json 을 읽지 못했다 · {e}"); sys.exit(1)
a.setdefault('dmPolicy', 'pairing'); a.setdefault('allowFrom', []); a.setdefault('groups', {}); a.setdefault('pending', {})
now = int(time.time() * 1000)
if not code:
    live = {k: v for k, v in a['pending'].items() if v.get('expiresAt', 0) >= now}
    print(f"PAIR_STATUS 정책 {a['dmPolicy']} · 허용 {len(a['allowFrom'])}명 · 대기 코드 {', '.join(live) or '없음'}")
    sys.exit(0)
p = a['pending'].get(code)
if not p:
    print(f"PAIR_FAIL 코드 {code} 가 대기 목록에 없다 · 봇이 켜진 상태에서 DM 을 다시 보내 새 코드를 받는다"); sys.exit(1)
if p.get('expiresAt', 0) < now:
    del a['pending'][code]
    json.dump(a, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f"PAIR_FAIL 코드 {code} 는 만료됐다 · DM 을 다시 보내 새 코드를 받는다"); sys.exit(1)
sid, cid = str(p['senderId']), str(p['chatId'])
if sid not in a['allowFrom']: a['allowFrom'].append(sid)
del a['pending'][code]
a['dmPolicy'] = 'allowlist'
os.makedirs(state, exist_ok=True)
json.dump(a, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
os.makedirs(os.path.join(state, 'approved'), exist_ok=True)
open(os.path.join(state, 'approved', sid), 'w').write(cid)
print(f"PAIR_OK {sid} 를 허용했다 · 정책 allowlist 로 잠금 · 봇이 DM 으로 「Paired!」 를 보낸다")
PY
