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
#  Server configuration script for Apache Stratos
# ----------------------------------------------------------------------------

# Die on any error:
set -e

SLEEP=60

source "./conf/setup.conf"
export LOG=$log_path/stratos-setup.log

mb="false"
cc="false"
lb="false"
as="false"
sm="false"
cep="false"
product_list="mb;cc;cep;lb;as;sm"
enable_internal_git=false

function help {
    echo ""
    echo "Usage:"
    echo "setup.sh -u <host username> -p \"<product list>\""
    echo "product list : [mb, cc, lb, as, sm, cep]"
    echo "Example:"
    echo "sudo ./setup.sh -p \"cc lb\""
    echo "sudo ./setup.sh -p \"all\""
    echo ""
    echo "-u: <host username> The login user of the host."
    echo "-p: <product list> Apache Stratos products to be installed on this node. Provide one or more names of the servers."
    echo "    The available servers are cc, lb, as, sm or all. 'all' means you need to setup all servers in this machine. Default is all"
    echo "-g: <enable_internal_git> true|false Whether enable internal git repo for Stratos2. Default is false"
    echo ""
}

while getopts u:p:g: opts
do
  case $opts in
    p)
        product_list=${OPTARG}
        ;;
    g)
        enable_internal_git=${OPTARG}
        ;;
    \?)
        help
        exit 1
        ;;
  esac
done


arr=$(echo $product_list | tr " " "\n")

for x in $arr
do
    if [[ $x = "mb" ]]; then
        mb="true"
    fi
    if [[ $x = "cc" ]]; then
        cc="true"
    fi
    if [[ $x = "cep" ]]; then
        cep="true"
    fi
    if [[ $x = "lb" ]]; then
        lb="true"
    fi
    if [[ $x = "as" ]]; then
        as="true"
    fi
    if [[ $x = "sm" ]]; then
        sm="true"
    fi
    if [[ $x = "all" ]]; then
        mb="true"
        cep="true"
        cc="true"
        lb="true"
        as="true"
        sm="true"
    fi
done

product_list=`echo $product_list | sed 's/^ *//g' | sed 's/ *$//g'`
if [[ -z $product_list || $product_list = "" ]]; then
    help
    exit 1
fi

echo "user provided in conf/setup.conf is $host_user. If you want to provide some other user name please specify it at the prompt."
echo "If you want to continue with $host_user just press enter to continue"
read username
if [[ $username != "" ]]; then
    host_user=$username
fi
user=`id $host_user`
if [[ $? = 1 ]]; then
    echo "User $host_user does not exist. The system will create it."
    adduser --home /home/$host_user $host_user
fi

echo "StrictHostKeyChecking no" > /home/$host_user/.ssh/config
chmod 600 /home/$host_user/.ssh/config
chown $host_user:$host_user /home/$host_user/.ssh/config
export $enable_internal_git
export $host_user
export hostname=`hostname -f`



function helpsetup {
    echo ""
    echo "Please set up the $1 related environment variables correctly in conf/setup.conf"
    echo ""
}

function general_conf_validate {
    if [[ ! -d $JAVA_HOME ]]; then
        echo "Please set the JAVA_HOME environment variable for the running user"
        exit 1
    fi
    export JAVA_HOME=$JAVA_HOME

    if [[ -z $stratos_domain ]]; then
        echo "Please specify the stratos domain"
        exit 1
    fi
    if [[ (-z $mb_port_offset || -z $mb_ip ) ]]; then
        echo "Please specify the ip and the port offset of MB"
        exit 1
    fi
}

function mb_conf_validate {
    if [[ -z $mb_path ]]; then
	helpsetup MB
	exit 1
    fi
}

function cep_conf_validate {
    if [[ (-z $cep_path || -z $cep_port_offset) ]]; then
	helpsetup CEP
	exit 1
    fi
    if [[ ! -f $cep_extension_jar ]]; then
        echo "Please copy the cep extension jar into the same folder as this command(stratos release pack folder) and update conf/setup.conf file"
        exit 1
    fi
}

function lb_conf_validate {
    if [[ -z $lb_path ]]; then
	helpsetup LB
	exit 1
    fi
    if [[ -z $lb_cep_ip ]]; then
	echo "Please specify the ip of CEP in conf/setup.conf"
	exit 1
    fi
}

function cc_conf_validate {
    if [[ (-z $cc_path || -z $cc_port_offset) ]]; then
	helpsetup CC
	exit 1
    fi

    if [[ $ec2_provider_enabled = "false" && $openstack_provider_enabled = "false" ]]; then
        echo "Please enable at least one of the IaaS providers in conf/setup.conf file"
        exit 1
    fi

    if [[ $openstack_provider_enabled = "true" ]]; then
        if [[ ( -z $openstack_identity || -z $openstack_credential || -z $openstack_jclouds_endpoint ) ]]; then
            echo "Please set openstack configuration information in conf/setup.conf file"
            exit 1
        fi
    fi

    if [[ $ec2_provider_enabled = "true" ]]; then
        if [[ ( -z $ec2_identity || -z $ec2_credential || -z $ec2_keypair_name ) ]]; then
            echo "Please set ec2 configuration information in conf/setup.conf file"
            exit 1
        fi
    fi
}

function as_conf_validate {
    if [[ (-z $as_path || -z $as_port_offset) ]]; then
	helpsetup AS
	exit 1
    fi
}

function sm_conf_validate {
    if [[ (-z $sm_path || -z $sm_port_offset || -z $stratos_foundation_db_user || -z $stratos_foundation_db_pass) ]]; then
	helpsetup SM
	exit 1
    fi
    if [[ ! -f $mysql_connector_jar ]]; then
        echo "Please copy the mysql connector jar into the same folder as this command(stratos2 release pack folder) and update conf/setup.conf file"
        exit 1
    fi
    if [[ -z $cc_port_offset ]]; then
        echo "Please specify the port offset of CC"
        exit 1
    fi

}


general_conf_validate
if [[ $mb = "true" ]]; then
    mb_conf_validate
fi
if [[ $cep = "true" ]]; then
    cep_conf_validate
fi
if [[ $lb = "true" ]]; then
    lb_conf_validate
fi
if [[ $cc = "true" ]]; then
    cc_conf_validate
fi
if [[ $as = "true" ]]; then
    as_conf_validate
fi
if [[ $sm = "true" ]]; then
    sm_conf_validate
fi


# Make sure the user is running as root.
if [ "$UID" -ne "0" ]; then
	echo ; echo "  You must be root to run $0.  (Try running 'sudo bash' first.)" ; echo 
	exit 69
fi

if [[ ! -d $log_path ]]; then
    mkdir -p $log_path
fi




echo ""
echo "For all the questions asked while during executing the script please just press the enter button"
echo ""

if [[ $mb = "true" ]]; then
    if [[ ! -d $mb_path ]]; then
        unzip $mb_pack_path -d $stratos_path
    fi
fi
if [[ $cep = "true" ]]; then
    if [[ ! -d $cep_path ]]; then
        unzip $cep_pack_path -d $stratos_path
    fi
fi
if [[ $lb = "true" ]]; then
    if [[ ! -d $lb_path ]]; then
        unzip $lb_pack_path -d $stratos_path
    fi
fi
if [[ $cc = "true" ]]; then
    if [[ ! -d $cc_path ]]; then
        unzip $cc_pack_path -d $stratos_path
    fi
fi
if [[ $as = "true" ]]; then
    if [[ ! -d $as_path ]]; then
        unzip $as_pack_path -d $stratos_path
    fi
fi
if [[ $sm = "true" ]]; then
    if [[ ! -d $resource_path ]]; then
        cp -rf ./resources $stratos_path
    fi
    if [[ ! -d $sm_path ]]; then
        unzip $sm_pack_path -d $stratos_path
    fi
fi



# ------------------------------------------------
# Setup MB
# ------------------------------------------------
function mb_setup {
    echo "Setup MB" >> $LOG
    echo "Configuring the Message Broker"

    pushd $mb_path

    echo "In repository/conf/carbon.xml"
    cp -f repository/conf/carbon.xml repository/conf/carbon.xml.orig
    cat repository/conf/carbon.xml.orig | sed -e "s@<Offset>0</Offset>@<Offset>${mb_port_offset}</Offset>@g" > repository/conf/carbon.xml

    echo "End configuring the Message Broker"
    popd #mb_path
}

if [[ $mb = "true" ]]; then
    mb_setup
fi

# ------------------------------------------------
# Setup CEP
# ------------------------------------------------
function cep_setup {
    echo "Setup CEP" >> $LOG
    echo "Configuring the Complex Event Processor"

    cp -f ./config/cep/repository/conf/jndi.properties $cep_path/repository/conf/
    cp -f $cep_extension_jar $cep_path/repository/components/lib/
    cp -f $cep_extension_path/artifacts/eventbuilders/*.xml $cep_path/repository/deployment/server/eventbuilders/
    cp -f $cep_extension_path/artifacts/inputeventadaptors/*.xml $cep_path/repository/deployment/server/inputeventadaptors/
    cp -f $cep_extension_path/artifacts/outputeventadaptors/*.xml $cep_path/repository/deployment/server/outputeventadaptors/
    cp -f $cep_extension_path/artifacts/executionplans/*.xml $cep_path/repository/deployment/server/executionplans/
    cp -f $cep_extension_path/artifacts/eventformatters/*.xml $cep_path/repository/deployment/server/eventformatters/

    pushd $cep_path

    echo "In repository/conf/carbon.xml"
    cp -f repository/conf/carbon.xml repository/conf/carbon.xml.orig
    cat repository/conf/carbon.xml.orig | sed -e "s@<Offset>0</Offset>@<Offset>${cep_port_offset}</Offset>@g" > repository/conf/carbon.xml

    echo "In repository/conf/jndi.properties"
    cp -f repository/conf/jndi.properties repository/conf/jndi.properties.orig
    cat repository/conf/jndi.properties.orig | sed -e "s@MB_HOSTNAME:MB_LISTEN_PORT@$mb_hostname:$cep_mb_listen_port@g" > repository/conf/jndi.properties

    echo "In repository/conf/siddhi/siddhi.extension"
    cp -f repository/conf/siddhi/siddhi.extension repository/conf/siddhi/siddhi.extension.orig
    echo "org.apache.stratos.cep.extension.GradientFinderWindowProcessor" >> repository/conf/siddhi/siddhi.extension.orig
    echo "org.apache.stratos.cep.extension.SecondDerivativeFinderWindowProcessor" >> repository/conf/siddhi/siddhi.extension.orig
    echo "org.apache.stratos.cep.extension.FaultHandlingWindowProcessor" >> repository/conf/siddhi/siddhi.extension.orig
    mv -f repository/conf/siddhi/siddhi.extension.orig repository/conf/siddhi/siddhi.extension

    echo "End configuring the Complex Event Processor"
    popd #cep_path
}
if [[ $cep = "true" ]]; then
    cep_setup
fi

# ------------------------------------------------
# Setup LB
# ------------------------------------------------    
function lb_setup {
    echo "Setup LB" >> $LOG
    echo "Configuring the Load Balancer"

    cp -f ./config/lb/repository/conf/loadbalancer.conf $lb_path/repository/conf/
    cp -f ./config/lb/repository/conf/axis2/axis2.xml $lb_path/repository/conf/axis2/

    pushd $lb_path

    echo "In repository/conf/loadbalancer.conf" >> $LOG
    cp -f repository/conf/loadbalancer.conf repository/conf/loadbalancer.conf.orig
    cat repository/conf/loadbalancer.conf.orig | sed -e "s@MB_IP@$lb_mb_ip@g" > repository/conf/loadbalancer.conf

    cp -f repository/conf/loadbalancer.conf repository/conf/loadbalancer.conf.orig
    cat repository/conf/loadbalancer.conf.orig | sed -e "s@MB_LISTEN_PORT@$lb_mb_listen_port@g" > repository/conf/loadbalancer.conf
    
    cp -f repository/conf/loadbalancer.conf repository/conf/loadbalancer.conf.orig
    cat repository/conf/loadbalancer.conf.orig | sed -e "s@CEP_IP@$lb_cep_ip@g" > repository/conf/loadbalancer.conf

    cp -f repository/conf/loadbalancer.conf repository/conf/loadbalancer.conf.orig
    cat repository/conf/loadbalancer.conf.orig | sed -e "s@CEP_LISTEN_PORT@$lb_cep_tcp_port@g" > repository/conf/loadbalancer.conf

    popd #lb_path
    echo "End configuring the Load Balancer"
}

if [[ $lb = "true" ]]; then
    lb_setup
fi

# ------------------------------------------------
# Setup CC
# ------------------------------------------------
function cc_setup {
    echo "Setup CC" >> $LOG
    echo "Configuring the Cloud Controller"

    echo "Creating payload directory ... " >> $LOG
    if [[ ! -d $cc_path/repository/resources/payload ]]; then
        mkdir -p $cc_path/repository/resources/payload
    fi

    cp -f ./config/cc/repository/conf/cloud-controller.xml $cc_path/repository/conf/
    cp -f ./config/cc/repository/conf/carbon.xml $cc_path/repository/conf/
    cp -f ./config/cc/repository/conf/jndi.properties $cc_path/repository/conf/

    echo "In repository/conf/cloud-controller.xml"
    if [[ $ec2_provider_enabled = true ]]; then
        ./ec2.sh
    fi
    if [[ $openstack_provider_enabled = true ]]; then
        ./openstack.sh
    fi

    pushd $cc_path
    
    cp -f repository/conf/cloud-controller.xml repository/conf/cloud-controller.xml.orig
    cat repository/conf/cloud-controller.xml.orig | sed -e "s@MB_HOSTNAME:MB_LISTEN_PORT@$mb_hostname:$cc_mb_listen_port@g" > repository/conf/cloud-controller.xml

    echo "In repository/conf/carbon.xml"
    cp -f repository/conf/carbon.xml repository/conf/carbon.xml.orig
    cat repository/conf/carbon.xml.orig | sed -e "s@CC_PORT_OFFSET@$cc_port_offset@g" > repository/conf/carbon.xml

    echo "In repository/conf/jndi.properties"
    cp -f repository/conf/jndi.properties repository/conf/jndi.properties.orig
    cat repository/conf/jndi.properties.orig | sed -e "s@MB_HOSTNAME:MB_LISTEN_PORT@$mb_hostname:$cc_mb_listen_port@g" > repository/conf/jndi.properties

    popd #cc_path
    echo "End configuring the Cloud Controller"
}

if [[ $cc = "true" ]]; then
   cc_setup
fi

# ------------------------------------------------
# Setup AS
# ------------------------------------------------   
function as_setup {
    echo "Setup AS" >> $LOG
    echo "Configuring the Auto Scalar"

    cp -f ./config/as/repository/conf/carbon.xml $as_path/repository/conf/
    cp -f ./config/as/repository/conf/jndi.properties $as_path/repository/conf/

    pushd $as_path

    echo "In repository/conf/carbon.xml"
    cp -f repository/conf/carbon.xml repository/conf/carbon.xml.orig
    cat repository/conf/carbon.xml.orig | sed -e "s@AS_PORT_OFFSET@$as_port_offset@g" > repository/conf/carbon.xml

    echo "In repository/conf/jndi.properties"
    cp -f repository/conf/jndi.properties repository/conf/jndi.properties.orig
    cat repository/conf/jndi.properties.orig | sed -e "s@MB_HOSTNAME:MB_LISTEN_PORT@$mb_hostname:$as_mb_listen_port@g" > repository/conf/jndi.properties

    popd #as_path
    echo "End configuring the Auto smalar"
}

if [[ $as = "true" ]]; then
    as_setup
fi



# ------------------------------------------------
# Setup SM
# ------------------------------------------------
function sm_setup {
    echo "Setup SM" >> $LOG
    echo "Configuring Stratos Manager"

    cp -f ./config/sc/repository/conf/carbon.xml $sm_path/repository/conf/
    cp -f ./config/sm/repository/conf/jndi.properties $sm_path/repository/conf/
    cp -f ./config/sm/repository/conf/cartridge-config.properties $sm_path/repository/conf/
    cp -f ./config/sm/repository/conf/datasources/master-datasources.xml $sm_path/repository/conf/datasources/
    cp -f $mysql_connector_jar $sm_path/repository/components/lib/

    pushd $sm_path

    echo "In repository/conf/carbon.xml"
    cp -f repository/conf/carbon.xml repository/conf/carbon.xml.orig
    cat repository/conf/carbon.xml.orig | sed -e "s@SC_PORT_OFFSET@$sm_port_offset@g" > repository/conf/carbon.xml

    echo "In repository/conf/jndi.properties"
    cp -f repository/conf/jndi.properties repository/conf/jndi.properties.orig
    cat repository/conf/jndi.properties.orig | sed -e "s@MB_HOSTNAME:MB_LISTEN_PORT@$mb_hostname:$sm_mb_listen_port@g" > repository/conf/jndi.properties

    echo "In repository/conf/cartridge-config.properties" >> $LOG

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@CC_HOSTNAME:CC_HTTPS_PORT@$cc_hostname:$sm_cc_https_port@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@STRATOS_DOMAIN@$stratos_domain@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@SC_HOSTNAME:SC_HTTPS_PORT@$sm_ip:$sm_https_port@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@STRATOS_FOUNDATION_DB_HOSTNAME:STRATOS_FOUNDATION_DB_PORT@$stratos_foundation_db_hostname:$stratos_foundation_db_port@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@STRATOS_FOUNDATION_DB_USER@$stratos_foundation_db_user@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@STRATOS_FOUNDATION_DB_PASS@$stratos_foundation_db_pass@g" > repository/conf/cartridge-config.properties

    cp -f repository/conf/cartridge-config.properties repository/conf/cartridge-config.properties.orig
    cat repository/conf/cartridge-config.properties.orig | sed -e "s@STRATOS_FOUNDATION_DB_SCHEMA@$stratos_foundation_db_schema@g" > repository/conf/cartridge-config.properties

    echo "In repository/conf/datasources/master-datasources.xml" >> $LOG
    cp -f repository/conf/datasources/master-datasources.xml repository/conf/datasources/master-datasources.xml.orig
    cat repository/conf/datasources/master-datasources.xml.orig | sed -e "s@USERSTORE_DB_HOSTNAME@$userstore_db_hostname@g" > repository/conf/datasources/master-datasources.xml

    cp -f repository/conf/datasources/master-datasources.xml repository/conf/datasources/master-datasources.xml.orig
    cat repository/conf/datasources/master-datasources.xml.orig | sed -e "s@USERSTORE_DB_PORT@$userstore_db_port@g" > repository/conf/datasources/master-datasources.xml

    cp -f repository/conf/datasources/master-datasources.xml repository/conf/datasources/master-datasources.xml.orig
    cat repository/conf/datasources/master-datasources.xml.orig | sed -e "s@USERSTORE_DB_SCHEMA@$userstore_db_schema@g" > repository/conf/datasources/master-datasources.xml

    cp -f repository/conf/datasources/master-datasources.xml repository/conf/datasources/master-datasources.xml.orig
    cat repository/conf/datasources/master-datasources.xml.orig | sed -e "s@USERSTORE_DB_USER@$userstore_db_user@g" > repository/conf/datasources/master-datasources.xml

    cp -f repository/conf/datasources/master-datasources.xml repository/conf/datasources/master-datasources.xml.orig
    cat repository/conf/datasources/master-datasources.xml.orig | sed -e "s@USERSTORE_DB_PASS@$userstore_db_pass@g" > repository/conf/datasources/master-datasources.xml

    popd # sm_path


    # Database Configuration
    # -----------------------------------------------
    echo "Create and configure MySql Databases" >> $LOG

    echo "Creating userstore database"
    mysql -u$userstore_db_user -p$userstore_db_pass < $resource_path/userstore.sql
    
    echo "Creating stratos_foundation database"
    mysql -u$stratos_foundation_db_user -p$stratos_foundation_db_pass < $resource_path/stratos_foundation.sql


    #Copy https://svn.wso2.org/repos/wso2/scratch/hosting/build/tropos/resources/append_zone_file.sh into /opt/scripts folder
    if [[ ! -d $stratos_path/scripts ]]; then
        mkdir -p $stratos_path/scripts
    fi
    cp -f ./scripts/add_entry_zone_file.sh $stratos_path/scripts/add_entry_zone_file.sh
    cp -f ./scripts/remove_entry_zone_file.sh $stratos_path/scripts/remove_entry_zone_file.sh


    echo "End configuring the SM"
}

if [[ $sm = "true" ]]; then
    sm_setup
fi


# ------------------------------------------------
# Starting the servers
# ------------------------------------------------
echo "Starting the servers" >> $LOG
#Starting the servers in the following order is recommended
#mb, cc, elb, is, agent, sm

echo "Starting up servers. This may take time. Look at $LOG file for server startup details"

chown -R $host_user.$host_user $log_path
chmod -R 777 $log_path

export setup_dir=$PWD
su - $host_user -c "source $setup_dir/conf/setup.conf;$setup_dir/start-servers.sh -p$product_list >> $LOG"

echo "Servers started. Please look at $LOG file for server startup details"
if [[ $sm == "true" ]]; then
    echo "**************************************************************"
    echo "Management Console : https://$stratos_domain:$sm_https_port/"
    echo "**************************************************************"
fi

