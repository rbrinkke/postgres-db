# Central PostgreSQL Database

**Shared database for Activity App microservices**

## Overview

This repository contains the central PostgreSQL database configuration shared by:
- **auth-api** - Authentication & user management
- **write-api** - Command execution (CQRS write side) - *future use*

## Architecture

```
┌─────────────┐       ┌─────────────┐
│  auth-api   │       │ write-api   │
│  (port 8000)│       │ (port 8007) │
└──────┬──────┘       └──────┬──────┘
       │                     │
       │ auth_api_user       │ write_api_user
       │                     │
       └──────────┬──────────┘
                  │
          ┌───────▼────────┐
          │  postgres-db   │
          │  (port 5441)   │
          │                │
          │ activity schema│
          │  - users       │
          │  - tokens      │
          └────────────────┘
```

## Database Users

| User | Access | Tables |
|------|--------|--------|
| `postgres` | Superuser | All (for migrations) |
| `auth_api_user` | Read/Write | `activity.users`, `activity.refresh_tokens` |
| `write_api_user` | Read/Write | Future tables |

## Quick Start

### 1. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env and update passwords
nano .env
```

### 2. Start Database

```bash
# Make sure networks exist first
docker network create activity-network 2>/dev/null || true
docker network create write-api-network 2>/dev/null || true

# Start postgres-db
docker compose up -d

# Check health
docker compose ps
docker compose logs -f postgres-db
```

### 3. Verify Setup

```bash
# Test superuser connection
docker exec -it activity-postgres-db psql -U postgres -d activitydb

# Test auth_api_user connection
docker exec -it activity-postgres-db psql -U auth_api_user -d activitydb

# List tables
\dt activity.*

# List stored procedures
\df activity.*

# Exit
\q
```

## Connection Strings

### For auth-api (.env)

```env
POSTGRES_HOST=postgres-db
POSTGRES_PORT=5432
POSTGRES_DB=activitydb
POSTGRES_USER=auth_api_user
POSTGRES_PASSWORD=auth_api_secure_password_change_in_prod
POSTGRES_SCHEMA=activity
```

### For write-api (.env) - Future

```env
POSTGRES_HOST=postgres-db
POSTGRES_PORT=5432
POSTGRES_DB=activitydb
POSTGRES_USER=write_api_user
POSTGRES_PASSWORD=write_api_secure_password_change_in_prod
```

## Schema

### Tables

#### activity.users
User authentication and profile data

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| email | VARCHAR(255) | Unique, lowercase |
| hashed_password | VARCHAR(255) | Argon2id hash |
| is_verified | BOOLEAN | Email verification status |
| is_active | BOOLEAN | Account status |
| created_at | TIMESTAMP | Registration date |
| verified_at | TIMESTAMP | Verification date |
| last_login_at | TIMESTAMP | Last login |

#### activity.refresh_tokens
JWT refresh token storage

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| user_id | UUID | FK → users.id |
| token | VARCHAR(500) | Refresh token |
| jti | VARCHAR(50) | JWT ID (unique) |
| expires_at | TIMESTAMP | Expiration |
| created_at | TIMESTAMP | Creation time |
| revoked | BOOLEAN | Revocation status |

### Stored Procedures

Auth API has 11 stored procedures for user management:

1. `sp_create_user` - Create new user
2. `sp_get_user_by_email` - Get user by email
3. `sp_get_user_by_id` - Get user by ID
4. `sp_verify_user_email` - Mark email as verified
5. `sp_update_last_login` - Update last login timestamp
6. `sp_update_password` - Update password
7. `sp_deactivate_user` - Soft delete user
8. `sp_cleanup_unverified_users` - Remove old unverified users
9. `sp_save_refresh_token` - Save refresh token
10. `sp_revoke_refresh_token` - Revoke refresh token
11. `sp_get_valid_refresh_token` - Get valid refresh token

## Port Allocation

- **Host**: 5441
- **Container**: 5432 (standard PostgreSQL)
- **Index**: 8 (systematic allocation for shared services)

## Troubleshooting

### Database not starting

```bash
# Check logs
docker compose logs postgres-db

# Check if port is available
lsof -i :5441

# Check volume
docker volume ls | grep postgres-db
```

### Connection refused

```bash
# Wait for health check
docker compose ps

# Test from host
psql -h localhost -p 5441 -U postgres -d activitydb

# Test from another container
docker exec -it auth-api psql -h postgres-db -U auth_api_user -d activitydb
```

### Permission denied

```bash
# Check user permissions
docker exec -it activity-postgres-db psql -U postgres -d activitydb -c "\du"

# Check table grants
docker exec -it activity-postgres-db psql -U postgres -d activitydb -c "\dp activity.*"
```

## Maintenance

### Backup

```bash
# Backup all data
docker exec activity-postgres-db pg_dump -U postgres activitydb > backup_$(date +%Y%m%d).sql

# Backup schema only
docker exec activity-postgres-db pg_dump -U postgres --schema-only activitydb > schema_$(date +%Y%m%d).sql
```

### Restore

```bash
# Restore from backup
cat backup_20251110.sql | docker exec -i activity-postgres-db psql -U postgres activitydb
```

### Logs

```bash
# View logs
docker compose logs -f postgres-db

# View last 100 lines
docker compose logs --tail=100 postgres-db
```

## Security

- ✅ Separate users for each API
- ✅ Table-level permissions
- ✅ Passwords in .env (not in code)
- ✅ No public schema access
- ✅ Resource limits configured

## Production Considerations

1. **Change all passwords** in .env
2. **Enable SSL** for connections
3. **Configure pg_hba.conf** for IP restrictions
4. **Set up automated backups**
5. **Monitor disk space**
6. **Configure connection pooling** (PgBouncer)
7. **Enable query logging** for audit

## Version

- PostgreSQL: 16-alpine
- Init scripts version: 1.0
- Last updated: 2025-11-10
