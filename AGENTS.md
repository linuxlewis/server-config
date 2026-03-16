# AGENTS.md

Guidelines for agents and contributors working in this repository.

## Project scope
- This is an infrastructure-as-code repository for a reproducible Linux dev server.
- Primary automation lives in `ansible/` and bootstrap/operations scripts in `bootstrap/` and `scripts/`.

## Change expectations
- Keep changes minimal, explicit, and easy to review.
- Prefer idempotent automation (especially in Ansible roles/tasks).
- Update documentation (`README.md`) whenever behavior or setup steps change.

## Ansible conventions
- Keep role responsibilities separated by domain (`base`, `docker`, `dev`, `networking`).
- Use descriptive task names.
- Avoid hard-coding secrets; consume from environment variables or inventory.
- Prefer built-in Ansible modules over raw shell/command when possible.

## CI expectations
- CI should always run Ansible validation checks before merge.
- At minimum, keep `ansible-playbook --syntax-check` passing for `ansible/server.yml`.
- Keep Ansible lint warnings actionable; avoid introducing new lint violations.
- Keep the Molecule scenario passing for the default Debian test harness.

## Local verification
From repo root:

```bash
uv sync --group dev
uv run ansible-galaxy collection install -r ansible/requirements.yml
uv run ansible-playbook -i ansible/inventory.ini ansible/server.yml --syntax-check
uv run ansible-lint --profile=min ansible/server.yml
cd ansible && uv run molecule test --all
```

## Ansible testing
- Prefer `uv run ...` for local Python-based tooling in this repo.
- Use Molecule for Ansible role/playbook regression testing instead of ad hoc shell scripts when feasible.
- Keep Molecule scenarios small, deterministic, and focused on expected host state plus idempotence.
- When changing role behavior, update Molecule verification or add a scenario if the behavior is not already covered.
- Keep assertions meaningful: verify package presence, ownership, group membership, idempotence, and key variable wiring.
- Use the `playbook` scenario when changing `ansible/server.yml` behavior or environment-variable driven defaults.

## PR hygiene
- Include a short summary of what changed and why.
- List validation commands that were run.
