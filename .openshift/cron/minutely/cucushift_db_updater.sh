#!/bin/sh

#  File name:	cucushift_db_updater.sh
#  Date:	2013/02/25 15:30
#  Author: cryan@redhat.com

# This script is for updating the cucushift validator web application database.

#Unzip the cucushift_dump.sql.tar.gz sent over by bulldozer
cd $OPENSHIFT_TMP_DIR 

FRESH_DUMP="cucushift_dump.sql"

if [ ! -f "${FRESH_DUMP}.bz2" ]; then
  # File is missing in the /tmp/
  exit 0
fi

bunzip2 -f "${FRESH_DUMP}.bz2" || exit 254

mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD ${OPENSHIFT_APP_NAME} -e "CREATE TABLE IF NOT EXISTS step_db_versions(version VARCHAR(128), dbhash VARCHAR(512))";

#Create an md5 sum of the sql file to see if anything has changed since the last time
NEWMD5=$(md5sum $FRESH_DUMP | awk '{print $1}')

#Get the mysql value for hash here
HASH=$(mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD ${OPENSHIFT_APP_NAME} --skip-column-names -e "SELECT dbhash FROM step_db_versions;" |tail -1)

#IMPORTANT! There must be TWO (2) spaces between the hash and the file in the md5sum -c check, i.e. $HASH  $FRESH_DUMP in order for the checksum to work.
RESULT=$(echo "$HASH  ${FRESH_DUMP}" | md5sum -c | awk '{ print $2 }')

#echo "the new md5 is: "$NEWMD5
#echo "the old md5 was: "$HASH

#Compare the result of the hash with the value in the database
if [ "$RESULT" = 'OK' ]; then
	exit 0
	#echo "It's totally cool."
else
	mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD ${OPENSHIFT_APP_NAME} < ${FRESH_DUMP}
	mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD ${OPENSHIFT_APP_NAME} -e "UPDATE step_db_versions set version=UTC_TIMESTAMP();"
	mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD ${OPENSHIFT_APP_NAME} -e "UPDATE step_db_versions set dbhash=\"$NEWMD5\";"
fi
  
rm -f ${FRESH_DUMP}*
exit 0

