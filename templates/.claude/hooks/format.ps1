# PostToolUse hook: auto-format the edited file in Google style if a formatter exists.
# Receives Claude Code tool JSON on stdin. Never blocks; always exits 0.
$ErrorActionPreference = 'SilentlyContinue'

$input_json = [Console]::In.ReadToEnd()
$f = $null
try {
  $obj = $input_json | ConvertFrom-Json
  $f = $obj.tool_input.file_path
} catch {}
if (-not $f) { exit 0 }
if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { exit 0 }

function Have($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

switch -Regex ($f) {
  '\.py$'                              { if (Have black) { & black -q $f }; if (Have isort) { & isort -q $f } }
  '\.(js|jsx|ts|tsx|json|css|md|ya?ml)$' { if (Have prettier) { & prettier --write --log-level error $f } }
  '\.go$'                              { if (Have gofmt) { & gofmt -w $f }; if (Have goimports) { & goimports -w $f } }
  '\.java$'                            { if (Have google-java-format) { & google-java-format -i $f } }
  '\.dart$'                            { if (Have dart) { & dart format $f *> $null } }
  '\.(c|cc|cpp|h|hpp)$'                { if (Have clang-format) { & clang-format -i --style=Google $f } }
  '\.sh$'                              { if (Have shfmt) { & shfmt -w -i 2 $f } }
  '\.ps1$'                             { if (Have Invoke-Formatter) { (Get-Content -Raw $f | Invoke-Formatter) | Set-Content $f } }
}
exit 0
