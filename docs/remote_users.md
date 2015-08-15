Cloud (remote) Users (Advanced)
-------------------------------

Some additional options must be set to run shotmap on a remote, SGE configured distributed computing cluster (invoked using --remote):

1. You must set up passphrase-less SSH to your computational cluster. In this example, the cluster should have a name like "compute.cluster.university.edu". Follow the links at "https://www.google.com/search?q=passphraseless+ssh" in order to find some solutions for setting this up.

2. Cluster configuration file: you will need point shotmap to a file that contains a SGE submission script configuration header by using the --cluster-config option. A cluster configuration file essentially contains the header information that you would include in a SGE or PBS submission script that is run on your high performance computing cluster. These configurations are often system specific; you may need to consult with the system administrator. See [here](../data/cluster_config.txt) for an example.

3. Ensure that gene prediction and search algorithms being invoked by shotmap are installed and accessible via the $PATH environmental variable on the remote machine.

4. Remote options: Invoke and properly set the following remote options (see below for details): --remote, --rhost, --rdir, --stage

Note that --stage need not be invoked everytime you run shotmap on your remote cluster.

