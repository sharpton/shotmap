MySQL (db) Users (Advanced)
---------------------------

Some additional configurations must be set up to interface shotmap with a MySQL database, which can be invoked using the --db option. Most users won't need to worry about this.

1. MySQL is installed on the database server, which need not be the machine shotmap is being run on.

2. The user has CREATE, INSERT, DROP, SELECT, and FILE privileges. Also, the user must be able to write to /tmp/ so that data can be loaded infile (this results in *massive* speed-ups).

3. DB options: Invoke and properly set the following db opions (see below for details): --db, --dbuser, --dbhost, --dbpass, --dbname
