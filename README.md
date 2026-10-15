# finops-skills

SEAT FinOps Cortex Code Skills. Layout required by Snowflake: `skills/<name>/SKILL.md`

| Branch | Deploys to | Extra |
|---|---|---|
| `dev`  | `FINOPS_DB.SKILLS_DEV.FINOPS_SEAT` | developers test here |
| `main` | `FINOPS_DB.SKILLS_PRD.FINOPS_SEAT` | certified + email to users (PR + approval only) |

Pipeline: `.github/workflows/deploy-skill.yml` -> `ci/*.sql`
