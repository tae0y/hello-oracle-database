# Set Up Oracle XE in Docker

This page describes how to troubleshoot Oracle XE Docker setup and connect with SQL clients.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose plugin)
- `.env` file configured with `ORACLE_PWD` (see [README](../README.md))

## Troubleshoot Common Issues

### "Password cannot be null" on Windows

This error is misleading. It is caused by bind-mounting a host directory as the Oracle data volume. NTFS permissions are incompatible with the Linux filesystem permissions Oracle expects.

Use Docker named volumes instead of bind mounts. The project's `docker/docker-compose.yml` already does this.

```yaml
# Correct - named volume
volumes:
  - oracle-data:/opt/oracle/oradata

# Wrong - bind mount (fails on Windows)
volumes:
  - ./data/oracle:/opt/oracle/oradata
```

### Password contains `!`

Bash interprets `!` as history expansion inside double-quoted strings. If `ORACLE_PWD` contains `!`, commands like `sqlplus sys/${ORACLE_PWD}@XE` fail silently.

Avoid `!` in the password, or single-quote the variable in shell commands.

### Database initialization takes too long

First-time startup creates the database from scratch and takes approximately 15 minutes. The health check has a 20-minute `start_period` to accommodate this.

1. Watch the logs until the ready message appears.

    ```bash
    docker logs oracle-xe -f
    # Wait for "DATABASE IS READY TO USE"
    ```

1. Verify the health status.

    ```bash
    docker inspect oracle-xe --format='{{.State.Health.Status}}'
    ```

### Nuclear reset

Remove all volumes to start fresh if the database is corrupted.

1. Stop containers and remove volumes.

    ```bash
    docker-compose -f docker/docker-compose.yml --env-file .env down -v
    ```

1. Free build cache (~4 GB).

    ```bash
    docker builder prune
    ```

## Connect with a SQL Client

Connection parameters for SQL Developer, DBeaver, or any JDBC-compatible tool:

| Parameter | Value |
|-----------|-------|
| Hostname | `localhost` |
| Port | `1521` |
| SID | `XE` |
| PDB service name | `XEPDB1` |
| Username | `system` |
| Password | Value of `ORACLE_PWD` in `.env` |

### SQLPlus from the container

1. Connect as SYSDBA.

    ```bash
    # bash/zsh
    docker exec -it oracle-xe sqlplus sys/${ORACLE_PWD}@XE as sysdba
    ```

    ```powershell
    # PowerShell
    docker exec -it oracle-xe sqlplus "sys/$env:ORACLE_PWD@XE as sysdba"
    ```

1. Connect to the pluggable database (XEPDB1).

    ```bash
    # bash/zsh
    docker exec -it oracle-xe sqlplus system/${ORACLE_PWD}@XEPDB1
    ```

    ```powershell
    # PowerShell
    docker exec -it oracle-xe sqlplus "system/$env:ORACLE_PWD@XEPDB1"
    ```
