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

The `SessionStart` hook also passes the conversation Claude is in (`--id`, from the
`session_id` Claude gives each hook), so a trail follows Claude through `/resume`
and `/clear`, and a restore brings back the conversation you were in.

They are the hooks [the README](../../README.md#hooks-for-each-agent) gives for
`~/.claude/settings.json`; use the plugin or paste those, not both. Each is silent,
never fails a turn, and does nothing outside tmux or when `trails` isn't on the
hook's `PATH`.

trails reads none of Claude's files, so without these hooks a Claude trail's state
is *unknown*.
