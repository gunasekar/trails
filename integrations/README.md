# Integrations

Trails integrations use the native packaging of the agent they run in.
Install Trails separately; these packages connect it to another application.

- [Agent integrations](agents/README.md) report session status through hooks.
  Claude Code, Codex and Cursor each have their own plugin package and manual
  installation instructions. Cursor here refers to its agent hooks.

Each integration keeps its manifest, documentation and any tests in its own
folder. Agent marketplace catalogs remain at the repository root and point into
`agents/`.

Editors do not need a Trails package. Run `trails` in the editor's terminal, or
use a generic terminal harness such as
[PTYrig](https://marketplace.visualstudio.com/items?itemName=ptyrig.ptyrig) in
VS Code with `"ptyrig.command": "trails"`.
