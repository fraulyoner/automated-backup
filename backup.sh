#!/bin/bash

# functions

usage ()
{
cat <<EOF

USAGE:	$0 options
	This script creates a backup for the current state of an application.
	The configuration is stored in the file backup.conf (e.g. the database name, if war file should be saved, folders/files to be saved etc.)
	Current database state is saved in a mysql dump. The user data for the databases must be stored in a mysql config file.

OPTIONS:
	-h Show this help message
 
EOF
}

read_in_conf_and_validate ()
{
# variable is empty	
if [ -z "$CONF_FILE" ]; then
	echo "CONF_FILE not set"
	exit 1
fi	

# no file found for the given variable
if [ ! -f "$CONF_FILE" ]; then
	echo "No configuration file found"
	exit 1
fi

# read in variables of conf file
. "$CONF_FILE"

# assure that conf file contains all required variables
if [ -z "$WEBAPP_PATH" ] || [ -z "$BACKUP_PATH" ] || [ -z "$DB_NAME" ] || [ -z "$MYSQL_CONF" ]; then
	echo "Configuration file seems to be incorrect: required variables missing. Please check your config file: $(readlink -f "$CONF_FILE")"
	exit 1
fi

# assure that WEBAPP_PATH exists
if [ ! -d "$WEBAPP_PATH" ]; then
	echo "The given webapp path does not exist. Please check your config file: $(readlink -f "$CONF_FILE")"
	exit 1
fi

# assure that mysql config file exists
if [ ! -f "$MYSQL_CONF" ]; then
	echo "The given mysql config file does not exist. Please check your config file: $(readlink -f "$CONF_FILE")"
	exit 1
fi
}


create_backup_dir () 
{
# check if backup dir exists, if not create it
if [ ! -d "$BACKUP_PATH" ]; then
	mkdir "$BACKUP_PATH"
	echo "Create parent backup directory $(readlink -f "$BACKUP_PATH")"
fi

# check if there is already a dir for current date, if not create it
if [ ! -d "$FULL_BACKUP_PATH" ]; then
	mkdir "$FULL_BACKUP_PATH"
	echo "Create backup directory $(readlink -f "$FULL_BACKUP_PATH")"
else
	echo "$(readlink -f "$FULL_BACKUP_PATH") already exists"
	echo "Wait until $(readlink -f "$BACKUP_PATH/$(date -d '+1min' +%Y-%m-%d_%H-%M)") can be created"
	exit 1
fi
}

save_app_properties ()
{
# more than one file matching the criterias found
if [ ! $(find "$WEBAPP_PATH" -name "$PROPS_NAME" | wc -l) -eq 1 ]; then
	echo "No or more than one $PROPS_NAME was found under the webapp path $(readlink -f "$WEBAPP_PATH")"
	exit 1
fi	

# copy the information about the current deployed version
cp "$APP_PROPS" "$FULL_BACKUP_PATH"
}

save_war_if_desired () 
{
if [ ! -z "$WAR" ]; then

SAVE_WAR=0

# decide if war should be saved

# if conf = save war only if current deployed version is a snapshot
if [ "$WAR" -eq 0 ]; then

# check if current deployed version is a snapshot
# read in properties 
. "$APP_PROPS"
# $version has information about current deployed version
case "$version" in
        *SNAPSHOT)
                SAVE_WAR=1
                ;;
esac
# if conf = save war always
elif [ "$WAR" -eq 1 ]; then
	SAVE_WAR=1
fi

if [ "$SAVE_WAR" -eq 1 ]; then
	echo "Backup war file: "
	cp -v "$WEBAPP_PATH"/../*.war "$FULL_BACKUP_PATH"
fi

fi
}

dump_dbs () 
{
for db in $DB_NAME
do
	# create dump and hide mysqldump errors due to own error handling
	mysqldump --defaults-file="$MYSQL_CONF" --defaults-group-suffix="$db" "$db" > "$FULL_BACKUP_PATH/$db-$CURRENT_DATE.dump.sql" 2>/dev/null
  # creating dump was successful, so return value is 0
	if [ "$?" -eq 0 ]; then
		echo "Create dump for database $db: $(readlink -f "$FULL_BACKUP_PATH/$db-$CURRENT_DATE.dump.sql")"
	# something went wrong while trying create dump (e.g. access denied), so return value is not 0 but any other number
	else
		echo "Problems encountered while trying to create dump for database $db"
	fi
done
}

save_content ()
{
CONTENT="$1"	
ACTION_NAME="$2"

case "$ACTION_NAME" in
	cp)
		ACTION='cp -r'
		ACTION_MSG="copy"
		;;
	mv)
    ACTION='mv'
		ACTION_MSG="move"
    ;;
esac

for i in $CONTENT
do
	if [ -d "$i" ] || [ -f "$i" ]; then
		echo "Do $ACTION_MSG $(readlink -f "$i") into backup dir"
		$ACTION "$i" "$FULL_BACKUP_PATH"
	else
		echo "Can not $ACTION_MSG $i: does not exist";	
	fi
done
}

# functions end

while getopts "h" OPTION; do
case "$OPTION" in
	h)
	usage
	exit 0
	;;	
esac
done

CONF_FILE="$(dirname "$0")/backup.conf"
read_in_conf_and_validate

CURRENT_DATE="$(date +%Y-%m-%d_%H-%M)"
FULL_BACKUP_PATH="$BACKUP_PATH/$CURRENT_DATE"
PROPS_NAME="pom.properties"
APP_PROPS="$(find "$WEBAPP_PATH" -name "$PROPS_NAME")"

echo "Starting backup using configuration file $(readlink -f "$CONF_FILE")"

create_backup_dir	

save_app_properties

save_war_if_desired

dump_dbs

if [ ! -z "$CONTENT_TO_BE_COPIED" ]; then
save_content "$CONTENT_TO_BE_COPIED" "cp"
fi

if [ ! -z "$CONTENT_TO_BE_MOVED" ]; then
save_content "$CONTENT_TO_BE_MOVED" "mv"
fi

echo "Backup done! You can find it under $(readlink -f "$FULL_BACKUP_PATH")"
