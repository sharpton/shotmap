Installing ShotMAP
==================

There are two general approaches to installing shotMAP:
* Clone the github repository and run the installer script
* Install the ShotMAP virtual machine

A. Github Installation
----------------------

1. Clone the github repository

        git clone https://github.com/sharpton/shotmap.git

2. Set the SHOTMAP_LOCAL environmental variable. This should point your github-checked-out copy of shotmap. 
Ideally, you set this variable in your ~/.bash_profile (or ~/.profile) so that you don't have to 
set the variable everytime you run shotmap. You might try the following, which will attempt to set
$SHOTMAP_LOCAL to your system environment when you log in:

        echo 'export SHOTMAP_LOCAL=<path_to_local_shotmap>' >> ~/.bash_profile
        source ~/.bash_profile

3. Run the installer script, which is located in the top level of the shotmap repository (install.pl).

        cd $SHOTMAP_LOCAL
        perl install.pl > install.log 2> install.err

    This script attempts to auto install all of the requirements and dependencies used by shotmap. 
It does so by downloading source files via the internet (so you must have an internet connection for this to work!) 
and building binaries on your server. Note that this is challenging to automate, and you may still have to install 
some software by hand. 

    This software will take some time to run and will generate a lot of output. I recommend storing the output in a file 
(like install.log in the above command) so that you can review the results of the installation process.

4. Set a few extra environmental variables. ShotMAP and its dependences reference these variables.

        echo 'export PYTHONPATH=${PYTHONPATH}:${SHOTMAP_LOCAL}/pkg//MicrobeCensus/' >> ~/.bash_profile
        echo 'export PATH=$PATH:${SHOTMAP_LOCAL}/pkg//MicrobeCensus/scripts/' >> ~/.bash_profile
        echo 'export PATH=$PATH:${SHOTMAP_LOCAL}/bin/' >> ~/.bash_profile
        echo 'export PERL5LIB=${PERL5LIB}:${SHOTMAP_LOCAL}/lib:${SHOTMAP_LOCAL}/ext/lib' >> ~/.bash_profile

5. Notes

    The Perl module XML::Parser require the Expat XML Parser C library to be accessible on your system. 
If you receive errors with XML::Parser, please have your system administrator install the expat
libraries. This is relatively straight forward via 

        apt-get install libexpat1-dev

B. ShotMAP Virtual Machine
--------------------------

If you are running a windows or mac os x machine, then the use of a Virtual Machine (VM) 
may make installation a bit simple. In short, a VM allows you to run a linux server within
your windows or mac (or linux) environment. Installation is relatively straightforward, but 
this feature is new, so please bare with us.

1. Download the latest version of VirtualBox. This is the software you need to run the VM.

   [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)

2. Download the 64-bit ShotMAP VM, which you will run within VirtualBox to access a linux
environment (specifically, Ubuntu 14.04.2 LTS) that has ShotMAP preinstalled. 

    [ShotMAP VM version 0.3](http://files.cgrb.oregonstate.edu/Sharpton_Lab/ShotMAP/ShotMAP_VM/ShotMAP_VM_v0.3%20Clone.vdi.gz)

3. Unzip the file you downloaded

4. Create a new VM:
*Launch VirtualBox and press the "New" button create a new machine.
*In the new window that pops up, type ShotMAP as the name for the virtual machine, select Linux as the Operating System, and Ubuntu (64 bit) as the version. Click "Next".
*Select the amount of RAM you will need. A minimum of 4 Gb is recommended, but you may need more depending on your data. Click "Next".
*Select “Use existing hard drive”. Browse to and select the unzipped ShotMAP VM you downloaded (the .vdi file). Click "Next".
*Click "Finish".
*Double click on the new VM that was created within VirtualBox. This will boot an ubuntu environment.
*Open a Terminal window (you may need to search for 'Terminal' using the topmost icon in the sidebar).

5. Run Shotmap. Go to the following path in your Ubuntu VM to access ShotMAP:


        cd ~/src/shotmap


    You can now implement all ShotMAP features as indicated in the documentation.

6. Let us know where things go wrong. As noted above, this is a new feature and we'll need your input to ensure this resource works as intended on a diverse population of machines.
