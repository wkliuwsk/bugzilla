#!/bin/bash

echo "========== bugzilla_config start =========="
cd $BUGZILLA_ROOT

# Configure database
echo "========== start mysqld_safe =========="
/usr/bin/mysqld_safe &
sleep 5
echo "========== start mysqld_safe end =========="
mysql -u root mysql -e "GRANT ALL PRIVILEGES ON *.* TO bugs@localhost IDENTIFIED BY 'bugs'; FLUSH PRIVILEGES;"
mysql -u root mysql -e "CREATE DATABASE bugs CHARACTER SET = 'utf8';"

perl checksetup.pl /checksetup_answers.txt
perl checksetup.pl /checksetup_answers.txt

mysqladmin -u root shutdown

echo "========== bugzilla_config end =========="