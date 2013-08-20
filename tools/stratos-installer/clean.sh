#!/bin/bash
# ----------------------------------------------------------------------------
#
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing,
#  software distributed under the License is distributed on an
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#  KIND, either express or implied.  See the License for the
#  specific language governing permissions and limitations
#  under the License.
#
# ----------------------------------------------------------------------------
#
# This script is for cleaning the host machine where one or more of the Stratos servers are run.
# Make sure the user is running as root.
# ----------------------------------------------------------------------------


if [ "$UID" -ne "0" ]; then
	echo ; echo "  You must be root to run $0.  (Try running 'sudo bash' first.)" ; echo 
	exit 69
fi

function help {
    echo ""
    echo "Clean the host machine where one or more of the Stratos2 servers are run."
    echo "usage:"
    echo "clean.sh -a<hostname> -b<stratos username> -c<mysql username> -d<mysql password>"
    echo ""
}

while getopts a:b:c:d: opts
do
  case $opts in
    a)
        hostname=${OPTARG}
        ;;
    b)
        host_user=${OPTARG}
        ;;
    c)
        mysql_user=${OPTARG}
        ;;
    d)
        mysql_pass=${OPTARG}
        ;;
    *)
        help
        exit 1
        ;;
  esac
done

function helpclean {
    echo ""
    echo "usage:"
    echo "clean.sh -a<hostname> -b<stratos username> -c<mysql username> -d<mysql password>"
    echo ""
}

function clean_validate {

if [[ ( -z $hostname || -z $host_user || -z $mysql_user || -z $mysql_pass ) ]]; then
    helpclean
    exit 1
fi
}

clean_validate

if [[ -d /home/git ]]; then
    deluser git
    rm -fr /home/git
fi
mysql -u $mysql_user -p$mysql_pass -e "DROP DATABASE IF EXISTS stratos_foundation;"
mysql -u $mysql_user -p$mysql_pass -e "DROP DATABASE IF EXISTS userstore;"
#mysql -u $mysql_user -p$mysql_pass -e "DROP DATABASE IF EXISTS billing;"

killall java
sleep 15
rm -rf $stratos_path/*
rm -rf $log_path/*
#rm -f /home/$host_user/.ssh/id_rsa

#remove contents of upload folder
if [[ -d /home/$host_user/upload ]]; then
    rm -f /home/$host_user/upload/*
fi

#clean /etc/hosts
KEYWORD='git.'
if grep -Fxq "$KEYWORD" /etc/hosts
then
    cat /etc/hosts | grep -v "$KEYWORD" > /tmp/hosts
    mv /tmp/hosts /etc/hosts
fi

#if grep -Fxq "$hostname" /etc/hosts
#then
#    cat /etc/hosts | grep -v "$hostname" > /tmp/hosts
#    mv /tmp/hosts /etc/hosts
#fi

