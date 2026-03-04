## MeshScale Agent Guidelines

- **Git commits are human-controlled.**
  - Never run `git commit`, `git push`, or any other mutating git command unless the user explicitly asks for it.
  - When asked to commit, always show a clear summary of changes first.

- **Be transparent about changes.**
  - Prefer editing files via the editor/tools and describe changes briefly in your response.
  - Do not auto-format or mass-refactor the repo without being asked.

- **Respect safety and history.**
  - Never rewrite history (`git push --force`, `git reset --hard`, interactive rebases) unless the user explicitly requests it and understands the impact.
  - Never edit `.git` internals.

- **Ask before automating workflows.**
  - If the user hints at automation (CI, hooks, release scripts), propose a plan and wait for confirmation before wiring in git commands.

