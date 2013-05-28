Make sure you have Vagrant and Virtualbox(Not necessary, if deploying to AWS) installed.
Install librarian-chef gem

    gem install librarian-chef

And Vagrant plugins

    vagrant plugin install vagrant-aws
    vagrant plugin install vagrant-omnibus

Move to `/deployment` and run

    librarian-chef install

This will install all the cookbooks mentioned in Cheffile.

To install Huginn on AWS, fill the Vagrantfile with your account details and run

    vagrant up ec2 --provider=aws

To install it on a virtualbox VM:

    vagrant up vb

It'll install huginn and get the server started. You can now go to `yourserver.com/3000` to use huginn if you are in virtualbox. On ec2, pointing to public DNS will let you access huginn. Huginn will be at `/home/huginn/huginn`. A new dedicated user will be created for managing huginn with username `huginn` and password `huginn`. To ssh into ec2: 

    vagrant ssh ec2

Similarly, to ssh into VirtualBox

    vagrant ssh vb
    
After ssh-ing into ec2, you can start(its already running), stop or restart huginn by
    
    sudo start huginn
    sudo stop huginn
    sudo restart huginn

To terminate ec2 instance:

    vagrant destroy ec2

Similarly, to destroy VirtualBox VM

    vagrant destroy vb
