# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.omnibus.chef_version = :latest

  config.vm.provision :chef_solo do |chef|
    chef.roles_path = "roles"
    chef.cookbooks_path = ["cookbooks", "site-cookbooks"]
    chef.add_role("huginn_development")
    # chef.add_role("huginn_production")
  end

  config.vm.provider :virtualbox do |vb, override|
    #vb.memory = 1024
    #vb.cpus = 4
    override.vm.box = "hashicorp/precise64"
    override.vm.network :forwarded_port, host: 3000, guest: 3000
  end

  config.vm.provider :parallels do |prl, override|
    override.vm.box = "parallels/ubuntu-12.04"
  end

  config.vm.provider :aws do |aws, override|
    aws.ami = ENV['AWS_AMI'] || "ami-828675f5"
    aws.region = ENV['AWS_REGION'] || "eu-west-1"
    aws.instance_type = "t1.micro"

    override.vm.box = "dummy"
    override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    override.ssh.private_key_path = ENV["AWS_SSH_PRIVKEY"]
    override.ssh.username = ENV['AWS_SSH_USER'] || "ubuntu"

    aws.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
    aws.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
    aws.keypair_name = ENV["AWS_KEYPAIR_NAME"]
    aws.security_groups = [ ENV["AWS_SECURITY_GROUP"] ]
  end
end
