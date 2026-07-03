---
description: Pull an issue from GitHub, GitLab, or Bitbucket and turn it into Beads tasks with acceptance criteria.
argument-hint: <issue-number or URL>
---

Intake issue **$ARGUMENTS** into the Beads backlog. The VCS host is in `.aiflow/config.json` (`vcs`).

1. Fetch the issue (title, body, labels, comments):
   - **github** → use the GitHub MCP server.
   - **gitlab** → `glab issue view $ARGUMENTS` (GitLab CLI; token `GITLAB_TOKEN`).
   - **bitbucket** → `curl` the Bitbucket REST API with `BITBUCKET_TOKEN` (or `gh`-style helper).
2. Restate the goal; extract/derive explicit **acceptance criteria**. If vague, post the open
   questions back on the issue before planning.
3. Use the **planner** agent (optionally **claude-task-master**, see `/decompose`) to break it
   into small Beads tasks with dependencies (`bd`).
4. Note the source issue on each bead. Post one summary comment back on the issue with the bead ids.
5. Show `/beads:ready`.

Planning only — no feature code here.
