#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: " 2>&1
  echo "$0 site dest" 2>&1
  echo "  site: site-xxx for wordpress instance /var/www/site-xxx " 2>&1
  echo "  dest: Destination directory in Dropbox. Need to start from '/'. Example: '/site-xxx'" 2>&1
  echo "" 2>&1
  echo "Backup will be uploaded to Dropbox" 2>&1
  exit
fi

SITE=$1
DEST=$2
BASEDIR=$(dirname "$0")
WORKDIR=$HOME/workdir

mysqldump --add-drop-table -u'$DATABASE_USER' -p"$DATABASE_PASSWORD" wp_$SITE > $HOME/mysql.sql
tar zcf - -C $WORKDIR mysql.sql -C /var/www/$SITE/wp-content/ plugins themes uploads | python3 -u $BASEDIR/upload_dropbox.py $DEST
rm -rf $WORKDIR
