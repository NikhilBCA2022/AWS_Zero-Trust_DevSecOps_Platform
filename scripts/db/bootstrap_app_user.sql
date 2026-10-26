\set ON_ERROR_STOP on

-- Required psql variables:
--   database_name
--   app_password
--
-- Connect to the target database as the RDS administrator.
-- Supply app_password securely at execution time; never commit it.

SELECT format(
    'CREATE ROLE cloud_ops_app LOGIN PASSWORD %L',
    :'app_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'cloud_ops_app'
)
\gexec

GRANT CONNECT ON DATABASE :"database_name" TO cloud_ops_app;
GRANT USAGE ON SCHEMA public TO cloud_ops_app;

-- Grant only the table permissions required by the application.
-- Add specific tables after the application's migration schema is finalized.
