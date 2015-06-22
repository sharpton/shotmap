Installing ShotMAP
==================

There are two general approaches to installing shotMAP:

A. Clone the github repository and run the installer script
B. Install the shotMAP virtual machine (in development)

A. Github Installation
----------------------

 1. clone the github repository

git clone https://github.com/sharpton/shotmap.git

 2. set the SHOTMAP_LOCAL environmental variable

echo 'export SHOTMAP_LOCAL=<path_to_local_shotmap>' >> ~/.bash_profile
source ~/.bash_profile

 3. run the installer script

cd $SHOTMAP_LOCAL
perl install.pl

 4. set a few extra environmental variables

echo 'export PYTHONPATH=${PYTHONPATH}:${SHOTMAP_LOCAL}/pkg//MicrobeCensus/' >> ~/.bash_profile
echo 'export PATH=$PATH:${SHOTMAP_LOCAL}/pkg//MicrobeCensus/scripts/' >> ~/.bash_profile
echo 'export PATH=$PATH:${SHOTMAP_LOCAL}/bin/' >> ~/.bash_profile
echo 'export PERL5LIB=${PERL5LIB}:${SHOTMAP_LOCAL}/lib:${SHOTMAP_LOCAL}/ext/lib' >> ~/.bash_profile

 5. Notes

The Perl module XML::Parser require the Expat XML Parser C library to be accessible on your system. 
If you receive errors with XML::Parser, please have your system administrator install the expat
libraries. This is relatively straight forward via apt:

apt-get install libexpat1-dev



