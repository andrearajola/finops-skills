-- Deploys skills/ from a Git branch as a new version of a Cortex Extension.
-- Called by .github/workflows/deploy-skill.yml with:
--   snow sql -f ci/deploy_skill.sql -D ext=<DB.SCHEMA.EXT> -D branch=<branch> -D alias=<G+sha>
ALTER GIT REPOSITORY FINOPS_DB.SKILLS_CICD.FINOPS_GIT FETCH;

ALTER CORTEX EXTENSION <% ext %> ADD LIVE VERSION <% alias %> FROM LAST;

COPY FILES INTO 'snow://cortex_extension/<% ext %>/versions/live/skills/'
  FROM '@FINOPS_DB.SKILLS_CICD.FINOPS_GIT/branches/<% branch %>/skills/';

ALTER CORTEX EXTENSION <% ext %> COMMIT;
