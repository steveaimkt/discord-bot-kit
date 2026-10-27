# discord-bot-kit · 봇 켜기 (봇켜기.cmd 가 부른다)
# 이 창이 열려 있는 동안만 봇이 답한다. 닫으면 봇도 꺼진다.
# 이 파일은 UTF-8(BOM) 으로 저장한다.

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}

# 실습 폴더 = 이 파일의 두 단계 위 (실습폴더\.claude\bot\start-bot.ps1)
$Project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
Set-Location -LiteralPath $Project

# 안티그래비티를 다시 켜지 않아도 bun · claude 를 찾게
foreach ($d in @((Join-Path $env:USERPROFILE '.local\bin'), (Join-Path $env:USERPROFILE '.bun\bin'))) {
  if ((Test-Path $d) -and (($env:Path -split ';') -notcontains $d)) { $env:Path = "$d;$env:Path" }
}
# 예전에 넣어 둔 환경 변수가 .env 보다 먼저 읽히지 않게
Remove-Item Env:DISCORD_BOT_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue
# 첫 기동 때 discord.js 를 받느라 늦어도 끊기지 않게
$env:MCP_TIMEOUT = '120000'

$StateDir = if ($env:DISCORD_STATE_DIR) { $env:DISCORD_STATE_DIR } else { Join-Path $env:USERPROFILE '.claude\channels\discord' }
$problems = @()
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $problems += 'Claude CLI 를 찾을 수 없습니다' }
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) { $problems += 'bun 을 찾을 수 없습니다' }
if (-not (Test-Path (Join-Path $StateDir '.env'))) { $problems += '봇 토큰이 없습니다 (토큰등록.cmd)' }
if (-not (Test-Path (Join-Path $env:USERPROFILE '.claude\plugins\cache\claude-plugins-official\discord'))) { $problems += '디스코드 플러그인이 설치되지 않았습니다' }

if ($problems.Count -gt 0) {
  Write-Host ''
  Write-Host '봇을 켜기 전에 고칠 것이 있습니다.' -ForegroundColor Yellow
  foreach ($p in $problems) { Write-Host " · $p" }
  Write-Host ''
  Write-Host '안티그래비티 채팅창에 «디스코드 봇 점검해줘» 라고 칩니다.'
  exit 1
}

Write-Host ''
Write-Host "봇을 켭니다 · $Project" -ForegroundColor Cyan
Write-Host '디스코드에서 봇 이름 옆에 초록 점이 뜨면 켜진 것입니다.'
Write-Host '처음 켤 때는 1~2분 걸릴 수 있습니다. 이 창은 닫지 않습니다.'
Write-Host ''
& claude --channels plugin:discord@claude-plugins-official --permission-mode acceptEdits
