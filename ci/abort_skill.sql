-- Runs if the deploy fails: discard the open live version
ALTER CORTEX EXTENSION <% ext %> ABORT;
