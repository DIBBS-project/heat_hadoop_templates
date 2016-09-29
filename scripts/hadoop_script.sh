#!/usr/bin/bash

function clean_hadoop() {
    echo "Cleaning running hadoop services"
    $(ps aux | grep java  | grep -v grep | awk '{print $2}' | sudo xargs kill -9) || true

    echo "Cleaning existing data in hdfs"
    $(sudo rm -rf /home/hadoop/hadoopdata/hdfs/datanode) || true

    echo "Cleaning hadoop logs"
    $(sudo rm -rf /usr/hadoop/hadoop/logs/*) || true
}

function repair_permissions() {

    # Repair permissions
    pushd /usr/hadoop

    sudo chmod 777 start_hadoop.sh
    sudo chmod 777 reload.sh

    sudo chmod 777 hadoop/etc/hadoop
    sudo chmod 777 hadoop/etc/hadoop/*

    popd
}

function install_hadoop() {

    HADOOP_USERNAME=$1
    HADOOP_MASTER_NAME=$2
    HADOOP_NODE_NAME=$3

    # Configure an hadoop folder
    sudo mkdir -p /usr/hadoop
    sudo chown $HADOOP_USERNAME /usr/hadoop

    # Configure hadoop node
    pushd /usr/hadoop
    echo "$HADOOP_NODE_NAME" > hadoop/etc/hadoop/slaves
    echo "$HADOOP_MASTER_NAME" > hadoop/etc/hadoop/masters

    # Export variables
    echo "" > environment
    cat >> environment <<- EOM
export HADOOP_HOME=/usr/hadoop/hadoop
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin:/sbin:/bin:
export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk/
EOM

    sudo cp environment /etc/environment
    source /etc/environment

    HADOOP_USER_HOME_PATH=$(eval echo ~$HADOOP_USERNAME)
    echo "source /etc/environment" >> $HADOOP_USER_HOME_PATH/.bashrc
    sudo cp $HADOOP_USER_HOME_PATH/.bashrc /root/.bashrc || true

    cd hadoop/etc/hadoop

    # Configure Hadoop
    cat > core-site.xml <<- EOM
<configuration>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://$HADOOP_MASTER_NAME:9000</value>
  </property>
</configuration>
EOM

    cat > hdfs-site.xml <<- EOM
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>

  <property>
    <name>dfs.permissions</name>
    <value>false</value>
  </property>

  <property>
    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
    <value>false</value>
  </property>

  <property>
    <name>dfs.name.dir</name>
    <value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
  </property>

  <property>
    <name>dfs.data.dir</name>
    <value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
  </property>
</configuration>
EOM

    cat > mapred-site.xml <<- EOM
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>

  <property>
    <name>yarn.app.mapreduce.am.staging-dir</name>
    <value>/user</value>
  </property>
</configuration>

EOM

        cat > yarn-site.xml <<- EOM
<configuration>
  <property>
    <name>yarn.resourcemanager.webapp.address</name>
    <value>0.0.0.0:8088</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>$HADOOP_MASTER_NAME</value>
  </property>
  <property>
    <name>yarn.resourcemanager.address</name>
    <value>$HADOOP_MASTER_NAME:8032</value>
  </property>
  <property>
    <name>yarn.resourcemanager.scheduler.address</name>
    <value>$HADOOP_MASTER_NAME:8030</value>
  </property>
  <property>
    <name>yarn.resourcemanager.resource-tracker.address</name>
    <value>$HADOOP_MASTER_NAME:8031</value>
  </property>
</configuration>
EOM

    if [ "$HADOOP_MASTER_NAME" == "$HADOOP_NODE_NAME" ]; then
       # Format namenode
       cd /usr/hadoop
       $HADOOP_HOME/bin/hdfs namenode -format
    fi

    # Run Hadoop cluster
    cd /usr/hadoop/

    if [ "$HADOOP_MASTER_NAME" == "$HADOOP_NODE_NAME" ]; then
       cat > start_hadoop.sh <<- EOM
#!/bin/bash
bash \$HADOOP_HOME/sbin/start-dfs.sh
bash \$HADOOP_HOME/sbin/start-yarn.sh
EOM
    else
           cat > start_hadoop.sh <<- EOM
#!/bin/bash
bash \$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
bash \$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager
bash \$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager
EOM
    fi

    screen -dm bash start_hadoop.sh

    cat > reload.sh <<- EOM
#!/bin/bash
EOM

    popd
}

function install_and_configure_agents() {
    pushd /usr/hadoop

    # Start a screen for the agents
    sudo yum install -y screen || true

    SCREEN_NAME="agents"
    COMMON_SCREEN_ARGS="-S $SCREEN_NAME -X screen"
    screen -AdmS $SCREEN_NAME

    ############################################################################
    # Cloning Agents projects and preparing dependencies
    ############################################################################
    git clone https://github.com/DIBBS-project/operation_manager_agent.git
    git clone https://github.com/DIBBS-project/resource_manager_agent.git
    git clone https://github.com/badock/ChameleonHadoopWebservice.git

    sudo yum install -y python-pip

    sudo pip install -r operation_manager_agent/requirements.txt
    sudo pip install -r resource_manager_agent/requirements.txt
    sudo pip install -r ChameleonHadoopWebservice/requirements.txt

    ############################################################################
    # Install Operation Manager Agent
    ############################################################################

    pushd operation_manager_agent

    cat > configure_webservice.sh <<- EOM
#!/bin/bash

pushd /usr/hadoop/operation_manager_agent
bash reset.sh
python manage.py runserver 0.0.0.0:8011

EOM

    screen $COMMON_SCREEN_ARGS -t pm_agent -dm bash /usr/hadoop/operation_manager_agent/configure_webservice.sh
    popd

    ############################################################################
    # Install Resource Manager Agent
    ############################################################################

    pushd resource_manager_agent

    cat > configure_webservice.sh <<- EOM
#!/bin/bash

pushd /usr/hadoop/resource_manager_agent
bash reset.sh
python manage.py runserver 0.0.0.0:8012

EOM

    screen $COMMON_SCREEN_ARGS -t rm_agent -dm bash /usr/hadoop/resource_manager_agent/configure_webservice.sh
    popd


    ############################################################################
    # Install Hadoop Webservice (legacy)
    ############################################################################

    pushd ChameleonHadoopWebservice

    cat > configure_webservice.sh <<- EOM
#!/bin/bash

pushd /usr/hadoop/ChameleonHadoopWebservice
bash reset_app.sh
python manage.py runserver 0.0.0.0:8000

EOM

    screen $COMMON_SCREEN_ARGS -t hadoop_agent -dm bash /usr/hadoop/ChameleonHadoopWebservice/configure_webservice.sh
    popd

    popd
}

