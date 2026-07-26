# Contributing

## Base branch

- `dev`: target for all feature and fix PRs.
- `main`: release-only. Only `dev → main` promotion PRs land here.

Fork off `dev` and open PRs against `dev`. PRs opened against `main` will be asked to re-target or closed.

## PR checklist

- [ ] Branch off `dev`, target `dev`
- [ ] Scope is one thing. No unrelated refactors.
- [ ] `install.sh --dry-run` clean if any hook/skill wiring changed
- [ ] Commit message explains *why*, not just what
- [ ] No AI-attribution trailers in commits or PR body

## Style

- Terse. No emoji, no sales copy.
- Skill / agent frontmatter matches existing files.
- Hook shell scripts stay POSIX-`sh` compatible where practical.

## License

By contributing you agree your work is licensed under this project's MIT license.
