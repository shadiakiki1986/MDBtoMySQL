#!/usr/bin/env bash
#
# Usage: Check README.md in repository

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

set -e

echo "-- -----------------------------------------------------------------------";
echo "-- MDBtoSQL";
echo "-- A library for easy data migration from MS Access to a MySQL database";
echo "-- Copyright (C) 2016- Vagelis Prokopiou.";
echo "-- Licensed under the MIT licence.";
echo "-- For more info, check out https://github.com/Vaggos/MDBtoMySQL";
echo "-- ";
echo "-- Usage info:";
echo "-- This script presupposes that \"mdbtools\" and a \"mysql\" client are installed in your system.";
echo "-- If not, install them with \"sudo apt-get install mdbtools mysql-client\" in a Debian";
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

    # create empty array
    # Example 27-6. Some special properties of arrays
    # http://www.tldp.org/LDP/abs/html/arrays.html
    declare -a tablesToImport

    # http://stackoverflow.com/a/14203146/4126114
    # http://mywiki.wooledge.org/BashFAQ/035#getopts
    while getopts "m:d:u:p:h:g:t:" opt; do
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
            t)  # http://stackoverflow.com/a/918931/4126114
                IFS=',' read -ra tablesToImport <<< "$OPTARG"
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
# setting password in env var to avoid warning about insecurity of using a password on the command-line
# quote: mysql: [Warning] Using a password on the command line interface can be insecure.
# http://serverfault.com/a/476286
export MYSQL_PWD="$password"
mysqlCmd="mysql --host=$host --user=$user $db_to_create" #  --password=$password
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
mdb-schema "$db_to_read" mysql > .schema.txt.new

# alert if schema changed
# doesnt work with set -e on top
#if [ -f ".schema.txt" ]; then
#  diff .schema.txt .schema.txt.new 2>&1 > /dev/null
#  if [ $? -ne 0 ]; then
#    echo "schema changed!!!"
#  fi
#fi

mv .schema.txt.new .schema.txt

# drop tables, but only those in tablesToImport
for table in "${tables[@]}"; do
  $mysqlCmd -e "DROP table if exists $db_to_create.$table";
  # echo "Dropped table $db_to_create.$table"
done

echo "";
echo "<------------------------------------------------------------------------>"
echo "           Dropped tables if existant"
echo "<------------------------------------------------------------------------>"

# if tablesToImport is not empty, filter tables for those that are there
# http://unix.stackexchange.com/a/104848
if [ ${#tablesToImport[@]} -gt 0 ]; then

  # 2016-12-01 TODO: doesnt seem to work in dockerfile
  # Note on sort below: need to sort by ignoring case (-i) and dictionary order (-d, i.e. ignore underscores)
  #echo "Filtering tables for those requested"
  #tables=($(comm -12 <(printf '%s\n' "${tablesToImport[@]}"|LC_ALL=C sort -f -d) <(printf '%s\n' "${tables[@]}"|LC_ALL=C sort -f -d)))
  #echo "Tables filtered down to"
  #echo ${tables[@]}          # echo ${colors[*]} also works.

  tables=($(printf '%s\n' "${tablesToImport[@]}"))
fi

# get mdb-export version
mdbexv=`man mdb-export|tail -n 1|awk '{print $1}'`
if [ $mdbexv == "MDBTools" ]; then
  mdbexv=`man mdb-export|tail -n 1|awk '{print $2}'`;
fi

# version 0.7.1 latest commit 2013
# https://github.com/brianb/mdbtools/tree/0.7.1
# version 0.7~rc1 latest commit 2011
# https://github.com/brianb/mdbtools/tree/0.7_rc1
if [ $mdbexv != "0.7.1" ] && [ $mdbexv != "0.7~rc1" ]; then
  echo "mdb-export version $mdbexv unsupported yet"
  exit 1
fi

# create tables
# Note on COMMENT ON COLUMN below: these extra lines were showing up in the schema when running on travis-ci
cat .schema.txt | grep -v "^COMMENT ON " | $mysqlCmd
echo "";
echo "<------------------------------------------------------------------------>"
echo "           The tables of the \"$db_to_create\" database were successfully created."
echo "<------------------------------------------------------------------------>"

# Get the tables to start exporting the data.
for table in "${tables[@]}"; do
  echo "Copying table $db_to_create.$table"

  # Create a insert file
  mdb-export -D "%Y-%m-%d %H:%M:%S" -I mysql -R ";\r\n" "$db_to_read" $table > "$table".sql
  if [ "$table" == "$grepTable" ]; then
    echo "grepping table $table for date"
    grep "`date +%Y-%m-%d`" "$table".sql > temp.sql && mv temp.sql "$table".sql \
      || echo "No data to copy from $table" && rm "$table".sql
  fi

  # issue with DEPARTMENTS table, 1st entry has illegal NULL
  if [ "$table" == "DEPARTMENTS" ]; then
    grep -v "OUR COMPANY" "$table".sql > temp.sql
    mv temp.sql "$table".sql
  fi

	# Execute mysql queries.
	$mysqlCmd -e "TRUNCATE table $db_to_create.$table";

  if [ -f "$table".sql ]; then
	  cat "$table".sql | $mysqlCmd
	  rm "$table".sql;
    echo "Copied table $db_to_create.$table"
  fi

done

echo "";
echo "<------------------------------------------------------------------------>"
echo "           Done"
echo "<------------------------------------------------------------------------>"

