#!/usr/bin/env node
// Generates the asciicast (.cast) sources for the terminal GIFs in this folder.
// The sessions are scripted replicas of real aiflow output — update them when the
// CLI output changes, then re-render the GIFs:
//
//   node make-casts.mjs
//   agg --theme dracula --font-size 16 install.cast  install.gif
//   agg --theme dracula --font-size 16 init.cast     init.gif
//   agg --theme dracula --font-size 16 settings.cast settings.gif
//
// agg: https://github.com/asciinema/agg (scoop/brew install agg)

import { writeFileSync } from "node:fs";

const R = "[0m";      // reset
const G = "[32m";     // green
const C = "[36m";     // cyan
const Y = "[33m";     // yellow
const B = "[1m";      // bold
const D = "[2m";      // dim

/** Tiny builder for asciicast v2 files with a typing effect. */
class Cast {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.t = 0;
    this.events = [];
  }
  raw(s) { this.events.push([this.t, "o", s]); return this; }
  pause(sec) { this.t += sec; return this; }
  /** Print one output line instantly (plus newline). */
  out(s = "", d = 0.06) { this.pause(d); this.raw(s + "\r\n"); return this; }
  /** Show a shell prompt, type a command char by char, then "run" it. */
  cmd(s, { pre = 0.6, cps = 0.035, post = 0.35 } = {}) {
    this.pause(pre);
    this.raw(`${G}${B}$${R} `);
    for (const ch of s) { this.pause(cps); this.raw(`${B}${ch}${R}`); }
    this.pause(post);
    this.raw("\r\n");
    return this;
  }
  /** Print an interactive question, type the user's answer, submit. */
  ask(q, answer = "", { pre = 0.25, think = 0.5, cps = 0.06 } = {}) {
    this.pause(pre);
    this.raw(q);
    this.pause(think);
    for (const ch of answer) { this.pause(cps); this.raw(`${Y}${B}${ch}${R}`); }
    this.pause(0.25);
    this.raw("\r\n");
    return this;
  }
  save(file) {
    const header = {
      version: 2, width: this.width, height: this.height,
      timestamp: 0, env: { SHELL: "/bin/bash", TERM: "xterm-256color" },
      title: file.replace(/\.cast$/, ""),
    };
    const lines = [JSON.stringify(header), ...this.events.map((e) => JSON.stringify(e))];
    writeFileSync(new URL(file, import.meta.url), lines.join("\n") + "\n");
    console.log(`wrote ${file} (${this.events.length} events, ${this.t.toFixed(1)}s)`);
  }
}

/* ------------------------------------------------------------------ */
/* 1. install.gif — clone, install, doctor                             */
/* ------------------------------------------------------------------ */
{
  const c = new Cast(88, 26);
  c.cmd("git clone https://github.com/Cyber93de/aiflow.git");
  c.out(`Cloning into 'aiflow'...`);
  c.out(`remote: Enumerating objects: 324, done.`, 0.4);
  c.out(`Receiving objects: 100% (324/324), 512.4 KiB | 2.4 MiB/s, done.`, 0.5);
  c.cmd("cd aiflow && bash install.sh");
  c.out(`linked ${C}~/.local/bin/aiflow${R} -> ~/aiflow/bin/aiflow`, 0.3);
  c.out(``);
  c.out(`Optional prerequisites (so 'aiflow init' later only asks which Ollama models to pull):`);
  c.out(`  git already present`);
  c.ask(`  Install Subversion (svn)? (y/n) [n]: `);
  c.ask(`  Install Ollama (local models)? (y/n) [n]: `, "y");
  c.out(`  ${D}installing ollama ... done${R}`, 0.8);
  c.out(``);
  c.out(`next:`);
  c.out(`  ${C}aiflow doctor${R}              # see what's present`);
  c.out(`  ${C}aiflow install-deps --all${R}  # install the rest of the toolchain`);
  c.out(`  ${C}aiflow init${R}                # bootstrap a project`);
  c.cmd("aiflow doctor", { pre: 1.2 });
  c.out(`aiflow doctor`);
  c.out(`core:`);
  c.out(`  ${G}[ok]${R}   claude     2.1.7 (Claude Code)`, 0.12);
  c.out(`  ${G}[ok]${R}   git        git version 2.49.0`, 0.1);
  c.out(`  ${G}[ok]${R}   node       v22.16.0`, 0.1);
  c.out(`  ${G}[ok]${R}   jq         jq-1.7.1`, 0.1);
  c.out(`  ${G}[ok]${R}   bd         bd version 0.49.2`, 0.1);
  c.out(`  ${G}[ok]${R}   dolt       dolt version 1.62.1`, 0.1);
  c.out(`  ${G}[ok]${R}   podman     podman version 5.5.0`, 0.1);
  c.out(``);
  c.out(`task / memory / vcs:`);
  c.out(`  ${G}[ok]${R}   graphify   graphify 0.9.2`, 0.1);
  c.out(`  ${G}[ok]${R}   ccc        cocoindex-code 0.4.1`, 0.1);
  c.out(`  ${G}[ok]${R}   gh         gh version 2.76.0`, 0.1);
  c.out(`  ${G}[ok]${R}   ollama     ollama version 0.9.6`, 0.1);
  c.pause(3);
  c.save("install.cast");
}

/* ------------------------------------------------------------------ */
/* 2. init.gif — the full interactive Q&A                              */
/* ------------------------------------------------------------------ */
{
  const c = new Cast(88, 26);
  c.cmd("mkdir my-app && cd my-app");
  c.cmd("aiflow init");
  c.out(`${C}>> aiflow init -> /home/dev/my-app  (new project)${R}`, 0.3);
  c.out(``);
  c.out(`Configure this project (Enter = default):`);
  c.out(`  Token-saving defaults (caveman + rtk) and intensive graph-memory learning are ON.`);
  c.ask(`  Save tokens with caveman (terse output)? (y/n) [y]: `);
  c.ask(`  caveman mode (full recommended / lite / ultra) [full]: `);
  c.ask(`  Save tokens by filtering CLI output with rtk? (y/n) [y]: `);
  c.ask(`  Use graphify (structural code graph: imports/call-graph) for memory? (y/n) [y]: `);
  c.ask(`  Use cocoindex-code (semantic code RAG search, local)? (y/n) [y]: `);
  c.ask(`  Use claude-task-master for task decomposition? (y/n) [y]: `);
  c.ask(`  Enable filesystem MCP? (y/n) [y]: `);
  c.ask(`  Enable context7 MCP (live library docs)? (y/n) [y]: `);
  c.out(``);
  c.out(`Claude memory (intensive graph-memory learning is recommended):`);
  c.ask(`  Enable persistent Claude memory? (y/n) [y]: `);
  c.ask(`  Learn the codebase into a knowledge graph (graph memory)? (y/n) [y]: `);
  c.ask(`  Memory learning intensity (aggressive / normal / light) [aggressive]: `);
  c.out(``);
  c.out(`Claude access (token-based; pick how you authenticate):`);
  c.ask(`  Claude auth (apikey = ANTHROPIC_API_KEY / oauth = claude setup-token) [apikey]: `, "oauth");
  c.out(``);
  c.out(`Version control:`);
  c.ask(`  Local version control (git / svn / none) [git]: `);
  c.out(``);
  c.out(`Remote host (API tokens only — no OAuth):`);
  c.out(`  github | github-enterprise | gitlab | gitlab-self | bitbucket | forgejo | gitea | ...`);
  c.ask(`  Remote type [github]: `);
  c.ask(`  Git-host MCP to wire (github/gitlab/bitbucket/forgejo/gitea/none) [github]: `);
  c.ask(`  Ask to push + dolt-sync the remote each time a Beads issue is closed? (y/n) [y]: `);
  c.out(``);
  c.out(`Ollama (local models — no API key needed):`);
  c.ask(`  Set up Ollama for local models? (y/n) [n]: `, "y");
  c.out(`  Suggested: qwen3-coder (recommended, newest Qwen), qwen3, llama3.1, deepseek-r1`);
  c.ask(`  Models to install (comma-separated) [qwen3-coder]: `, "qwen3-coder,llama3.1");
  c.ask(`  Ollama URL [http://localhost:11434]: `);
  c.ask(`  Use claude-code-router (route easy tasks to cheap/local models)? (y/n) [y]: `);
  c.out(``);
  c.ask(`  Project aim (what should it achieve?) []: `, "REST API for order management");
  c.ask(`  Target architecture (e.g. hexagonal, MVC, layered...) []: `, "hexagonal");
  c.ask(`  Your OS (windows / macos / linux) [linux]: `);
  c.ask(`  Your IDE (vscode / intellij / other) [vscode]: `);
  c.out(``);
  c.out(`Git branching model:`);
  c.ask(`  Branching model (simple / gitflow / none) [simple]: `, "gitflow");
  c.ask(`  Enable strict branch rules? (y/n) [y]: `);
  c.ask(`  Merges only via Pull Requests (no direct push to main/develop)? (y/n) [y]: `);
  c.ask(`  Auto-create a release when develop merges into main? (y/n) [n]: `);
  c.ask(`  Allow chore/* branches? (y/n) [y]: `);
  c.out(`  ${G}wrote .aiflow/config.json${R}`, 0.3);
  c.out(`  ${G}.env created (fill in tokens!)${R}`, 0.15);
  c.out(`  ${G}git initialised${R}`, 0.15);
  c.out(`  .mcp.json rendered (host-mcp=github filesystem=true context7=true graphify=true`, 0.15);
  c.out(`    cocoindex=true task-master=true)`);
  c.out(`  branching: gitflow (strict=true prOnly=true) -> .aiflow/branching.json`, 0.12);
  c.out(`  git hooks enforced (core.hooksPath=.githooks)`, 0.12);
  c.out(`  memory written (aim + dev environment + policy: intensity=aggressive graph=true)`, 0.12);
  c.out(`${G}apply done.${R}`, 0.2);
  c.out(``);
  c.out(`Done.`);
  c.out(`This is a NEW project. Next steps:`);
  c.out(`  1) edit ${C}.env${R}        -> GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)`);
  c.out(`  2) review ${C}CLAUDE.md${R} + .claude/memory/project-aim.md (fill the [EDIT ME] blocks)`);
  c.out(`  3) ${C}aiflow shell${R}     -> start Claude Code (secrets loaded)`);
  c.pause(3.5);
  c.save("init.cast");
}

/* ------------------------------------------------------------------ */
/* 3. settings.gif — change settings later (vcs, ollama, token-saving) */
/* ------------------------------------------------------------------ */
{
  const c = new Cast(88, 26);
  c.cmd("aiflow change-settings");
  c.out(`Change settings (Enter keeps current):`);
  c.ask(`  caveman (terse output)? (y/n) [y]: `);
  c.ask(`  caveman mode (full/lite/ultra) [full]: `, "lite");
  c.ask(`  rtk CLI-output filtering? (y/n) [y]: `);
  c.ask(`  graphify structural code graph? (y/n) [y]: `);
  c.out(`  ${D}...${R}`, 0.3);
  c.ask(`  Local version control (git/svn/none) [git]: `, "svn");
  c.out(`  ${D}...${R}`, 0.3);
  c.ask(`  set up Ollama (local models)? (y/n) [y]: `);
  c.ask(`  Ollama models (comma-separated; qwen3-coder recommended) [qwen3-coder]: `, "qwen3-coder,deepseek-r1");
  c.ask(`  Ollama URL [http://localhost:11434]: `);
  c.out(`  ${D}...${R}`, 0.3);
  c.out(`  ${G}updated .aiflow/config.json${R}`, 0.4);
  c.out(`${G}apply done.${R}`, 0.2);
  c.out(``);
  c.cmd("aiflow change-settings --no-token-saving", { pre: 1.4 });
  c.out(`Change settings (Enter keeps current):`);
  c.out(`  ${Y}--no-token-saving: caveman + rtk switched OFF (full, unfiltered output).${R}`, 0.4);
  c.ask(`  graphify structural code graph? (y/n) [y]: `);
  c.out(`  ${D}...${R}`, 0.3);
  c.out(`  ${G}updated .aiflow/config.json${R}`, 0.4);
  c.out(`${G}apply done.${R}`, 0.2);
  c.pause(3);
  c.save("settings.cast");
}
