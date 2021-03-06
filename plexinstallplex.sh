#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with Plex
# https://github.com/NasKar2/plex-freenas-iocage

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults

JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
POOL_PATH=""
APPS_PATH=""
JAIL_NAME=""
PLEX_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
USE_BETA=0
USE_BASEJAIL="-b"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/plex-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for plex-config and set configuration
if ! [ -e $SCRIPTPATH/plex-config ]; then
  echo "$SCRIPTPATH/plex-config must exist."
  exit 1
fi

# Check that necessary variables were set by plex-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  echo 'Configuration error: INTERFACE must be set'
  exit 1
fi
if [ -z $POOL_PATH ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi

if [ -z $APPS_PATH ]; then
  echo 'Configuration error: APPS_PATH must be set'
  exit 1
fi

if [ -z $JAIL_NAME ]; then
  echo 'Configuration error: JAIL_NAME must be set'
  exit 1
fi


#if [ -z $PLEX_DATA ]; then
#  echo 'Configuration error: PLEX_DATA must be set'
#  exit 1
#fi

if [ "$USE_BETA" != 0 ] && [ "$USE_BETA" != 1 ]; then
  echo 'Configuration error: USE_BETA must be set to 0 for plex or 1 for plexpass'
  exit 1
fi

if [ -z $MEDIA_LOCATION ]; then
  echo 'Configuration error: MEDIA_LOCATION must be set'
  exit 1
fi

if [ -z $TORRENTS_LOCATION ]; then
  echo 'Configuration error: TORRENTS_LOCATION must be set'
  exit 1
fi

if [ $USE_BETA -eq 1 ]; then
	echo "Using beta-release plexmediaserver code"
	PLEXPKG="plexmediaserver_plexpass"
else
	echo "Using stable-release plexmediaserver code"
	PLEXPKG="plexmediaserver"
fi

#
# Create Jail
echo '{"pkgs":["nano","ca_root_nss"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" ${USE_BASEJAIL}
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

echo ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}
plex_config=${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

iocage exec ${JAIL_NAME} mkdir -p /mnt/media
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} mkdir -p /config
chown -R 972:972 "${plex_config}"
iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${plex_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0

iocage restart ${JAIL_NAME}

#
# Add user media to jail
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"

#
# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf

#
# Upgrade to the lastest repo
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

#
# Install Plex
if [ $PLEX_TYPE == "plexpass" ]; then
   echo "plexpass to be installed"
   iocage exec ${JAIL_NAME} pkg install -y plexmediaserver-plexpass
   iocage exec ${JAIL_NAME} sysrc "plexmediaserver_plexpass_enable=YES"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_support_path="/config"
#   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_pidfile="/config/plex.pid"
   iocage exec ${JAIL_NAME} service plexmediaserver_plexpass start
   iocage exec ${JAIL_NAME} service plexmediaserver_plexpass stop
# Change plex user to media
   iocage exec ${JAIL_NAME} "pw groupmod media -m plex"
   iocage exec ${JAIL_NAME} "pw groupmod plex -m media"
#   iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_plexpass_user=\"plex\"/plexmediaserver_plexpass_user=\"media\"/" /usr/local/etc/rc.d/plexmediaserver_plexpass
#   iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_plexpass_group=\"plex\"/plexmediaserver_plexpass_group=\"media\"/" /usr/local/etc/rc.d//plexmediaserver_plexpass
   iocage exec ${JAIL_NAME} chown -R media:media /config /var/run/plex
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_user="media"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_group="media"
   iocage exec ${JAIL_NAME} service plexmediaserver_plexpass start
else
   echo "plex to be installed"
   iocage exec ${JAIL_NAME} pkg install -y plexmediaserver
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_enable="YES"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_support_path="/config"
#  iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_pidfile="/config/plex.pid"
   iocage exec ${JAIL_NAME} service plexmediaserver start
   iocage exec ${JAIL_NAME} service plexmediaserver stop
# Change plex user to media
   iocage exec ${JAIL_NAME} "pw groupmod media -m plex"
   iocage exec ${JAIL_NAME} "pw groupmod plex -m media"
#   iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_user=\"plex\"/plexmediaserver_user=\"media\"/" /usr/local/etc/rc.d/plexmediaserver
#   iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_group=\"plex\"/plexmediaserver_group=\"media\"/" /usr/local/etc/rc.d//plexmediaserver
   iocage exec ${JAIL_NAME} chown -R media:media /config /var/run/plex
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_user="media"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_group="media"
   iocage exec ${JAIL_NAME} service plexmediaserver start
   iocage exec "${JAIL_NAME}" cp -f /mnt/configs/update_packages /tmp/update_packages
   iocage exec "${JAIL_NAME}" sed -i '' "s/_plexpass//" /tmp/update_packages
fi

#
# update packages & remove /mnt/configs as no longer needed
iocage exec "${JAIL_NAME}" crontab /tmp/update_packages
iocage fstab -r "${JAIL_NAME}" "${CONFIGS_PATH}" /mnt/configs nullfs rw 0 0
iocage exec "${JAIL_NAME}" rm -rf /mnt/configs /tmp/update_packages
iocage restart "${JAIL_NAME}"
echo "${PLEXPKG} installed"
echo
echo "${PLEXPKG} should be available at http://${JAIL_IP}:32400/web/index.html"
