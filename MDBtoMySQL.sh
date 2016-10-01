#!/usr/bin/env bash

# Table 2-1. MDB Utilities
# Name	Description
# mdb-tables	list tables in the specified file
# mdb-schema	generate schema DDL for the specified file
# mdb-export	generate CSV style output for a table

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

TOOLS=$(which scribus >/dev/null 2>&1);
# Check if mdbtools are installed.
command -v mdb-tables >/dev/null 2>&1 || { echo >&2 "I require mdb-tools but they are not installed. Aborting."; exit 1; }
command -v mysql >/dev/null 2>&1 || { echo >&2 "I require MySQL but it is not installed. Aborting."; exit 1; }

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

# Check the permissions/owner.
if [[ ! -O "$db_to_read" ]]; then
	echo "You are not the owner of this file. Aborting the operation.";
	echo "";
	exit 1;
fi

# Check if the file exists.
if [[ ! -f "$db_to_read" ]]; then
	echo "The file was not found.";
	echo "Check the name and the path and try again.";
	echo "Aborting.";
	exit 1;
fi

# Check the name provided.
if [[ "$db_to_read" =~ [\],!,\\,@,#,$,%,^,\&,\*,\(,\),\?,\<,\>,{,},\[]+ ]] || [[ "$db_to_read" =~ [[:space:]]+ ]]; then
	echo "It is preferable to not include any special characters or spaces in the name.";
	echo "Please, rename the file and try again.";
	echo "Aborting.";
	exit 1;
fi

echo "";
echo "Please, provide the name of the database that will be created.";
echo "Do not use spaces or any special characters:";
read db_to_create;

# Check the name provided.
if [[ "$db_to_create" =~ [\],!,\\,@,#,$,%,^,\&,\*,\(,\),\?,\<,\>,{,},\[]+ ]] || [[ "$db_to_create" =~ [[:space:]]+ ]]; then
	echo "No special characters or spaces are allowed in the database name.";
	echo "Aborting.";
	exit 1;
fi

# Create the database.
echo "";
echo "!!! Attention !!!";
echo "If there already is a database with the same name, it is about to be deleted!!!";
echo "Press \"Y\" to confirm and continue.";
echo "Press \"N\" to abort the operation.";
read proceed;

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

# Create the database.
mysql -u$user -p$password -e "DROP DATABASE IF EXISTS $db_to_create";
mysql -u$user -p$password -e "CREATE DATABASE $db_to_create DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;";
echo "";
echo "<------------------------------------------------------------------------>"
echo "           Database \"$db_to_create\" was successfully created."
echo "<------------------------------------------------------------------------>"

# Create the query that will create the tables.
sql_query=$(
mdb-schema db.mdb  \
| sed -r 's/(\[[a-zA-Z0-9]+)(\ )/\1_/g' \
| sed "s/type.*/VARCHAR (255),/g" \
| sed "s/\]//g" \
| sed "s/\[//g" \
| tr '/' '_' \
| sed 's/Long\ Integer/INT UNSIGNED/g' \
| sed 's/Integer/INT UNSIGNED/g' \
| sed -r "s/Text \(.+\)/VARCHAR (255)/g" \
| sed "s/Memo_Hyperlink\ (.*)/VARCHAR (255)/g" \
| sed "s/ID/id/g" \
| sed "s/Boolean/TINYINT UNSIGNED/g" \
| sed "s/DateTime/DATE/g" \
| sed "s/id INT/id INT UNSIGNED AUTO INCEMENT NOT NULL/g" \
| sed "s/[[:space:]]\+/\ /g" \
| awk 'NR >= 10'
);

# Execute the query.
mysql -u"$user" -p"$password" -e "USE $db_to_create $sql_query";
echo "";
echo "<------------------------------------------------------------------------>"
echo "           The tables of the \"$db_to_create\" database were successfully created."
echo "<------------------------------------------------------------------------>"
