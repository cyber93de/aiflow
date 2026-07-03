# aiflow config schema (self)

`.aiflow/config.json` — the single source of truth `apply.sh` renders from. Written by `init.sh`,
edited by `settings.sh`. **Any new field must be added in all three** (init write, settings write +
jq, apply read).

```jsonc
{
  "caveman":  { "enabled": true, "mode": "full" },      // full|lite|ultra
  "rtk":      { "enabled": true },                       // CLI-output filtering
  "router":   { "enabled": false },                      // claude-code-router; auto-on with ollama
  "graphify": { "enabled": true },                       // structural code graph MCP
  "taskmaster": { "enabled": false },
  "mcp":      { "filesystem": true, "context7": true, "cocoindex": true },  // extra MCP servers
  "memory":   { "enabled": true, "graph": true, "intensity": "aggressive" },// off|light|normal|aggressive
  "claude":   { "auth": "oauth" },                       // apikey|oauth (Claude only; OAuth wins if both env set)
  "vcs":      { "system": "git" },                       // git|svn|none (local VCS)
  "remote": {
    "type": "github",        // github|github-enterprise|gitlab|gitlab-self|bitbucket|forgejo|gitea|custom|none
    "baseUrl": "https://github.com",
    "api": "github-api",     // github-api|gitlab-api|bitbucket|gitea-api|generic
    "tokenEnv": "GITHUB_TOKEN",
    "mcp": "github"          // github|gitlab|bitbucket|forgejo|gitea|none (host MCP to wire)
  },
  "sync":     { "askOnClose": true, "pullOnStart": true },// dolt sync gate + SessionStart auto-pull
  "ollama":   { "enabled": false, "url": "http://localhost:11434", "models": [] },
  "teamPrefs":{ "enabled": true, "codeStyle": "google" },// versioned .aiflow/team-prefs.json
  "project":  { "aim": "…", "architecture": "…" },
  "dev":      { "os": "windows", "ide": "vscode" },
  "git":      { "model": "none",      // simple|gitflow|none (branching; git only)
                "strict": false, "prOnly": false, "autoRelease": false,
                "versionStrategy": "semver", "releaseTags": true, "chore": true },
  "templates_search": false
}
```

## Back-compat
- Legacy `.vcs` as a **string** (old host name) is still read by `apply.sh` as a fallback for
  `.remote.type` — don't remove that fallback.

## Rendering map (which field → what)
- `mcp.*` + `remote.mcp` → `.mcp.json` servers.
- `remote.*` → host MCP env (`GITHUB_HOST`/`GITLAB_API_URL`/`GITEA_URL`) + `bd config` owner/repo.
- `vcs.system` → git init/hooks/branching gate.
- `memory.*` → `.claude/memory/memory-policy.md` (routing + intensity).
- `ollama.*` + `router` → `.aiflow/router-config.json` (Ollama provider + background route).
- `teamPrefs.*` → `.aiflow/team-prefs.json`.
- `sync.askOnClose` → `.aiflow/bd-close-sync.sh`; `sync.pullOnStart` → SessionStart hook behaviour.

See [[architecture]], [[codebase-map]], [[design-decisions]].
