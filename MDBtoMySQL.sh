#!/usr/bin/env bash
#
# Usage 1: Interactive
#
#   bash MDBtoMySQL.sh
#   
#   mysql host used is localhost
#
# Usage 2: Non-interactive
#
#   bash MDBtoMySQL.sh -m db.mdb -d movies -u user -p pass 
#
#   -m  path to mdb file
#   -d  mysql database into which to import
#   -u  mysql --username parameter
#   -p  mysql --password parameter
#   -h  mysql --host parameter
#   -g  table name that requires "grep `date +%Y-%m-%d`" to save on time

# Stuff for testing.
# db_to_read='db.mdb';
# db_to_create='movies';
# user='root';
# password='root';

# Table 2-1. MDB Utilities
# Name	Description
# mdb-tables	list tables in the specified file
# mdb-schema	generate schema DDL for the specified file
# mdb-export	generate CSV style output for a table

#set -e

echo "-- -----------------------------------------------------------------------";
echo "-- MDBtoSQL";
echo "-- A library for easy data migration from MS Access to a MySQL database";
echo "-- Copyright (C) 2016- Vagelis Prokopiou.";
echo "-- Licensed under the MIT licence.";
echo "-- For more info, check out https://github.com/Vaggos/MDBtoMySQL";
echo "-- ";
echo "-- Usage info:";
echo "-- This script presupposes that \"mdbtools\" are installed in your system.";
echo "-- If not, install them with \"sudo apt-get install mdbtools\" in a Debian";
echo "-- or Debian-based system.";
echo "-- -----------------------------------------------------------------------";

# Check if mdbtools are installed.
command -v mdb-tables >/dev/null 2>&1 || { echo >&2 "I require mdb-tools but they are not installed. Aborting."; exit 1; }
command -v mysql >/dev/null 2>&1 || { echo >&2 "I require MySQL but it is not installed. Aborting."; exit 1; }

if [ $# -eq 1 ]; then
# Get all the info you need.
# sleep 1;
  echo "";
  echo "Please, provide the name of the MySQL user.";
  read user;

  echo "";
  echo "Please, provide the password of the MySQL user.";
  read password;

  echo "";
  echo "Please, provide the name of the mdb file.";
  echo "Make sure to provide the full path,
  if the file is not in the current directory.";
  read db_to_read;

  echo "";
  echo "Please, provide the name of the database that will be created.";
  echo "Do not use spaces or any special characters:";
  read db_to_create;

  # Create the database.
  echo "";
  echo "!!! Attention !!!";
  echo "If there already is a database with the same name, it is about to be deleted!!!";
  echo "Press \"Y\" to confirm and continue.";
  echo "Press \"N\" to abort the operation.";
  read proceed;

  # host parameter to mysql
  host="localhost"
  dropCreateDb=1
  grepTable=""
else
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # http://stackoverflow.com/a/14203146/4126114
    # http://mywiki.wooledge.org/BashFAQ/035#getopts
    while getopts "m:d:u:p:h:g:" opt; do
        case "$opt" in
            m)  db_to_read=$OPTARG
                ;;
            d)  db_to_create=$OPTARG
                ;;
            u)  user=$OPTARG
                ;;
            p)  password=$OPTARG
                ;;
            h)  host=$OPTARG
                ;;
            g)  grepTable=$OPTARG
                ;;
        esac
    done
    shift "$((OPTIND-1))" # Shift off the options and optional --.
    [ "$1" = "--" ] && shift

    printf \
      "Params:\n  mdb: %s\n  db: %s\n  user: %s\n  pass: %s\n  host: %s\n" \
      "${db_to_read}" "${db_to_create}" "$user" "$password" "$host" >&2

    proceed=Y
    dropCreateDb=0
fi

# Check if the file exists.
if [[ ! -f "$db_to_read" ]]; then
	echo "The file was not found.";
	echo "Check the name and the path and try again.";
	echo "Aborting.";
	exit 1;
fi

# Check the permissions/owner.
if [[ ! -O "$db_to_read" ]]; then
	echo "You are not the owner of this file. Aborting the operation.";
	echo "";
	exit 1;
fi

# Check the name provided.
if [[ "$db_to_read" =~ [\],!,\\,@,#,$,%,^,\&,\*,\(,\),\?,\<,\>,{,},\[]+ ]] || [[ "$db_to_read" =~ [[:space:]]+ ]]; then
	echo "It is preferable to not include any special characters or spaces in the name.";
	echo "Please, rename the file and try again.";
	echo "Aborting.";
	exit 1;
fi

# Check the name provided.
if [[ "$db_to_create" =~ [\],!,\\,@,#,$,%,^,\&,\*,\(,\),\?,\<,\>,{,},\[]+ ]] || [[ "$db_to_create" =~ [[:space:]]+ ]]; then
	echo "No special characters or spaces are allowed in the database name.";
	echo "Aborting.";
	exit 1;
fi

if [[ $proceed == "y" ]] || [[ $proceed == "Y" ]]; then
    echo "Continuing";
elif [[ $proceed == "n" ]] || [[ $proceed == "N" ]]; then
    echo "Aborthing";
    exit 1;
else
	echo "The expected input was invalid";
	echo "Aborting";
	exit 1;
fi

# mysql cmd
mysqlCmd="mysql --host=$host --user=$user --password=$password $db_to_create"
printf "Connecting using cmd: %s\n" "$mysqlCmd"

# Get the tables to start exporting the data.
IFS=' ' read -ra tables <<< "$(mdb-tables "$db_to_read")"

# drop and create
if [ $dropCreateDb -eq 1 ]; then
  # Create the database.
  $mysqlCmd -e "DROP DATABASE IF EXISTS $db_to_create";
  $mysqlCmd -e "CREATE DATABASE $db_to_create DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;";
  echo "";
  echo "<------------------------------------------------------------------------>"
  echo "           Database \"$db_to_create\" was successfully created."
  echo "<------------------------------------------------------------------------>"
fi

# Create the query that will create the tables.
mdb-schema $db_to_read mysql > .schema.txt.new

# just alert if schema changed
if [ -f ".schema.txt" ]; then
  diff .schema.txt .schema.txt.new 2>&1 > /dev/null
  if [ $? -ne 0 ]; then
    echo "schema changed!!!"
  fi
fi
mv .schema.txt.new .schema.txt

# drop tables
for table in "${tables[@]}"; do
  $mysqlCmd -e "DROP table if exists $db_to_create.$table";
done

# create tables
cat .schema.txt | $mysqlCmd
echo "";
echo "<------------------------------------------------------------------------>"
echo "           The tables of the \"$db_to_create\" database were successfully created."
echo "<------------------------------------------------------------------------>"

# Get the tables to start exporting the data.
for table in "${tables[@]}"; do

  # get mdb-export version
  mdbexv=`man mdb-export|tail -n 1|awk '{print $1}'`
  if [ $mdbexv == "MDBTools" ]; then
    mdbexv=`man mdb-export|tail -n 1|awk '{print $2}'`;
  fi

	# Create a insert file
  if [ $mdbexv == "0.7.1" ]; then
		mdb-export -D "%Y-%m-%d %H:%M:%S" -I mysql -R ";\r\n" $db_to_read $table > "$table".sql
    if [ "$table" == "$grepTable" ]; then
      grep "`date +%Y-%m-%d`" "$table".sql > temp.sql
      mv temp.sql "$table".sql
    fi
    cat "$table".sql | $mysqlCmd
  else
    echo "mdb-export version $mdbexv unsupported yet"
    exit
  fi

	# Execute mysql queries.
	$mysqlCmd -e "TRUNCATE table $db_to_create.$table";
	cat "$table".sql | $mysqlCmd

	# Remove the temp files.
	rm "$table".sql; 
done
