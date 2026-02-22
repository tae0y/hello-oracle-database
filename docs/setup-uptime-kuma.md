# Set Up Uptime Kuma

This page describes how to configure Uptime Kuma monitors and Discord notifications for Oracle XE after the initial container startup.

## Prerequisites

- All containers running (see Getting Started in [README](../README.md))
- Oracle XE container in healthy state
- A [Discord webhook URL](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) (for notifications)

## Initial Setup

1. Open `http://localhost:3001` and create an admin account.

## Monitors

Add the following monitors to check Oracle XE availability.

| Monitor Type | Friendly Name | Hostname | Port | Heartbeat Interval |
|--------------|---------------|----------|------|-------------------|
| Ping | Oracle XE Ping | `oracle-xe` | — | 60 seconds |
| TCP Port | Oracle XE Port 1521 | `oracle-xe` | `1521` | 60 seconds |

> **Important:** Use the container name `oracle-xe` as the hostname, not `localhost`. Both containers share the same Docker network.

## Discord Notification

1. Navigate to **Settings** > **Notifications** > **Setup Notification** and select **Discord**.

1. Enter the Discord Webhook URL, click **Test**, then **Save**.

1. Assign the notification to each monitor under the monitor's edit page > **Notifications** section.

## Remove

1. Delete the monitors from the Uptime Kuma dashboard.

1. Remove the notification under **Settings** > **Notifications**.
