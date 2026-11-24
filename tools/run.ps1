# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 test
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 shot 0
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 import
#
# 为什么要这个脚本：Godot 是 Windows GUI 子系统程序，直接 & $godot ... 时
# stdout/stderr 不会挂到控制台，报错信息全部丢失，只能靠重定向到文件才看得到。

param(
	[ValidateSet("test", "shot", "import", "headless")]
	[string]$Mode = "test",
	[string]$Arg = ""
)

$ErrorActionPreference = 'Continue'
$proj = Split-Path -Parent $PSScriptRoot

$godot = Get-ChildItem "$env:USERPROFILE\Desktop" -Filter "Godot_v*.exe" -File -ErrorAction SilentlyContinue |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $godot) {
	Write-Error "在桌面找不到 Godot 可执行文件"
	exit 1
}

$out = Join-Path $env:TEMP "mygame_run_out.txt"
$err = Join-Path $env:TEMP "mygame_run_err.txt"

switch ($Mode) {
	"test"    { $argl = @('--headless', '--path', $proj, '--script', 'res://tools/test_game.gd') }
	"shot"    { $argl = @('--path', $proj, '--script', 'res://tools/shot.gd', '--', $Arg) }
	"import"  { $argl = @('--headless', '--editor', '--path', $proj, '--quit') }
	"headless"{ $argl = @('--headless', '--path', $proj, '--quit-after', '120') }
}

Write-Host "Godot : $godot"
Write-Host "Mode  : $Mode  $Arg"

$p = Start-Process -FilePath $godot -ArgumentList $argl -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
$p | Wait-Process -Timeout 120
if (-not $p.HasExited) {
	$p.Kill()
	Write-Host "!! 超时，已终止进程"
} else {
	Write-Host "退出码: $($p.ExitCode)"
}

if ((Get-Item $out).Length -gt 0) {
	Write-Host "---- STDOUT ----"
	Get-Content $out -Encoding UTF8 | Out-String -Width 200 | Write-Host
}
if ((Get-Item $err).Length -gt 0) {
	Write-Host "---- STDERR ----"
	Get-Content $err -Encoding UTF8 | Out-String -Width 200 | Write-Host
}
