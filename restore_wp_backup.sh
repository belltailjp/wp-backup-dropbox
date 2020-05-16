#!/bin/bash

# Check shell. If it's sh, it should not run.
# Specifically, yes/no confirmation part requires bash
ps -p $$ | tail -n 1 | grep " sh$" > /dev/null    # c.f. https://stackoverflow.com/questions/3327013
if [ $? -eq 0 ]; then
  echo "Please run with bash instead of sh." 2>&1
  exit
fi

if [ `id -u` -ne 0 ]; then
  echo "This script requires root. Please run with sudo." 2>&1
  exit
fi

if [ $# -ne 2 ]; then
  echo "Usage (1):" 2>&1
  echo "$0 site /path/to/archive" 2>&1
  echo "  site: site-xxx for wordpress instance /var/www/site-xxx " 2>&1
  echo "  /path/to/archive.tar.gz: Archive file uploaded to Dropbox" 2>&1
  echo "" 2>&1
  echo "Usage (2):" 2>&1
  echo "$0 site dropbox_path_to_backup_dir" 2>&1
  echo "  site: site-xxx for wordpress instance /var/www/site-xxx " 2>&1
  echo "  dropbox_path_to_backup_dir: Path to backup directory created in Dropbox by upload_dropbox.py (wp_backup.sh)" 2>&1
  echo "      Example: '/site/backup-20200506-1409'" 2>&1
  exit
fi

SITE=$1
ARCHIVE=$2
WORKDIR=$HOME/workdir

# Check the specified site exists or not
if [ ! -e /var/www/$SITE ]; then
  echo /var/www/$SITE
  echo "The specified site $SITE doesn't exist in /var/www" 2>&1
  exit
fi

# Extract content from archive/dropbox
rm -rf $WORKDIR
mkdir $WORKDIR
if [ -e $ARCHIVE ]; then
  echo "Archive-based restore mode" 2>&1
  # If this is a bz2 archive
  file $ARCHIVE | grep 'gzip' > /dev/null
  if [ $? -eq 0 ]; then
    tar xf $ARCHIVE -C $WORKDIR
  else
    echo "Error: The file $ARCHIVE seems to be not a gz file" 2>&1
    exit
  fi
else
  echo "Dropbox-based restore mode" 2>&1
  BASEDIR=$(dirname "$0")
  python3 $BASEDIR/download_backup.py $ARCHIVE | tar zxf - -C $WORKDIR
  if [ $? -ne 0 ]; then
    echo "Error: Cannot download $ARCHIVE from Dropbox" 2>&1
    echo "Check path or API token" 2>&1
    exit
  fi
fi

# Check directory structure
for I in mysql.sql plugins themes uploads
do
  if [ ! -e $WORKDIR/$I ]; then
    echo "Error: unexpected archive structure" 2>&1
    echo "$WORKDIR" 2>&1
    echo "\`-- (site)" 2>&1
    echo "    \`-- mysql.sql" 2>&1
    echo "    |-- plugins" 2>&1
    echo "    |-- themes" 2>&1
    echo "    \`-- uploads" 2>&1
    echo "($I is not found)"
    exit
  fi
done

# Check if it's reeeeeeeeeally OK
RED='\033[0;31m'
NC='\033[0m'
echo -e "${RED}This will overwrite content, which can never be rolled back.${NC}" 2>&1
echo -e "${RED}Archive: $ARCHIVE${NC}" 2>&1
echo -e "${RED}Site: /var/www/$SITE${NC}" 2>&1
echo -e -n "${RED}Is that OK? [y/n]: ${NC}" 2>&1
read ANSWER
case $ANSWER in
  "Y" | "y" | "yes" | "Yes" | "YES" ) ;;
  * ) echo "Cancelled" 2>&1; exit;;
esac

service nginx stop

# Copy directories to wordpress
WP_CONTENT=/var/www/$SITE/wp-content
for D in plugins themes uploads
do
  rm -rf $WP_CONTENT/$D
  mv $WORKDIR/$D $WP_CONTENT
  chown -R www-data:www-data $WP_CONTENT/$D
  chmod -R 777 $WP_CONTENT/$D
done

# Load database
mysql -u $DATABASE_USER -p"$DATABASE_PASSWORD" wp_${SITE} < $WORKDIR/mysql.sql

# Restart 
service nginx restart

# Cleanup
rm -rf $WORKDIR
