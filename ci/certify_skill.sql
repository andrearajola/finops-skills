-- PRD only: certify the version just deployed (users without a pinned version get it)
ALTER CORTEX EXTENSION <% ext %> VERSION <% alias %>
  SET TAG snowflake.core.certification_status = 'CERTIFIED';
