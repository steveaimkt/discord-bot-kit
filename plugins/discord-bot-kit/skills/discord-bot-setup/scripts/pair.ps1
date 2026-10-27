# 채팅창에서 페어링 · 공식 /discord:access pair <코드> + policy allowlist 와 같은 일을 한다
# 쓰는 법 · powershell -NoProfile -ExecutionPolicy Bypass -File pair.ps1 -Code <6자리 코드>
#          (코드 없이 돌리면 대기 중인 코드만 보여 준다)
# 봇 서버는 메시지마다 access.json 을 새로 읽고 approved\ 폴더를 살펴 「Paired!」 를 보낸다
param([string]$Code = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$StateDir = if ($env:DISCORD_STATE_DIR) { $env:DISCORD_STATE_DIR } else { Join-Path $env:USERPROFILE '.claude\channels\discord' }
$path = Join-Path $StateDir 'access.json'
$utf8 = New-Object Text.UTF8Encoding($false)

$a = $null
if (Test-Path $path) {
  try { $a = [IO.File]::ReadAllText($path).TrimStart([char]0xFEFF) | ConvertFrom-Json }
  catch { Write-Output "PAIR_FAIL access.json 을 읽지 못했다 · $($_.Exception.Message)"; exit 1 }
}
if (-not $a) { $a = [pscustomobject]@{} }
foreach ($k in 'dmPolicy','allowFrom','groups','pending') {
  if (-not ($a.PSObject.Properties.Name -contains $k)) {
    $v = switch ($k) { 'dmPolicy' { 'pairing' } 'allowFrom' { @() } default { [pscustomobject]@{} } }
    $a | Add-Member -NotePropertyName $k -NotePropertyValue $v
  }
}
$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$Code = $Code.Trim()

if (-not $Code) {
  $live = @($a.pending.PSObject.Properties | Where-Object { [int64]$_.Value.expiresAt -ge $now } | ForEach-Object { $_.Name })
  $codes = if ($live.Count) { $live -join ', ' } else { '없음' }
  Write-Output "PAIR_STATUS 정책 $($a.dmPolicy) · 허용 $(@($a.allowFrom).Count)명 · 대기 코드 $codes"
  exit 0
}

$p = $a.pending.PSObject.Properties[$Code]
if (-not $p) { Write-Output "PAIR_FAIL 코드 $Code 가 대기 목록에 없다 · 봇이 켜진 상태에서 DM 을 다시 보내 새 코드를 받는다"; exit 1 }
if ([int64]$p.Value.expiresAt -lt $now) {
  $a.pending.PSObject.Properties.Remove($Code)
  [IO.File]::WriteAllText($path, ($a | ConvertTo-Json -Depth 10), $utf8)
  Write-Output "PAIR_FAIL 코드 $Code 는 만료됐다 · DM 을 다시 보내 새 코드를 받는다"; exit 1
}
$sid = [string]$p.Value.senderId; $cid = [string]$p.Value.chatId
$allow = @($a.allowFrom | ForEach-Object { [string]$_ })
if ($allow -notcontains $sid) { $allow += $sid }
$a.allowFrom = $allow
$a.pending.PSObject.Properties.Remove($Code)
$a.dmPolicy = 'allowlist'
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
[IO.File]::WriteAllText($path, ($a | ConvertTo-Json -Depth 10), $utf8)
$approved = Join-Path $StateDir 'approved'
New-Item -ItemType Directory -Force -Path $approved | Out-Null
[IO.File]::WriteAllText((Join-Path $approved $sid), $cid, $utf8)
Write-Output "PAIR_OK $sid 를 허용했다 · 정책 allowlist 로 잠금 · 봇이 DM 으로 「Paired!」 를 보낸다"
