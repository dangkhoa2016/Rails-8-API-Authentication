\set ON_ERROR_STOP on

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  'rails_8_api_authentication_production_cache',
  current_user
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = 'rails_8_api_authentication_production_cache'
)\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  'rails_8_api_authentication_production_queue',
  current_user
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = 'rails_8_api_authentication_production_queue'
)\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  'rails_8_api_authentication_production_cable',
  current_user
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = 'rails_8_api_authentication_production_cable'
)\gexec
