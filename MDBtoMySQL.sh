#!/usr/bin/env bash

echo "";
echo "<--------------------------- MDBtoSQL --------------------------------->";
echo "";
echo 'This script presupposes that "mdbtools" are installed in your system.';
echo 'If not, install them with "sudo apt-get install mdbtools" in a Debian(ish) system.';

# Get all the info you need.
sleep 1;
echo "";
echo "Please, provide the name of the database that will be created.";
echo "Do not use spaces or any special characters:";
read db_to_create;
echo "$db_to_create";

echo "";
echo "Please, provide the name of the mdb file.";
echo "Make sure to provide the full path,
if the file is not in the current directory.";
read db_to_read;

# db_Movies.mdb

tables=$(mdb-tables $db_to_read);
#tables=$(mdb-tables $db_to_read | tr " "  "\n");
#for table in $tables; do echo "$table"; done;

# Create the database.
mysql -uroot -proot -e "DROP DATABASE IF EXISTS $db_to_create";
mysql -uroot -proot -e "CREATE DATABASE $db_to_create DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;";
echo "";
echo "<------------------------------------------------------------------------>"
echo "           Database \"$db_to_create\" was successfully created."
echo "<------------------------------------------------------------------------>"

# Create the tables.
for table in $tables;
    do mysql -uroot -proot -e "CREATE TABLE $db_to_create.$table(id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY ( id ))";

    echo "";
    echo "<------------------------------------------------------------------------>"
    echo "           Table \"$table\" was successfully created."
    echo "<------------------------------------------------------------------------>"

done;

