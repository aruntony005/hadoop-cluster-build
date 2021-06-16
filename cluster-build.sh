## Before starting the script do passwordless ssh for hdfs user
## PROVIDE SUDO PERMISSION FOR HDFS USER
## Copy the mariadb jar files

#!/bin/bash

echo "Started Pseudo mode Hadoop cluster installation ..."

ip=`hostname -i`

echo "Node IP : $ip"

sudo yum install java-1.8.0-openjdk-devel wget -y

echo "Installed open JDK"
wget https://downloads.apache.org/hadoop/common/hadoop-3.2.2/hadoop-3.2.2.tar.gz
java_home=`ls -ltr /etc/alternatives/java | sed 's/\/bin\/java//g;s/ //g' | awk -F'>' '{print $2}' | head -n 1`

sudo chown hdfs:hdfs hadoop-3.2.2.tar.gz
tar -xvf hadoop-3.2.2.tar.gz
sudo mv hadoop-3.2.2 /opt/hadoop

cat >> .bash_profile << EOF
export PATH=\$PATH:/opt/hadoop/bin:/opt/hadoop/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/bin
export JAVA_HOME=${java_home}
export HADOOP_HOME=/opt/hadoop
export PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/bin:/bin:/sbin
export HDFS_NAMENODE_USER="hdfs"
export HDFS_DATANODE_USER="hdfs"
export HDFS_SECONDARYNAMENODE_USER="hdfs"
export YARN_RESOURCEMANAGER_USER="hdfs"
export YARN_NODEMANAGER_USER="hdfs"
EOF

cat >> .bashrc << EOF
export PATH=\$PATH:/opt/hadoop/bin:/opt/hadoop/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/bin
export JAVA_HOME=${java_home}
EOF

source ~/.bashrc
source ~/.bash_profile

echo "export JAVA_HOME=${java_home}" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
echo "export HADOOP_HOME=/opt/hadoop" >> /opt/hadoop/etc/hadoop/hadoop-env.sh

sed -i '/configuration/d' /opt/hadoop/etc/hadoop/core-site.xml

cat >> /opt/hadoop/etc/hadoop/core-site.xml << EOF
<configuration>
       <property>
            <name>fs.default.name</name>
            <value>hdfs://${ip}:9000</value>
        </property>
</configuration>
EOF

sed -i '/configuration/d' /opt/hadoop/etc/hadoop/hdfs-site.xml

cat >> /opt/hadoop/etc/hadoop/hdfs-site.xml << EOF
<configuration>
    <property>
            <name>dfs.namenode.name.dir</name>
            <value>/opt/data/nameNode</value>
    </property>
    <property>
            <name>dfs.datanode.data.dir</name>
            <value>/opt/data/dataNode</value>
    </property>
    <property>
            <name>dfs.replication</name>
            <value>1</value>
    </property>
</configuration>
EOF

sed -i '/configuration/d' /opt/hadoop/etc/hadoop/mapred-site.xml

cat >> /opt/hadoop/etc/hadoop/mapred-site.xml << EOF
<configuration>
    <property>
            <name>mapreduce.framework.name</name>
            <value>yarn</value>
    </property>
    <property>
            <name>yarn.app.mapreduce.am.env</name>
            <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
            <name>mapreduce.map.env</name>
            <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
            <name>mapreduce.reduce.env</name>
            <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name>
        <value>512</value>
</property>
<property>
        <name>mapreduce.map.memory.mb</name>
        <value>256</value>
</property>
<property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>256</value>
</property>
</configuration>
EOF

sed -i '/configuration/d' /opt/hadoop/etc/hadoop/yarn-site.xml

cat >> /opt/hadoop/etc/hadoop/yarn-site.xml << EOF
<configuration>
<!-- Site specific YARN configuration properties -->
    <property>
            <name>yarn.acl.enable</name>
            <value>0</value>
    </property>
    <property>
            <name>yarn.resourcemanager.hostname</name>
            <value>${ip}</value>
    </property>
    <property>
            <name>yarn.nodemanager.aux-services</name>
            <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>1536</value>
</property>
<property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>1536</value>
</property>
<property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>128</value>
</property>
<property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
</property>
</configuration>
EOF



echo -e "${ip}" > /opt/hadoop/etc/hadoop/workers
sudo chown -R hdfs:hdfs /opt

hdfs namenode -format

start-all.sh

# Get the hadoop namenode UI in 
# http://<10.128.0.50 ip>:9870/

######## SPARK #############

hdfs dfs -mkdir -p /spark/logs

wget https://downloads.apache.org/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz
tar -xzf spark-2.4.8-bin-hadoop2.7.tgz
mv spark-2.4.8-bin-hadoop2.7 /opt/spark
sudo yum install python3 -y


cat >> .bash_profile << EOF
export SPARK_HOME=/opt/spark
export PATH=\$PATH:\$SPARK_HOME/bin
export LD_LIBRARY_PATH=/opt/hadoop/lib/native
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export PATH=\$PATH:\$HADOOP_HOME/etc/hadoop:\$HADOOP_HOME/lib/native
export PYTHONPATH=\$SPARK_HOME/python:\$SPARK_HOME/python/lib/py4j-0.10.7-src.zip:\$PYTHONPATH
export PYSPARK_PYTHON=python3
EOF

cat >> .bashrc << EOF
export SPARK_HOME=/opt/spark
export PATH=\$PATH:\$SPARK_HOME/bin
EOF

source ~/.bashrc
source ~/.bash_profile

mv /opt/spark/conf/spark-defaults.conf.template /opt/spark/conf/spark-defaults.conf


cat >> /opt/spark/conf/spark-defaults.conf << EOF
spark.${ip}    yarn
spark.driver.memory    512m
spark.yarn.am.memory    512m
spark.executor.memory          512m
spark.eventLog.enabled  true
spark.eventLog.dir hdfs://${ip}:9000/spark/logs
spark.history.provider            org.apache.spark.deploy.history.FsHistoryProvider
spark.history.fs.logDirectory     hdfs://${ip}:9000/spark/logs
spark.history.fs.update.interval  10s
spark.history.ui.port             18080
EOF

mv /opt/spark/conf/spark-env.sh.template /opt/spark/conf/spark-env.sh

# export SPARK_MASTER_HOST='<10.128.0.50-IP>'export JAVA_HOME=<Path_of_JAVA_installation>

echo "export SPARK_MASTER_HOST=${ip}" >> /opt/spark/conf/spark-env.sh
echo "export JAVA_HOME=${java_home}" >> /opt/spark/conf/spark-env.sh

echo "${ip}" > /opt/spark/conf/slaves

sh /opt/spark/sbin/start-all.sh

# Get the spark ui in 
# http://<10.128.0.50 ip>:8080
# Get the yarn resource manager in 
# http://<10.128.0.50 ip>:8088



######### HIVE ################

sudo yum install mariadb-server -y
sudo systemctl start mariadb
sudo yum install mysql-connector-java.noarch -y

# mysql -sfu root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'aruntonyml'";
# mysql -sfu root --password='aruntonyml' -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''";

echo "UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\\_%';
FLUSH PRIVILEGES;" > access.sql

mysql -sfu root < access.sql

sudo mysql -u root --password='root' -e "create database hive"
sudo mysql -u root --password='root' -e "CREATE USER 'hiveuser'@'%' IDENTIFIED BY 'hivepassword'"
sudo mysql -u root --password='root' -e "GRANT ALL PRIVILEGES ON *.* TO 'hiveuser'@'%' WITH GRANT OPTION"

hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -mkdir /tmp
hdfs dfs -chmod -R 777 /user/hive/warehouse
hdfs dfs -chmod -R 777 /tmp

wget https://downloads.apache.org/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz
tar -xzf apache-hive-3.1.2-bin.tar.gz
mv apache-hive-3.1.2-bin /opt/hive

cat >> ~/.bash_profile << EOF
export HIVE_HOME=/opt/hive
export PATH=\$PATH:\$HIVE_HOME/bin
EOF

cat >> ~/.bashrc << EOF
export HIVE_HOME=/opt/hive
export PATH=\$PATH:\$HIVE_HOME/bin
EOF

source ~/.bashrc
source ~/.bash_profile



mv /opt/hive/conf/hive-env.sh.template /opt/hive/conf/hive-env.sh

cat >> /opt/hive/conf/hive-env.sh << EOF
export HADOOP_HOME=/opt/hadoop
export HIVE_CONF_DIR=/opt/hive/conf
EOF


cat > /opt/hive/conf/hive-site.xml << EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:mysql://${ip}:3306/hive</value>
        <description>JDBC connection string used by Hive Metastore</description>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.mariadb.jdbc.Driver</value>
        <description>JDBC Driver class</description>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hiveuser</value>
        <description>Metastore database user name</description>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>hivepassword</value>
        <description>Metastore database password</description>
    </property>
 <property>
    <name>datanucleus.connectionPoolingType</name>
    <value>dbcp</value>
  </property>
 <property>
    <name>hive.metastore.schema.verification</name>
    <value>true</value>
  </property>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://${ip}:9083</value>
    <description>URI for client to contact metastore server</description>
  </property>
</configuration>
EOF

cp /usr/share/java/mysql-connector-java.jar /opt/hive/lib
cp /usr/share/java/mysql-connector-java.jar /opt/spark/jars/
cp /opt/hadoop/share/hadoop/common/lib/guava-27.0-jre.jar /opt/hive/lib
rm /opt/hive/lib/guava-19.0.jar
sudo chown hdfs:hdfs /opt/hive/lib/mysql-connector-java.jar
sudo chown hdfs:hdfs /opt/spark/jars/mysql-connector-java.jar

# wget https://downloads.mariadb.com/Connectors/java/connector-java-2.5.4/mariadb-java-client-2.5.4-sources.jar
# wget https://downloads.mariadb.com/Connectors/java/connector-java-2.5.4/mariadb-java-client-2.5.4-javadoc.jar
# wget https://downloads.mariadb.com/Connectors/java/connector-java-2.5.4/mariadb-java-client-2.5.4.jar

cp mariadb-java-client-2.5.4.jar /opt/hive/lib/
cp mariadb-java-client-2.5.4-javadoc.jar /opt/hive/lib/
cp mariadb-java-client-2.5.4-sources.jar /opt/hive/lib/


cp  /opt/hive/conf/hive-site.xml  /opt/spark/conf/

schematool -dbType mysql -initSchema
schematool -dbType mysql -info

nohup hive --service metastore &> /home/hdfs/log &

======================
hive

CREATE DATABASE qwerty;

create table qwerty.orders (
  order_id int,
  order_date string,
  order_customer_id int,
  order_status string
) row format delimited fields terminated by ','
stored as textfile;

load data inpath '/public/retail_db/orders/part-00000' into table qwerty.orders;

