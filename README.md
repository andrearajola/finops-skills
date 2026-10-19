# finops-skills

SEAT FinOps Cortex Code Skills. Layout required by Snowflake: `skills/<name>/SKILL.md` (one folder per skill).

| Branch | Deploys to | Extra |
|---|---|---|
| `dev`  | `FINOPS_DB.SKILLS_DEV.<NAME>` | developers test here, description prefixed with [DEV] |
| `main` | `FINOPS_DB.SKILLS_PRD.<NAME>` | certified + email to users (PR + approval only) |

Pipeline: `.github/workflows/sync-skills.yml` validates (`ci/validate_skills.sh`) and calls
`FINOPS_DB.SKILLS_CICD.SP_SKILL_SYNC_ALL()` in Snowflake, which publishes only the skills whose files changed.

Optional `skills/<name>/cicd.yml`: `dev_reader`, `prd_reader`, `prd_enabled` (true/false).
