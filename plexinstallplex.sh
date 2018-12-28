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
INTERFACE=""
VNET="off"
POOL_PATH=""
APPS_PATH=""
JAIL_NAME="plexpass"
PLEX_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
PLEX_TYPE="plexpass"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/plex-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | sed "s/STABLE/RELEASE/g")

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

if [ "$PLEX_TYPE" != "plex" ] && [ "$PLEX_TYPE" != "plexpass" ]; then
  echo '${PLEX_TYPE} Configuration error: PLEX_DATA must be set to plex or plexpass'
  echo ${PLEX_TYPE}
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

#
# Create Jail
echo '{"pkgs":["nano","ca_root_nss"]}' > /tmp/pkg.json
iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r ${RELEASE} ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"

rm /tmp/pkg.json
echo ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}
plex_config=${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${plex_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0

iocage restart ${JAIL_NAME}

#
# Make media the user of the jail and create group media and make media a user of the that group
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"
#iocage exec ${JAIL_NAME} "pw groupadd -n media -g 8675309"
#iocage exec ${JAIL_NAME} "pw groupmod media -m plex"

#
# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf

#
# Upgrade to the lastest repo
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

# Install Plex

if [ $PLEX_TYPE == "plexpass" ]; then
   echo "plexpass to be installed"
   iocage exec ${JAIL_NAME} pkg install -y plexmediaserver-plexpass
   iocage exec ${JAIL_NAME} sysrc "plexmediaserver_plexpass_enable=YES"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_support_path="/config"
#   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_user="plex"
#   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_group="plex"
#   iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_pidfile="/config/plex.pid"
   iocage exec ${JAIL_NAME} chown -R plex:plex /config
   iocage exec ${JAIL_NAME} chmod -R 760 /config
#   iocage exec ${JAIL_NAME} "pw groupmod media -m plex"
   iocage exec ${JAIL_NAME} service plexmediaserver_plexpass start
else
   echo "plex to be installed"
   iocage exec ${JAIL_NAME} pkg install -y plexmediaserver
   iocage exec ${JAIL_NAME} sysrc "plexmediaserver_enable=YES"
   iocage exec ${JAIL_NAME} sysrc plexmediaserver_support_path="/config"
 #  iocage exec ${JAIL_NAME} sysrc plexmediaserver_user="plex"
 #  iocage exec ${JAIL_NAME} sysrc plexmediaserver_group="plex"
 #  iocage exec ${JAIL_NAME} sysrc plexmediaserver_plexpass_pidfile="/config/plex.pid"
   iocage exec ${JAIL_NAME} chown -R plex:plex /config
   iocage exec ${JAIL_NAME} chmod -R 760 /config
#   iocage exec ${JAIL_NAME} "pw groupmod media -m plex"
#   iocage exec ${JAIL_NAME} "pw groupmod plex -m media"
   iocage exec ${JAIL_NAME} service plexmediaserver start
fi

#
# Change plex user to media
#
iocage exec ${JAIL_NAME} "pw groupmod media -m plex"
iocage exec ${JAIL_NAME} "pw groupmod plex -m media"
iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_plexpass_user=\"plex\"/plexmediaserver_plexpass_user=\"media\"/" /git/freenas-iocage-plex/configs/plexmediaserver_plexpass
iocage exec ${JAIL_NAME} sed -i '' "s/plexmediaserver_plexpass_group=\"plex\"/plexmediaserver_plexpass_group=\"media\"/" /git/freenas-iocage-plex/configs/plexmediaserver_plexpass

#
# remove /mnt/configs as no longer needed
iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

echo "${PLEX_TYPE} installed"
echo
echo "${PLEX_TYPE} should be available at http://${JAIL_IP}:32400/web/index.html"
