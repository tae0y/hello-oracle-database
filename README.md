# Hello Oracle Database

A repository for learning Oracle Database.

## Getting Started

1. Create a `.env` file.

    ```bash
    cp .env.example .env
    # Edit ORACLE_PWD and HOSTNAME in .env
    ```

1. Start containers.

    ```bash
    docker-compose -f docker/docker-compose.yml --env-file .env up -d
    ```

1. Watch logs and wait for initialization to complete (~15 minutes).

    ```bash
    docker logs oracle-xe -f
    # Wait for the "DATABASE IS READY TO USE" message
    ```

    This command initiate two container. `oracle-db` is database, and `uptime-kuma` is optional for service monitoring. 

1. Connect to the database using SQL Developer or a similar tool.

    > If you need, set up Uptime Kuma monitoring manually at `http://localhost:3001` (see [setup-uptime-kuma.md](docs/setup-uptime-kuma.md)).


## Docs

For more detailed information, please refer belo documents.

| Document | Summary |
|----------|---------|
| [setup-oracle-xe-troubleshooting.md](docs/setup-oracle-xe-troubleshooting.md) | Troubleshoot Oracle XE Docker setup and connect with SQL clients |
| [setup-oracle-xe-sample-data.md](docs/setup-oracle-xe-sample-data.md) | Install the HR sample schema and run practice queries |
| [setup-uptime-kuma.md](docs/setup-uptime-kuma.md) | Configure Uptime Kuma monitors and Discord notifications |
| [setup-windows-monitor.md](docs/setup-windows-monitor.md) | Windows host resource monitoring with PowerShell and Discord |

> Practice queries will be in the `sql/` directory. (Coming soon)
