# rancher-backup

This repository contains a very simple container which backs up volumes attached to parent containers.

# Usage

## Configure the service in the `docker-compose.yml` file:

1. Add this container as a sidekick to the target service.
2. Set the environment variable `BACKUP_HOME` for the top-level backups directory.
3. Set the cron entry.

Example:

```
spigot:
	labels:
		io.rancher.sidekicks: backup
	image: username/spigot
	volumes:
		- mcdata:/minecraft
backup:
	labels:
		io.rancher.container.start_once: 'true'
		com.socialengine.rancher-cron.schedule: '@every 6h'
	image: username/rancher-backup
	environment:
		- BACKUP_HOME=/backup
	volumes_from:
		- spigot
	volumes:
		- /backup:/backup
```

Important notes:
* The backup container must be a sidekick.
* `BACKUP_HOME` must be set to the top-level directory of the backups. (TODO: named volume instead?)
* cron is nice but not necessary.
* All services being backed up must be mounted by the backup container.

## Configure the following metadata in the `rancher-compose.yml` file:

Example:

```
spigot:
    scale: 1
	metadata:
        world:
            include:
                - 'minecraft/world'
                - 'minecraft/world_nether'
                - 'minecraft/world_the_end
            keep: 5
        plugins:
            include:
                - 'minecraft/plugins'
            exclude:
                - 'minecraft/plugins/dynmap/web'
backup:
    scale: 1
```

Notes:
* The metadata must be in the primary service, even when backing up volumes from other services!
* The `include` key is required and must be a pathname.
* The `exclude` key is optional and defaults to ''.
* The `keep` key is also optional, and has a default value of 1.
* Leading slashes on pathnames cause warnings and can also make excludes not work.

# Explanation

Every time the container runs, it will do the following:
1. Check its configuration for consistency.
2. Create directories if necessary.

Backups are stored in a directory structure under the `BACKUP_HOME` directory,  by the stack name.  Backups for the `minecraft` stack with a `BACKUP_HOME` value of `/backups` will be found in `/backups/minecraft`.

For each backup found under the metadata:
1. A new tar-based backup is created, including the desired directories but not the undesired directories.
2. The oldest backup is retired if the keep limit has been reached.

For the above example, the file containing the plugins backups would be named `plugins.1.tar.gz`, while there would be multiple files for the world backups.
