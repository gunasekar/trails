# Integrations

Trails integrations use the native packaging of the agent or editor they run in.
Install Trails separately; these packages connect it to another application.

[Agent integrations](agents/README.md) live under `agents/` and report session
status through hooks. Claude Code, Codex and Cursor each have their own plugin
package and manual installation instructions. Cursor here refers to its agent hooks.

Editor packages belong under `editors/`, separate from the agent hook packages.
Agent marketplace catalogs remain at the repository root and point into `agents/`.
