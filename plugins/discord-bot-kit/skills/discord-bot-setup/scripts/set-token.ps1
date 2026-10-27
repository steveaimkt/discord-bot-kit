# discord-bot-kit · 봇 토큰 넣기 (토큰등록.cmd 가 부른다)
# 토큰을 채팅창에 붙여 넣지 않게 하려고 따로 둔 창이다. 토큰은 화면에 보이지 않는다.
# 이 파일은 UTF-8(BOM) 으로 저장한다.

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$PSDefaultParameterValues['Invoke-RestMethod:UserAgent'] = 'DiscordBot (discord-bot-kit, 0.1)'

$StateDir = if ($env:DISCORD_STATE_DIR) { $env:DISCORD_STATE_DIR } else { Join-Path $env:USERPROFILE '.claude\channels\discord' }
$EnvFile = Join-Path $StateDir '.env'
$Perms = 274878008384

Write-Host ''
Write-Host '디스코드 봇 토큰 넣기' -ForegroundColor Cyan
Write-Host 'Developer Portal → Bot → Reset Token 으로 복사한 토큰을 붙여 넣습니다.'
Write-Host '붙여 넣기는 창 안에서 마우스 오른쪽 버튼 한 번입니다. 글자는 보이지 않아도 들어갑니다.'
Write-Host ''

for ($try = 1; $try -le 3; $try++) {
  $sec = Read-Host '토큰' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  # 붙여 넣을 때 따라온 줄바꿈 · 공백 · 따옴표를 모두 걷어 낸다 (\r 이 남으면 공식 서버가 토큰을 못 쓴다)
  $token = ($token -replace '\s', '').Trim('"').Trim("'")
  if ($token.StartsWith('Bot')) { $token = $token.Substring(3) }
  if (($token -split '\.').Count -ne 3) {
    Write-Host '토큰 모양이 아닙니다. 점(.)으로 나뉜 세 덩어리여야 합니다. 다시 붙여 넣어 주세요.' -ForegroundColor Yellow
    continue
  }
  try {
    $bot = Invoke-RestMethod -Uri 'https://discord.com/api/v10/users/@me' -Headers @{ Authorization = "Bot $token" } -TimeoutSec 15 -ErrorAction Stop
  } catch {
    $code = $null
    try { $code = $_.Exception.Response.StatusCode.value__ } catch {}
    if ($code -eq 401) { Write-Host '디스코드가 이 토큰을 거절했습니다. Reset Token 으로 새로 받아 붙여 넣어 주세요.' -ForegroundColor Yellow; continue }
    Write-Host "디스코드에 닿지 않습니다 ($($_.Exception.Message)). 토큰은 저장하고 넘어갑니다." -ForegroundColor Yellow
    $bot = $null
  }

  if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
  # BOM 이 붙으면 봇이 토큰을 못 읽는다. BOM 없는 UTF-8 로 쓴다
  [IO.File]::WriteAllText($EnvFile, "DISCORD_BOT_TOKEN=$token`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ''
  Write-Host "저장했습니다 · $EnvFile" -ForegroundColor Green

  if ($bot) {
    Write-Host "봇 이름 · $($bot.username)"
    try {
      $app = Invoke-RestMethod -Uri 'https://discord.com/api/v10/applications/@me' -Headers @{ Authorization = "Bot $token" } -TimeoutSec 15 -ErrorAction Stop
      $flags = [int64]$app.flags
      if ((($flags -band 524288) -ne 0) -or (($flags -band 262144) -ne 0)) { Write-Host 'Message Content Intent · 켜짐' -ForegroundColor Green }
      else { Write-Host 'Message Content Intent · 꺼짐 → Developer Portal → Bot → Message Content Intent 켜고 Save Changes' -ForegroundColor Red }
    } catch {}
    try {
      $guilds = @(Invoke-RestMethod -Uri 'https://discord.com/api/v10/users/@me/guilds' -Headers @{ Authorization = "Bot $token" } -TimeoutSec 15 -ErrorAction Stop)
      if ($guilds.Count -gt 0) { Write-Host ('들어간 서버 · ' + (($guilds | ForEach-Object { $_.name }) -join ', ')) -ForegroundColor Green }
      else {
        $invite = "https://discord.com/oauth2/authorize?client_id=$($bot.id)&scope=bot&permissions=$Perms"
        Write-Host '아직 서버에 없습니다. 아래 주소를 브라우저로 열어 내 서버에 초대합니다.' -ForegroundColor Yellow
        Write-Host $invite
        try { Set-Clipboard -Value $invite; Write-Host '(주소를 복사해 두었습니다. 브라우저 주소창에 붙여 넣으면 됩니다)' } catch {}
      }
    } catch {}
  }
  Write-Host ''
  Write-Host '이 창을 닫고 채팅창으로 돌아가 «토큰 넣었어» 라고 칩니다.'
  exit 0
}
Write-Host '세 번 모두 실패했습니다. 채팅창에 «토큰이 안 들어가» 라고 칩니다.' -ForegroundColor Red
exit 1
