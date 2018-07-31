# plex-freenas-iocage

Script to create an iocage jail on Freenas 11.1U4 from scratch with plex.

Plex will be placed in a jail with separate data directory (/mnt/v1/apps/...) to allow for easy reinstallation/backup.

Plex will be installed with the default user/group (plex/plex) and the media group will include plex to allow reading of the media files.

Thanks to Pentaflake for his work on installing these apps in an iocage jail.

https://forums.freenas.org/index.php?resources/fn11-1-iocage-jails-plex-tautulli-sonarr-radarr-lidarr-jackett-ombi-transmission-organizr.58/

### Prerequisites
Edit file plex-config

Edit plex-config file with your network information and directory data name you want to use and location of your media files and torrents.

APPS_PATH="apps" will install the data for plex in POOL_PATH/APPS_PATH in this setup /mnt/v1/apps/

PLEX_DATA="plexpass" will create a data directory /mnt/v1/apps/plexpass to store all the data for that app.

MEDIA_LOCATION will set the location of your media files, in this example /mnt/v1/media

TORRENTS_LOCATION will set the location of your torrent files, in this example /mnt/v1/torrents

PLEX_TYPE needs to be set to plexpass or plex depending on which version you want.


```
JAIL_IP="192.168.5.57"
DEFAULT_GW_IP="192.168.5.1"
INTERFACE="igb0"
VNET="off"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
JAIL_NAME="plexapps"
PLEX_DATA="plexdata2"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"
PLEX_TYPE="plexpass"
```
## Install Plex in fresh Jail

Create an iocage jail to install plex.

Then run this command
```
./plexinstallplex.sh
```
## After install

Server/Network/Secure connections is set to Preferred by default

Make sure to add to Server/Network/List of IP addresses and networks that are allowed without auth to your subnet for example 192.168.5.0/24 to allow metadata to be downloaded.

Analyze and Refresh All Metadata for the libraries
