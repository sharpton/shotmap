Cloud (remote) Users (Advanced)
-------------------------------

Some additional options must be set to run shotmap on a remote, SGE configured distributed computing cluster (invoked using --remote):

1. You must set up passphrase-less SSH to your computational cluster. In this example, the cluster should have a name like "compute.cluster.university.edu". Follow the links at "https://www.google.com/search?q=passphraseless+ssh" in order to find some solutions for setting this up.

2. Cluster configuration file: you will need point shotmap to a file that contains a SGE submission script configuration header (using --cluster-config=<path_to_cluster_configuration_file>). These configurations are often system specific; you may need to consult with the system administrator. See data/cluster_config.txt for an example.

3. Ensure that gene prediction and search algorithms being invoked by shotmap are installed and accessible via the $PATH environmental variable on the remote machine.

4. Remote options: Invoke and properly set the following remote options (see below for details): --remote, --rhost, --rdir
