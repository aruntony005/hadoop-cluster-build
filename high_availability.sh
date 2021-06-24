######################## High Availability ######################
# https://www.edureka.co/blog/how-to-set-up-hadoop-cluster-with-hdfs-high-availability/
# test1 -> namenode 1, journalnode
# test2 -> namenode 2, journalnode
# test3 -> datanode, journalnode
# cluster nameservice -> ha-cluster

## On all the nodes

wget https://archive.apache.org/dist/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz
tar –xvf zookeeper-3.4.6.tar.gz
mv /opt/zookeeper-3.4.6.tar.gz /opt/zookeeper
export ZOOKEEPER_HOME =/opt/zookeeper

cat >> .bashrc << EOF
export ZOOKEEPER_HOME =/opt/zookeeper
export PATH=\$PATH:/opt/zookeeper/bin
EOF

## Enable passwordless ssh to all the nodes from the namenodes

sed -i '/\/configuration/d' /opt/hadoop/etc/hadoop/core-site.xml

cat >> /opt/hadoop/etc/hadoop/core-site.xml << EOF
        <property>
            <name>dfs.journalnode.edits.dir</name>
            <value>/opt/data/jn</value>
         </property>
</configuration>
EOF

sed -i '/\/configuration/d' /opt/hadoop/etc/hadoop/hdfs-site.xml

cat >> /opt/hadoop/etc/hadoop/hdfs-site.xml << EOF
<configuration>
 <property>
 <name>dfs.permissions</name>
 <value>false</value>
 </property>
 <property>
 <name>dfs.nameservices</name>
 <value>ha-cluster</value>
 </property>
 <property>
 <name>dfs.ha.namenodes.ha-cluster</name>
 <value>test1,test2</value>
 </property>
 <property>
 <name>dfs.namenode.rpc-address.ha-cluster.test1</name>
 <value>test1.cluster.com:9000</value>
 </property>
 <property>
 <name>dfs.namenode.rpc-address.ha-cluster.test2</name>
 <value>test2.cluster.com:9000</value>
 </property>
 <property>
 <name>dfs.namenode.http-address.ha-cluster.test1</name>
 <value>test1.cluster.com:50070</value>
 </property>
 <property>
 <name>dfs.namenode.http-address.ha-cluster.test2</name>
 <value>test2.cluster.com:50070</value>
 </property>
 <property>
 <name>dfs.namenode.shared.edits.dir</name>
 <value>qjournal://test1.cluster.com:8485;test2.cluster.com:8485;test3.cluster.com:8485/ha-cluster</value>
 </property>
 <property>
 <name>dfs.client.failover.proxy.provider.ha-cluster</name>
 <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
 </property>
 <property>
 <name>dfs.ha.automatic-failover.enabled</name>
 <value>true</value>
 </property>
 <property>
 <name>ha.zookeeper.quorum</name>
 <value> test1.cluster.com:2181,test2.cluster.com:2181,test3.cluster.com:2181 </value>
 </property>
 <property>
 <name>dfs.ha.fencing.methods</name>
 <value>sshfence</value>
 </property>
 <property>
 <name>dfs.ha.fencing.ssh.private-key-files</name>
 <value>/home/hdfs/.ssh/id_rsa</value>
 </property>
</configuration>
EOF

mv /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg
mkdir -p /opt/data/zookeeper

echo "dataDir=/opt/data/zookeeper
Server.1=test1.cluster.com:2888:3888
Server.2=test2.cluster.com:2888:3888
Server.3=test3.cluster.com:2888:3888" >> /opt/zookeeper/conf/zoo.cfg

# These /opt/hadoop folder hsould be present in all the nodes, zookeeper folder should be present in all the quorum nodes
# In the datanodes dfs.datanode.data.dir should also be present.

# In Active namenode
echo 1 > /opt/data/zookeeper/myid

# In standby node namenode
echo 2 > /opt/data/zookeeper/myid

# Start the journalnode daemon in all the journal nodes
hadoop-daemon.sh start journalnode

# Now if jps is executed we will see journalnode daemon

# After this run namenode format command
hdfs namenode -format

# Now start the namenode daemon in the active namenode
hadoop-daemon.sh start namenode

# In the standby namenode execute the below command. This command copies the metadata from active namenode to standby namenode.

hdfs namenode -bootstrapStandby

# Now start the namenode daemon in the standby namenode
hadoop-daemon.sh start namenode

# Now start the zookeeper service in all the three journal nodes
zkServer.sh start

# Now when jps is run we will see the QuorumPeerMain service.
# Now start the datanode daemon in the datanodes
hadoop-daemon.sh start datanode

# Format the zookeeper failover controller in the active namenode
hdfs zkfc –formatZK

# Start ZKFC in the  active namenode
hadoop-daemon.sh start zkfc

# Format the zookeeper failover controller in the standby namenode
hdfs zkfc –formatZK

# Start ZKFC in the standby namenode
hadoop-daemon.sh start zkfc

# Now execute jps to see DFSZkFailoverController daemons.
# Now execute the below command in both the namenodes to know which node is active and which is standby.
hdfs haadmin –getServiceState test1
hdfs haadmin –getServiceState test2
