# Hello Oracle Database

A repository for learning Oracle Database.

## Getting Started

1. Create .env file

    ```bash
    cp .env.example .env
    # Edit ORACLE_PWD and HOSTNAME in .env file
    ```

1. Start containers

    ```bash
    docker-compose up -d
    ```

1. Check logs and wait for initialization to complete (~15 minutes)

    ```bash
    docker logs oracle-xe -f
    # Wait for the "DATABASE IS READY TO USE" message
    ```

1. Connect to the DB using SQL Developer or similar tool.

## Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| oracle-db | oracle-xe | 1521, 5500 | Oracle XE database |
| uptime-kuma | uptime-kuma | 3001 | Service monitoring (ping, port, etc.) |
