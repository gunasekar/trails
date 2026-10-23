# trails for Claude Code

A [Claude Code plugin](https://code.claude.com/docs/en/plugins) holding the hooks
that tell [trails](https://github.com/gunasekar/trails) what each Claude session is
doing, so you don't have to paste them into `~/.claude/settings.json`:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

Each hook runs `trails state working | waiting | idle`:

| When | Says |
|---|---|
| a session starts, a turn ends (`SessionStart`, `Stop`) | idle: your turn |
| a prompt is sent, a tool has run (`UserPromptSubmit`, `PostToolUse`) | working |
| a permission prompt, a question (`Notification` `permission_prompt`, `PreToolUse` `AskUserQuestion`) | waiting: needs you |

They are the hooks `trails hooks claude` prints for `~/.claude/settings.json`; use
the plugin or paste those, not both. Each is silent, never fails a turn, and does nothing outside tmux or
when `trails` isn't on the hook's `PATH`.

Claude also keeps its own state in a file trails reads, so trails knows Claude's
state without these hooks. With them, the hook's word and the file's are weighed,
the newer winning.
