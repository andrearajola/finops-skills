-- Deploys skills/ from a Git branch as a new version of a Cortex Extension.
-- Called by .github/workflows/deploy-skill.yml with:
--   snow sql -f ci/deploy_skill.sql -D ext=DB.SCHEMA.NAME -D schema=DB.SCHEMA -D name=NAME -D skill=<folder>
--            -D branch=<branch> -D alias=<G+sha> -D reader=<role> -D discoverable=TRUE|FALSE
ALTER GIT REPOSITORY FINOPS_DB.SKILLS_CICD.FINOPS_GIT FETCH;

-- Day 1: create the extension if it does not exist yet
-- (CREATE needs a root with only skills/, the Git root has ci/ and .github/ -> copy to a stage first)
EXECUTE IMMEDIATE $$
DECLARE
  n INTEGER;
BEGIN
  SHOW CORTEX EXTENSIONS LIKE '<% name %>' IN SCHEMA <% schema %>;
  SELECT COUNT(*) INTO :n FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
  IF (n = 0) THEN
    COPY FILES INTO @FINOPS_DB.SKILLS_CICD.SEED/<% alias %>/skills/<% skill %>/
      FROM @FINOPS_DB.SKILLS_CICD.FINOPS_GIT/branches/<% branch %>/skills/<% skill %>/;
    CREATE CORTEX EXTENSION <% ext %> FROM '@FINOPS_DB.SKILLS_CICD.SEED/<% alias %>/';
    ALTER CORTEX EXTENSION <% ext %> SET DISCOVERABLE = <% discoverable %>;
    GRANT READ ON CORTEX EXTENSION <% ext %> TO ROLE <% reader %>;
    RETURN 'Created <% ext %>';
  END IF;
  RETURN '<% ext %> already exists';
END;
$$;

-- New version from the branch
ALTER CORTEX EXTENSION <% ext %> ADD LIVE VERSION <% alias %> FROM LAST;

COPY FILES INTO 'snow://cortex_extension/<% ext %>/versions/live/skills/<% skill %>/'
  FROM '@FINOPS_DB.SKILLS_CICD.FINOPS_GIT/branches/<% branch %>/skills/<% skill %>/';

ALTER CORTEX EXTENSION <% ext %> COMMIT;
