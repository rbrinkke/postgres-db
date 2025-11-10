#!/bin/bash
set -e

# =============================================================================
# Central PostgreSQL Database Initialization
# =============================================================================
# This script initializes the central PostgreSQL database for Activity App
# It creates:
# - activity schema
# - auth_api_user (for auth-api)
# - write_api_user (for write-api, future use)
# =============================================================================

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
    -- =============================================================================
    -- 1. CREATE SCHEMA
    -- =============================================================================

    CREATE SCHEMA IF NOT EXISTS activity;

    -- =============================================================================
    -- 2. CREATE DATABASE USERS
    -- =============================================================================

    -- Auth API User
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'auth_api_user') THEN
            CREATE USER auth_api_user WITH PASSWORD 'auth_api_secure_password_change_in_prod';
        END IF;
    END
    $$;

    -- Write API User (for future use)
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'write_api_user') THEN
            CREATE USER write_api_user WITH PASSWORD 'write_api_secure_password_change_in_prod';
        END IF;
    END
    $$;

    -- =============================================================================
    -- 3. GRANT SCHEMA PERMISSIONS
    -- =============================================================================

    -- Grant schema usage to both users
    GRANT USAGE ON SCHEMA activity TO auth_api_user;
    GRANT USAGE ON SCHEMA activity TO write_api_user;

    -- Grant connect permission
    GRANT CONNECT ON DATABASE activitydb TO auth_api_user;
    GRANT CONNECT ON DATABASE activitydb TO write_api_user;

    -- =============================================================================
    -- 4. SET DEFAULT PRIVILEGES FOR FUTURE OBJECTS
    -- =============================================================================

    -- Auth API User
    ALTER DEFAULT PRIVILEGES IN SCHEMA activity GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO auth_api_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA activity GRANT USAGE, SELECT ON SEQUENCES TO auth_api_user;

    -- Write API User
    ALTER DEFAULT PRIVILEGES IN SCHEMA activity GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO write_api_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA activity GRANT USAGE, SELECT ON SEQUENCES TO write_api_user;

    -- =============================================================================
    -- COMPLETION
    -- =============================================================================

    DO $$
    BEGIN
        RAISE NOTICE '✅ Central database initialized successfully!';
        RAISE NOTICE '   Schema: activity';
        RAISE NOTICE '   Users: auth_api_user, write_api_user';
        RAISE NOTICE '   Ready for table creation!';
    END $$;
EOSQL

echo "✅ Database initialization complete!"
echo "   - Schema 'activity' created"
echo "   - Users 'auth_api_user' and 'write_api_user' created"
echo "   - Permissions configured"
