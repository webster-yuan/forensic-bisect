# forensic-bisect install script (Windows PowerShell)
# Copies forensic-bisect skill to ~/.claude/skills/forensic-bisect/ and ~/.hermes/skills/forensic-bisect/
param(
    [switch]$Force
)

$ClaudeSkillDir = "$env:USERPROFILE\.claude\skills\forensic-bisect"
$HermesSkillDir = "$env:USERPROFILE\AppData\Local\hermes\skills\forensic-bisect"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== forensic-bisect installer ==="

# Install to Claude Code
try {
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) {
        if (Test-Path $ClaudeSkillDir) {
            if ($Force) {
                Remove-Item -Recurse -Force $ClaudeSkillDir
                Write-Host "Claude Code: removed existing."
            } else {
                Write-Host "Claude Code: already installed (use -Force to reinstall)"
            }
        }
        if (-not (Test-Path $ClaudeSkillDir)) {
            New-Item -ItemType Directory -Force -Path $ClaudeSkillDir | Out-Null
            Copy-Item "$ScriptDir\SKILL.md" "$ClaudeSkillDir\"
            Write-Host "Claude Code: installed to $ClaudeSkillDir"
        }
    }
} catch {
    Write-Host "Claude Code: not found (skipping)"
}

# Install to Hermes
try {
    $hermes = Get-Command hermes -ErrorAction SilentlyContinue
    if ($hermes) {
        if (Test-Path $HermesSkillDir) {
            if ($Force) {
                Remove-Item -Recurse -Force $HermesSkillDir
                Write-Host "Hermes: removed existing."
            } else {
                Write-Host "Hermes: already installed (use -Force to reinstall)"
            }
        }
        if (-not (Test-Path $HermesSkillDir)) {
            New-Item -ItemType Directory -Force -Path $HermesSkillDir | Out-Null
            Copy-Item "$ScriptDir\SKILL.md" "$HermesSkillDir\"
            Write-Host "Hermes: installed to $HermesSkillDir"
        }
    }
} catch {
    Write-Host "Hermes: not found (skipping)"
}

Write-Host ""
Write-Host "Done! Restart Claude Code or Hermes to pick up the skill."
Write-Host "To verify: ask your agent '排查这个问题' and it should load forensic-bisect."
