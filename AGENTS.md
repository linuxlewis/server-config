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

## Local verification
From repo root:

```bash
cd ansible
ansible-playbook -i inventory.ini server.yml --syntax-check
```

## PR hygiene
- Include a short summary of what changed and why.
- List validation commands that were run.
