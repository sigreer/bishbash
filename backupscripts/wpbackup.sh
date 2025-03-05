#!/bin/bash

## This script is old and needs updating. Use at your own risk.

if [ -f "./.env" ]
then
echo "Found .env file in current directory"
source .env
else
   echo "Couldn't find .env file in current directory, please enter DB name:"
   read dbname
   echo "Please enter SQL username:"
   read sqluser
   echo "Please enter SQL password:"
   read -s sqlpass
   echo "Please enter the full path of your root website directory:"
   read websiteroot
fi
echo "creating tar for web files..."
tar -zcvf $dbname-files.tar.gz $websiteroot
if [ -f "./$dbname-files.tar.gz" ]
then
  echo "Successfully backed your site up to $dbname-files.tar.gz"
else
  echo "Looks like something went wrong whilst backing up your websites files"
  exit 0
fi
mysqldump -u $sqluser -p$sqlpass --add-drop-table -h localhost $dbname | bzip2 -c > $dbname.sql.bz2
if [ -f "./$dbname.sql.bz2" ]
then
  echo "Successfully backed up your site's database to $dbname.sql.bz2"
else
  echo "Looks like something went wrong whilst backing up your DB"
  exit 0
fi
echo "Adding files and DB to single tar..."
tar -zcvf $dbname.tar.gz $dbname.sql.bz2 $dbname-files.tar.gz
if [ -f "./$dbname.tar.gz" ]
then
  echo "Successfully backed your site up to $dbname.tar.gz"
  rm ./{$dbname.sql.bz2,$dbname-files.tar.gz}
else
  echo "Looks like something went wrong whilst generating your final backup file"
  exit 0
fi
exit 0
