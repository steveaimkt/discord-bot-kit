# discord-bot-kit · 윈도우 점검 · 수리
# 사용 · powershell -NoProfile -ExecutionPolicy Bypass -File doctor.ps1 [-Fix] [-Project <폴더>] [-Channel <채널 이름 또는 ID>] [-NoPatch]
# -Fix 없이 돌리면 보기만 한다. -Fix 를 주면 관리자 권한 없이 고칠 수 있는 것만 고친다.
# -Channel · DM 답장이 막힐 때, 나와 봇만 있는 서버 채널로 받도록 access.json 에 채널을 넣는다
# -NoPatch · DM 답장 우회 패치를 넣지 않는다 (넣은 패치는 -Unpatch 로 되돌린다)
# 이 파일은 UTF-8(BOM) 으로 저장한다. BOM 이 없으면 윈도우 PowerShell 5.1 이 한글을 깨뜨린다.
#
# 설계 (2026-10-27 · 맥에서 재현 확인)
# 1. 디스코드 플러그인은 설치하되 사용자 범위에서 꺼 둔다. 봇 세션만 --settings 로 켠다
#    → 확장 채팅창이 토큰 없이 서버를 띄웠다 실패하며 mcp-needs-auth-cache.json 을 오염시키지 않는다 (claude-code#80822 · #42769)
# 2. 봇을 켜기 전에 그 캐시의 plugin:discord:discord 항목을 지운다
# 3. DM 답장이 「not allowlisted」로 막히는 문제(claude-plugins-official#6768)에 작은 우회 패치를 넣는다
# 4. .env 의 BOM · CRLF 를 고친다 (공식 서버는 \n 으로만 나눠 \r 이 토큰에 붙는다)

param(
  [switch]$Fix,
  [string]$Project = (Get-Location).Path,
  [string]$Channel = '',
  [switch]$NoPatch,
  [switch]$Unpatch
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
# PowerShell 5.1 은 TLS 1.0 으로 붙는 경우가 있어 디스코드 · bun.sh 가 막힌다
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
# 클로드 세션 안에서 claude 하위 명령을 부를 때 막히지 않게
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue

$Market   = 'claude-plugins-official'
$PluginId = "discord@$Market"
$Home_    = $env:USERPROFILE
$BunBin   = Join-Path $Home_ '.bun\bin'
$LocalBin = Join-Path $Home_ '.local\bin'
$StateDir = if ($env:DISCORD_STATE_DIR) { $env:DISCORD_STATE_DIR } else { Join-Path $Home_ '.claude\channels\discord' }
$EnvFile  = Join-Path $StateDir '.env'
$Perms    = 274878008384   # View Channels · Send Messages · Send in Threads · Read History · Attach Files · Add Reactions
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$results = New-Object System.Collections.Generic.List[object]
function Add-R([string]$id, [string]$name, [string]$status, [string]$detail, [string]$todo) {
  $results.Add([pscustomobject]@{ id = $id; name = $name; status = $status; detail = $detail; todo = $todo }) | Out-Null
}
function Has-Cmd([string]$n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Add-UserPath([string]$dir) {
  $u = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $u) { $u = '' }
  if (($u -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($u.TrimEnd(';') + ';' + $dir).TrimStart(';'), 'User')
  }
  if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
}
function Write-Utf8NoBom([string]$path, [string]$text) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}
function Write-Utf8Bom([string]$path, [string]$text) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($true)))
}
function Parse-JsonLoose([string]$s) {
  if (-not $s) { return $null }
  try { return ($s | ConvertFrom-Json) } catch {}
  $i = $s.IndexOfAny([char[]]'[{')
  if ($i -ge 0) { try { return ($s.Substring($i) | ConvertFrom-Json) } catch {} }
  return $null
}
function Run-Claude([string[]]$argv) {
  $out = & claude @argv 2>&1 | Out-String
  return @{ code = $LASTEXITCODE; out = $out }
}

# 이 PowerShell 창이 PATH 를 늦게 읽었어도 찾게 한다
foreach ($d in @($LocalBin, $BunBin)) {
  if ((Test-Path $d) -and (($env:Path -split ';') -notcontains $d)) { $env:Path = "$d;$env:Path" }
}

# 1 · 내 컴퓨터
$os = [Environment]::OSVersion.Version
Add-R 'os' '윈도우 버전' 'ok' ("Windows {0}.{1} build {2} · PowerShell {3}" -f $os.Major, $os.Minor, $os.Build, $PSVersionTable.PSVersion) ''

if ($Home_ -match '[^\x00-\x7F]') {
  Add-R 'home_ascii' '사용자 폴더 이름' 'warn' "한글이 들어 있다 ($Home_)" 'bun 설치가 멈추면 강사에게 알린다. 대부분은 그대로 된다'
} else {
  Add-R 'home_ascii' '사용자 폴더 이름' 'ok' $Home_ ''
}

if ($Project -match 'OneDrive') {
  Add-R 'onedrive' '실습 폴더 위치' 'warn' "OneDrive 안에 있다 ($Project)" '봇이 켜져 있는 동안 OneDrive 동기화를 일시 중지하면 파일 잠김이 없다'
} else {
  Add-R 'onedrive' '실습 폴더 위치' 'ok' $Project ''
}

$pol = Get-ExecutionPolicy -Scope CurrentUser
$eff = Get-ExecutionPolicy
if ($eff -eq 'Restricted' -or $eff -eq 'AllSigned') {
  if ($Fix) {
    try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop; Add-R 'policy' '스크립트 실행 정책' 'fixed' "$eff → RemoteSigned (내 계정만)" '' }
    catch { Add-R 'policy' '스크립트 실행 정책' 'warn' "$eff · 바꾸지 못했다 (회사 정책)" '회사 그룹 정책이면 봇켜기.cmd 도 막힐 수 있다 · 손을 들어 강사에게' }
  } else {
    Add-R 'policy' '스크립트 실행 정책' 'warn' "$eff" '-Fix 로 RemoteSigned 로 바꾼다 (내 계정만)'
  }
} else {
  Add-R 'policy' '스크립트 실행 정책' 'ok' "$eff" ''
}

# 2 · Claude CLI
if (-not (Has-Cmd 'claude') -and (Test-Path (Join-Path $LocalBin 'claude.exe'))) {
  if ($Fix) { Add-UserPath $LocalBin } else { $env:Path = "$LocalBin;$env:Path" }
}
if (Has-Cmd 'claude') {
  $v = (& claude --version 2>&1 | Out-String).Trim()
  $m = [regex]::Match($v, '(\d+)\.(\d+)\.(\d+)')
  $okVer = $false
  if ($m.Success) {
    $maj = [int]$m.Groups[1].Value; $min = [int]$m.Groups[2].Value; $pat = [int]$m.Groups[3].Value
    $okVer = ($maj -gt 2) -or ($maj -eq 2 -and ($min -gt 1 -or ($min -eq 1 -and $pat -ge 80)))
  }
  if ($okVer) { Add-R 'claude' 'Claude CLI' 'ok' $v '' }
  else {
    if ($Fix) {
      # 업데이트 뒤 버전을 다시 읽어 실제로 올라갔을 때만 fixed
      & claude update 2>&1 | Out-Null
      $v2 = (& claude --version 2>&1 | Out-String).Trim()
      $m2 = [regex]::Match($v2, '(\d+)\.(\d+)\.(\d+)')
      $ok2 = $false
      if ($m2.Success) {
        $maj = [int]$m2.Groups[1].Value; $min = [int]$m2.Groups[2].Value; $pat = [int]$m2.Groups[3].Value
        $ok2 = ($maj -gt 2) -or ($maj -eq 2 -and ($min -gt 1 -or ($min -eq 1 -and $pat -ge 80)))
      }
      if ($ok2) { Add-R 'claude' 'Claude CLI' 'fixed' "$v → $v2" '안티그래비티를 껐다 켠다' }
      else { Add-R 'claude' 'Claude CLI' 'fail' "$v · claude update 로 올리지 못했다 (2.1.80 이상 필요)" 'irm https://claude.ai/install.ps1 | iex 로 다시 깐다' }
    }
    else { Add-R 'claude' 'Claude CLI' 'fail' "$v (2.1.80 이상 필요)" 'claude update' }
  }
} else {
  Add-R 'claude' 'Claude CLI' 'fail' '찾을 수 없다' '과제 1 · irm https://claude.ai/install.ps1 | iex → 안티그래비티를 껐다 켠다'
}

# 3 · Git (마켓플레이스를 받을 때 필요)
if (Has-Cmd 'git') {
  Add-R 'git' 'Git' 'ok' ((& git --version 2>&1 | Out-String).Trim()) ''
} elseif ($Fix -and (Has-Cmd 'winget')) {
  & winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
  $gp = 'C:\Program Files\Git\cmd'
  if (Test-Path (Join-Path $gp 'git.exe')) { $env:Path = "$gp;$env:Path"; Add-R 'git' 'Git' 'fixed' 'winget 으로 설치' '안티그래비티를 껐다 켠다' }
  else { Add-R 'git' 'Git' 'fail' 'winget 설치가 끝나지 않았다' 'git-scm.com 에서 윈도우 설치 파일을 받아 설치' }
} else {
  Add-R 'git' 'Git' 'fail' '찾을 수 없다' 'winget install Git.Git 또는 git-scm.com'
}

# 4 · Bun (디스코드 플러그인을 돌리는 바탕)
$bunExe = Join-Path $BunBin 'bun.exe'
if (-not (Has-Cmd 'bun') -and -not (Test-Path $bunExe)) {
  if ($Fix) {
    & powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm bun.sh/install.ps1 | iex" 2>&1 | Out-Null
  }
}
if (Test-Path $bunExe) {
  $onUserPath = (([Environment]::GetEnvironmentVariable('Path', 'User')) -split ';') -contains $BunBin
  if (-not $onUserPath -and $Fix) { Add-UserPath $BunBin }
  if (($env:Path -split ';') -notcontains $BunBin) { $env:Path = "$BunBin;$env:Path" }
  $bv = (& $bunExe --version 2>&1 | Out-String).Trim()
  if ($onUserPath -or $Fix) { Add-R 'bun' 'Bun' 'ok' "$bv · $bunExe" '' }
  else { Add-R 'bun' 'Bun' 'warn' "$bv · 사용자 PATH 에 없다" '-Fix 로 PATH 에 넣는다' }
} elseif (Has-Cmd 'bun') {
  Add-R 'bun' 'Bun' 'ok' ((& bun --version 2>&1 | Out-String).Trim()) ''
} else {
  Add-R 'bun' 'Bun' 'fail' '설치되지 않았다' '-Fix 로 설치. 계속 실패하면 github.com/oven-sh/bun/releases 에서 bun-windows-x64.zip'
}

# 5 · 공식 마켓플레이스와 디스코드 플러그인
$installPath = $null
if (Has-Cmd 'claude') {
  $ml = Parse-JsonLoose (Run-Claude @('plugin', 'marketplace', 'list', '--json')).out
  $hasMarket = $false
  if ($ml) { foreach ($x in @($ml)) { if ($x.name -eq $Market) { $hasMarket = $true } } }
  if (-not $hasMarket -and $Fix) {
    $r = Run-Claude @('plugin', 'marketplace', 'add', 'anthropics/claude-plugins-official')
    $hasMarket = ($r.code -eq 0)
    if ($hasMarket) { Add-R 'market' '공식 마켓플레이스' 'fixed' '추가함' '' }
    else { Add-R 'market' '공식 마켓플레이스' 'fail' ($r.out.Trim() -split "`n" | Select-Object -Last 1) 'Git 이 있는지, 회사 와이파이가 github.com 을 막는지 본다' }
  } elseif ($hasMarket) {
    if ($Fix) { Run-Claude @('plugin', 'marketplace', 'update', $Market) | Out-Null }
    Add-R 'market' '공식 마켓플레이스' 'ok' $Market ''
  } else {
    Add-R 'market' '공식 마켓플레이스' 'fail' '없다' '-Fix 로 추가'
  }

  $pl = Parse-JsonLoose (Run-Claude @('plugin', 'list', '--json')).out
  $p = $null
  if ($pl) { foreach ($x in @($pl)) { if ($x.id -eq $PluginId) { $p = $x } } }
  if (-not $p -and $Fix -and $hasMarket) {
    $r = Run-Claude @('plugin', 'install', $PluginId, '--scope', 'user')
    $pl = Parse-JsonLoose (Run-Claude @('plugin', 'list', '--json')).out
    if ($pl) { foreach ($x in @($pl)) { if ($x.id -eq $PluginId) { $p = $x } } }
    if ($p) { Add-R 'plugin' '디스코드 플러그인' 'fixed' "설치함 v$($p.version)" '' }
    else { Add-R 'plugin' '디스코드 플러그인' 'fail' ($r.out.Trim() -split "`n" | Select-Object -Last 1) 'claude plugin marketplace update claude-plugins-official 뒤 다시' }
  } elseif ($p) {
    Add-R 'plugin' '디스코드 플러그인' 'ok' "v$($p.version)" ''
  } else {
    Add-R 'plugin' '디스코드 플러그인' 'fail' '설치되지 않았다' '-Fix 로 설치'
  }
  # 평소엔 꺼 두고 봇 세션에서만 켠다 (봇켜기.cmd 가 --settings 로 켬)
  if ($p) {
    $pl2 = Parse-JsonLoose (Run-Claude @('plugin', 'list', '--json')).out
    $on = $false
    if ($pl2) { foreach ($x in @($pl2)) { if ($x.id -eq $PluginId -and $x.enabled) { $on = $true } } }
    if ($on -and $Fix) {
      $r = Run-Claude @('plugin', 'disable', $PluginId, '--scope', 'user')
      # 끈 뒤 다시 읽어 실제로 꺼졌을 때만 fixed
      $pl3 = Parse-JsonLoose (Run-Claude @('plugin', 'list', '--json')).out
      $still = $true
      if ($pl3) { foreach ($x in @($pl3)) { if ($x.id -eq $PluginId) { $still = [bool]$x.enabled } } }
      if (-not $still) { Add-R 'isolate' '디스코드 플러그인 격리' 'fixed' '평소엔 꺼 둠 · 봇 세션에서만 켬' '' }
      else { Add-R 'isolate' '디스코드 플러그인 격리' 'fail' '끄지 못했다 · 채팅창도 봇 서버를 띄운다' "claude plugin disable $PluginId --scope user 를 직접 실행" }
    } elseif ($on) {
      Add-R 'isolate' '디스코드 플러그인 격리' 'warn' '모든 세션에서 켜져 있다 · 채팅창도 봇 서버를 띄운다' '-Fix 로 꺼 둔다 (봇켜기.cmd 가 봇 세션에서만 켬)'
    } else {
      Add-R 'isolate' '디스코드 플러그인 격리' 'ok' '평소엔 꺼짐 · 봇 세션에서만 켬' ''
    }
  }
  if ($p) { $installPath = $p.installPath }
}

# 5-1 · 인증 캐시 오염 (토큰 없이 실패한 기록이 남으면 봇 세션이 서버를 조용히 건너뛴다)
$authCache = Join-Path $Home_ '.claude\mcp-needs-auth-cache.json'
if (Test-Path $authCache) {
  $ac = Parse-JsonLoose ([IO.File]::ReadAllText($authCache))
  if ($ac -and ($ac.PSObject.Properties.Name -contains 'plugin:discord:discord')) {
    if ($Fix) {
      $ac.PSObject.Properties.Remove('plugin:discord:discord')
      Write-Utf8NoBom $authCache ($ac | ConvertTo-Json -Depth 10 -Compress)
      Add-R 'authcache' '인증 캐시' 'fixed' '디스코드 실패 기록을 지움' ''
    } else {
      Add-R 'authcache' '인증 캐시' 'fail' '디스코드 실패 기록이 남아 봇 서버가 안 뜰 수 있다' '-Fix 로 지운다 (봇켜기.cmd 도 켜기 전에 지움)'
    }
  } else { Add-R 'authcache' '인증 캐시' 'ok' '디스코드 실패 기록 없음' '' }
}

# 5-2 · DM 답장 막힘 우회 패치 (claude-plugins-official#6768)
#   받은 DM 의 보낸 사람이 허용 목록에 있으면, 채널 종류 판정과 상관없이 답장을 통과시킨다.
#   보낸 사람이 이미 받는 쪽 허용 판정을 통과한 경우에만 해당해서 열리는 범위는 그대로다.
$Marker = 'discord-bot-kit patch'
if ($installPath -and (Test-Path (Join-Path $installPath 'server.ts'))) {
  $srv = Join-Path $installPath 'server.ts'
  $code = [IO.File]::ReadAllText($srv)
  $bak = "$srv.orig"
  if ($Unpatch) {
    if (Test-Path $bak) { Copy-Item $bak $srv -Force; Add-R 'patch' 'DM 답장 우회 패치' 'fixed' '되돌림 (원본 복구)' '' }
    else { Add-R 'patch' 'DM 답장 우회 패치' 'ok' '넣은 적 없음' '' }
  } elseif ($code.Contains($Marker)) {
    Add-R 'patch' 'DM 답장 우회 패치' 'ok' '들어가 있음' ''
  } elseif ($NoPatch) {
    Add-R 'patch' 'DM 답장 우회 패치' 'warn' '넣지 않음 (-NoPatch)' 'DM 답장이 막히면 -Channel 로 서버 채널을 쓴다'
  } else {
    $fn = $code.IndexOf('async function fetchAllowedChannel(')
    $anchor = 'const access = loadAccess()'
    $at = -1; if ($fn -ge 0) { $at = $code.IndexOf($anchor, $fn) }
    if ($at -lt 0) {
      Add-R 'patch' 'DM 답장 우회 패치' 'warn' '플러그인 코드가 바뀌어 넣지 못함 (새 버전이면 고쳐졌을 수 있음)' 'DM 답장이 막히면 -Channel 로 서버 채널을 쓴다'
    } elseif ($Fix) {
      $nl = "`n"; if ($code.Contains("`r`n")) { $nl = "`r`n" }
      $lineEnd = $code.IndexOf("`n", $at) + 1
      $ins = "  // $Marker · DM 답장 막힘 우회 (claude-plugins-official#6768)$nl" +
             "  const knownDmUser = dmChannelUsers.get(id)$nl" +
             "  if (knownDmUser && access.allowFrom.includes(knownDmUser)) return ch$nl"
      if (-not (Test-Path $bak)) { Copy-Item $srv $bak }
      [IO.File]::WriteAllText($srv, $code.Insert($lineEnd, $ins), (New-Object System.Text.UTF8Encoding($false)))
      Add-R 'patch' 'DM 답장 우회 패치' 'fixed' '넣음 · 원본은 server.ts.orig' '봇이 이미 켜져 있으면 /exit 뒤 봇켜기.cmd 로 다시 켠다'
    } else {
      Add-R 'patch' 'DM 답장 우회 패치' 'warn' '아직 안 넣음' '-Fix 로 넣는다'
    }
  }
}

# 6 · 첫 실행 준비 (discord.js 를 미리 받아 두면 봇 첫 기동에서 시간 초과가 안 난다)
if ($installPath -and (Test-Path $installPath)) {
  $djs = Join-Path $installPath 'node_modules\discord.js'
  if (Test-Path $djs) {
    Add-R 'deps' '봇 부품 (discord.js)' 'ok' '미리 받아 둠' ''
  } elseif ($Fix -and (Test-Path $bunExe)) {
    Push-Location $installPath
    $o = & $bunExe install --no-summary 2>&1 | Out-String
    Pop-Location
    if (Test-Path $djs) { Add-R 'deps' '봇 부품 (discord.js)' 'fixed' '미리 받음' '' }
    else { Add-R 'deps' '봇 부품 (discord.js)' 'fail' (($o.Trim() -split "`n") | Select-Object -Last 1) '백신이 막는지 본다. 휴대폰 핫스팟으로 다시' }
  } else {
    Add-R 'deps' '봇 부품 (discord.js)' 'warn' '아직 안 받음' '-Fix 로 미리 받는다'
  }
}

# 7 · 봇 토큰 파일
$token = $null
if (Test-Path $EnvFile) {
  $bytes = [IO.File]::ReadAllBytes($EnvFile)
  $bad = ''
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $bad = 'UTF-8 BOM' }
  elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $bad = 'UTF-16' }
  # 공식 서버는 \n 으로만 나눠서 CRLF 면 토큰 끝에 \r 이 붙어 로그인에 실패한다
  if ([Array]::IndexOf($bytes, [byte]13) -ge 0) { $bad = ($bad + ' CRLF 줄바꿈').Trim() }
  $text = [IO.File]::ReadAllText($EnvFile)
  foreach ($line in ($text -split "`r?`n")) {
    $l = $line.Trim().TrimStart([char]0xFEFF)
    if ($l -match '^\s*DISCORD_BOT_TOKEN\s*=\s*(.+)$') { $token = $Matches[1].Trim().Trim('"').Trim("'") }
  }
  if ($token -and $token.StartsWith('Bot ')) { $token = $token.Substring(4).Trim(); $bad = ($bad + ' Bot 머리말').Trim() }
  if ($bad -and $token) {
    if ($Fix) { Write-Utf8NoBom $EnvFile "DISCORD_BOT_TOKEN=$token`n"; Add-R 'envfile' '토큰 파일 (.env)' 'fixed' "$bad → 고쳐 씀" '' }
    else { Add-R 'envfile' '토큰 파일 (.env)' 'fail' "$bad 때문에 봇이 토큰을 못 읽는다" '-Fix 로 고쳐 쓴다' }
  } elseif ($token) {
    Add-R 'envfile' '토큰 파일 (.env)' 'ok' $EnvFile ''
  } else {
    Add-R 'envfile' '토큰 파일 (.env)' 'fail' 'DISCORD_BOT_TOKEN 줄이 없다' '토큰등록.cmd 를 다시 실행'
  }
} else {
  Add-R 'envfile' '토큰 파일 (.env)' 'todo' '아직 없다' '토큰등록.cmd 를 실행해 토큰을 넣는다'
}
$envTok = [Environment]::GetEnvironmentVariable('DISCORD_BOT_TOKEN', 'User')
if ($envTok -or $env:DISCORD_BOT_TOKEN) {
  Add-R 'envvar' '환경 변수 DISCORD_BOT_TOKEN' 'warn' '설정돼 있어 .env 보다 먼저 읽힌다' '봇켜기.cmd 는 이 값을 비우고 켠다. 옛 토큰이면 지운다'
}

# 8 · 디스코드에 직접 물어보기 (토큰 · Message Content Intent · 서버 초대)
$bot = $null; $app = $null
if ($token) {
  # PowerShell 5.1 은 -Headers 에 User-Agent 를 넣으면 오류가 난다. -UserAgent 로 따로 준다
  $h = @{ Authorization = "Bot $token" }
  $PSDefaultParameterValues['Invoke-RestMethod:UserAgent'] = 'DiscordBot (discord-bot-kit, 0.1)'
  try {
    $bot = Invoke-RestMethod -Uri 'https://discord.com/api/v10/users/@me' -Headers $h -TimeoutSec 15 -ErrorAction Stop
    Add-R 'token' '토큰' 'ok' "봇 이름 · $($bot.username)" ''
  } catch {
    $code = $null
    try { $code = $_.Exception.Response.StatusCode.value__ } catch {}
    if ($code -eq 401) { Add-R 'token' '토큰' 'fail' '디스코드가 거절했다 (401)' 'Developer Portal → Bot → Reset Token → 토큰등록.cmd 다시' }
    else { Add-R 'token' '토큰' 'fail' "디스코드에 닿지 않는다 ($($_.Exception.Message))" '회사 와이파이가 discord.com 을 막는지 본다. 휴대폰 핫스팟으로 다시' }
  }
  if ($bot) {
    try {
      $app = Invoke-RestMethod -Uri 'https://discord.com/api/v10/applications/@me' -Headers $h -TimeoutSec 15 -ErrorAction Stop
      $flags = [int64]$app.flags
      $intentOn = (($flags -band 524288) -ne 0) -or (($flags -band 262144) -ne 0)
      if ($intentOn) { Add-R 'intent' 'Message Content Intent' 'ok' '켜짐' '' }
      else { Add-R 'intent' 'Message Content Intent' 'fail' '꺼짐 · 봇이 메시지를 못 읽는다' 'Developer Portal → Bot → Privileged Gateway Intents → Message Content Intent 켜고 Save Changes' }
      if ($app.bot_public) { Add-R 'public' 'Public Bot' 'warn' '켜짐 · 아무나 이 봇을 자기 서버에 넣을 수 있다' 'Developer Portal → Bot → Public Bot 끄기 (권장)' }
    } catch { Add-R 'intent' 'Message Content Intent' 'warn' '확인하지 못했다' 'Developer Portal 에서 직접 본다' }
    try {
      $guilds = @(Invoke-RestMethod -Uri 'https://discord.com/api/v10/users/@me/guilds' -Headers $h -TimeoutSec 15 -ErrorAction Stop)
      $invite = "https://discord.com/oauth2/authorize?client_id=$($bot.id)&scope=bot&permissions=$Perms"
      if ($guilds.Count -gt 0) { Add-R 'guild' '봇이 들어간 서버' 'ok' (($guilds | ForEach-Object { $_.name }) -join ', ') '' }
      else { Add-R 'guild' '봇이 들어간 서버' 'fail' '아직 아무 서버에도 없다' "이 주소를 브라우저로 열어 내 서버에 초대 · $invite" }
    } catch { Add-R 'guild' '봇이 들어간 서버' 'warn' '확인하지 못했다' '' }
  }
}

# 9 · 페어링 상태
$acc = Join-Path $StateDir 'access.json'
if (-not $h -and $token) { $h = @{ Authorization = "Bot $token" } }
if (Test-Path $acc) {
  $a = Parse-JsonLoose ([IO.File]::ReadAllText($acc))
  $n = 0; if ($a -and $a.allowFrom) { $n = @($a.allowFrom).Count }
  $pol2 = 'pairing'; if ($a -and $a.dmPolicy) { $pol2 = $a.dmPolicy }
  if ($n -gt 0 -and $pol2 -eq 'allowlist') { Add-R 'pair' '페어링' 'ok' "허용 $n 명 · allowlist 로 잠김" '' }
  elseif ($n -gt 0) { Add-R 'pair' '페어링' 'warn' "허용 $n 명 · 정책 $pol2" '봇 세션에서 /discord:access policy allowlist' }
  else { Add-R 'pair' '페어링' 'todo' '아직 아무도 없다' '봇에 DM → 받은 코드로 /discord:access pair <코드>' }
} else {
  Add-R 'pair' '페어링' 'todo' '아직 안 함' '봇을 켠 뒤 봇에 DM → /discord:access pair <코드>'
}

# 9-1 · 서버 채널로 받기 (-Channel) · DM 답장이 막힐 때의 우회 (claude-plugins-official#6768 에 보고된 방법)
if ($Channel -and $bot -and $token) {
  $owners = @()
  if (Test-Path $acc) { $a2 = Parse-JsonLoose ([IO.File]::ReadAllText($acc)); if ($a2 -and $a2.allowFrom) { $owners = @($a2.allowFrom) } }
  if ($owners.Count -eq 0) {
    Add-R 'channel' '서버 채널로 받기' 'fail' '페어링이 아직 안 돼 내 ID 를 모른다' '먼저 봇에 DM 을 보내 페어링한 뒤 다시'
  } else {
    $found = $null
    try {
      $gs = @(Invoke-RestMethod -Uri 'https://discord.com/api/v10/users/@me/guilds' -Headers $h -TimeoutSec 15 -ErrorAction Stop)
      foreach ($g in $gs) {
        $chs = @(Invoke-RestMethod -Uri "https://discord.com/api/v10/guilds/$($g.id)/channels" -Headers $h -TimeoutSec 15 -ErrorAction Stop)
        foreach ($c in $chs) { if ($c.type -eq 0 -and ($c.id -eq $Channel -or $c.name -eq $Channel.TrimStart('#'))) { $found = $c } }
      }
    } catch {}
    if (-not $found) {
      Add-R 'channel' '서버 채널로 받기' 'fail' "「$Channel」 채널을 찾지 못했다" '디스코드 서버에 그 이름의 글 채널을 만들고, 봇이 볼 수 있게 한 뒤 다시'
    } elseif ($Fix) {
      $a3 = Parse-JsonLoose ([IO.File]::ReadAllText($acc))
      if (-not ($a3.PSObject.Properties.Name -contains 'groups') -or -not $a3.groups) { $a3 | Add-Member -NotePropertyName groups -NotePropertyValue ([pscustomobject]@{}) -Force }
      $entry = [pscustomobject]@{ requireMention = $false; allowFrom = $owners }
      $a3.groups | Add-Member -NotePropertyName ([string]$found.id) -NotePropertyValue $entry -Force
      Write-Utf8NoBom $acc ($a3 | ConvertTo-Json -Depth 10)
      Add-R 'channel' '서버 채널로 받기' 'fixed' "#$($found.name) 에서 내 메시지에 답한다 (멘션 없이)" '휴대폰에서 DM 대신 이 채널에 쓴다'
    } else {
      Add-R 'channel' '서버 채널로 받기' 'todo' "#$($found.name) 를 찾음" '-Fix 와 함께 다시'
    }
  }
}

# 9-2 · 마지막으로 켠 봇 세션의 상태 (디스코드 MCP 로그)
$logRoot = Join-Path $env:LOCALAPPDATA 'claude-cli-nodejs\Cache'
if (Test-Path $logRoot) {
  $last = Get-ChildItem -Path $logRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'mcp-logs-plugin-discord-discord' } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem -Path $_ -File -ErrorAction SilentlyContinue } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($last) {
    $log = [IO.File]::ReadAllText($last.FullName)
    $when = $last.LastWriteTime.ToString('MM-dd HH:mm')
    # 로그의 「마지막」 상태 줄로 판정한다. 등록 뒤 끊긴 세션을 ✅ 로 보지 않는다.
    # DM 을 받거나 답한 줄이 있어야 디스코드 접속으로 본다 (등록만으로는 접속을 알 수 없다)
    $state = ''
    foreach ($line in ($log -split "`n")) {
      if ($line -match 'channels feature is not currently available') { $state = 'feature' }
      if ($line -match 'DISCORD_BOT_TOKEN required') { $state = 'token' }
      if ($line -match 'Executable not found|ENOENT') { $state = 'bun' }
      if ($line -match 'login failed') { $state = 'login' }
      if ($line -match 'Connection failed|CONNECTION_CLOSED') { $state = 'closed' }
      if ($line -match 'Channel notifications registered') { $state = 'registered' }
      if ($line -match "gateway connected|notifications/claude/channel|Tool 'reply' completed") { $state = 'talking' }
    }
    switch ($state) {
      'feature' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'fail' '채널 기능이 이 계정에서 꺼져 있다 (서버 쪽)' '개인 Pro · Max 계정인지 본다. 회사 계정이면 관리자가 Channels 를 켠다. 계속 안 되면 대체 경로(Remote Control)로 간다' }
      'token' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'fail' '봇 서버가 토큰을 못 읽었다' '토큰등록.cmd 다시 · -Fix 로 .env 를 고친다' }
      'bun' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'fail' 'bun 을 찾지 못했다' '봇켜기.cmd 로 켠다 (bun 경로를 붙여 켬). 안 되면 -Fix' }
      'login' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'fail' '디스코드 로그인에 실패했다 · 토큰이 틀렸거나 Reset 됐다' '개발자 포털에서 토큰을 새로 받아 토큰등록.cmd 다시' }
      'closed' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'fail' '봇 서버가 끊겼다' "봇켜기.cmd 로 다시 켠다 · 로그 · $($last.FullName)" }
      'talking' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'ok' '디스코드 DM 을 주고받았다' '' }
      'registered' { Add-R 'botlog' "마지막 봇 세션 ($when)" 'warn' '채널은 등록됐다 · 디스코드 접속은 아직 확인 전' '휴대폰에서 봇에게 DM 을 한 번 보낸다' }
      default { Add-R 'botlog' "마지막 봇 세션 ($when)" 'warn' '접속 여부를 로그에서 찾지 못했다' "로그 · $($last.FullName)" }
    }
  } else {
    Add-R 'botlog' '마지막 봇 세션' 'todo' '아직 켠 적 없음' '봇켜기.cmd'
  }
}

# 10 · 실습 폴더에 실행 파일 · 권한 설정 놓기
if ($Fix -and (Test-Path $Project)) {
  $botDir = Join-Path $Project '.claude\bot'
  foreach ($f in @('start-bot.ps1', 'set-token.ps1')) {
    $src = Join-Path $ScriptDir $f
    if (Test-Path $src) { Write-Utf8Bom (Join-Path $botDir $f) ([IO.File]::ReadAllText($src)) }
  }
  $crlf = "`r`n"
  $start = '@echo off' + $crlf + 'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\bot\start-bot.ps1"' + $crlf + 'pause' + $crlf
  $tok   = '@echo off' + $crlf + 'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\bot\set-token.ps1"' + $crlf + 'pause' + $crlf
  [IO.File]::WriteAllText((Join-Path $Project '봇켜기.cmd'), $start, [Text.Encoding]::ASCII)
  [IO.File]::WriteAllText((Join-Path $Project '토큰등록.cmd'), $tok, [Text.Encoding]::ASCII)

  # 봇 세션이 디스코드 답장마다 허용 창을 띄우지 않게
  $sp = Join-Path $Project '.claude\settings.local.json'
  $s = $null
  if (Test-Path $sp) { $s = Parse-JsonLoose ([IO.File]::ReadAllText($sp)) }
  if (-not $s) { $s = [pscustomobject]@{} }
  if (-not ($s.PSObject.Properties.Name -contains 'permissions')) { $s | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) }
  if (-not ($s.permissions.PSObject.Properties.Name -contains 'allow')) { $s.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @() }
  $allow = @($s.permissions.allow)
  if ($allow -notcontains 'mcp__plugin_discord_discord') { $allow += 'mcp__plugin_discord_discord' }
  $s.permissions.allow = $allow
  Write-Utf8NoBom $sp ($s | ConvertTo-Json -Depth 20)
  Add-R 'launcher' '봇켜기.cmd · 토큰등록.cmd' 'fixed' $Project ''
} elseif (Test-Path (Join-Path $Project '봇켜기.cmd')) {
  Add-R 'launcher' '봇켜기.cmd · 토큰등록.cmd' 'ok' $Project ''
} else {
  Add-R 'launcher' '봇켜기.cmd · 토큰등록.cmd' 'todo' '아직 없다' '-Fix 로 실습 폴더에 만든다'
}

# 보고
$mark = @{ ok = '✅'; fixed = '🔧'; warn = '⚠️'; fail = '❌'; todo = '⬜' }
Write-Output ''
Write-Output '디스코드 봇 점검 결과'
Write-Output '─────────────────────'
foreach ($r in $results) {
  $line = '{0} {1} · {2}' -f $mark[$r.status], $r.name, $r.detail
  Write-Output $line
  if ($r.todo) { Write-Output ('    → ' + $r.todo) }
}
$fails = @($results | Where-Object { $_.status -eq 'fail' }).Count
$todos = @($results | Where-Object { $_.status -eq 'todo' }).Count
Write-Output ''
Write-Output ('막힘 {0} · 할 일 {1}' -f $fails, $todos)
$summary = [pscustomobject]@{ os = 'windows'; fix = [bool]$Fix; fails = $fails; todos = $todos; items = $results }
Write-Output ('DOCTOR_JSON ' + ($summary | ConvertTo-Json -Depth 6 -Compress))
