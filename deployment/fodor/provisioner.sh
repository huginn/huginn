fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab

sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf

apt-get install -y runit build-essential git zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils pkg-config cmake nodejs graphviz nginx python-software-properties

apt-add-repository ppa:brightbox/ruby-ng
apt-get update
apt-get -y install ruby2.2 ruby2.2-dev

sudo update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby2.2 400 \
 --slave /usr/bin/rake rake /usr/bin/rake2.2 \
 --slave /usr/bin/ri ri /usr/bin/ri2.2 \
 --slave /usr/bin/rdoc rdoc /usr/bin/rdoc2.2 \
 --slave /usr/bin/irb irb /usr/bin/irb2.2 \
 --slave /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby2.2.1.gz \
 --slave /usr/share/man/man1/rake.1.gz rake.1.gz /usr/share/man/man1/rake2.2.1.gz \
 --slave /usr/share/man/man1/ri.1.gz ri.1.gz /usr/share/man/man1/ri2.2.1.gz \
 --slave /usr/share/man/man1/rdoc.1.gz rdoc.1.gz /usr/share/man/man1/rdoc2.2.1.gz \
 --slave /usr/share/man/man1/gem.1.gz gem.1.gz /usr/share/man/man1/gem2.2.1.gz \
 --slave /usr/share/man/man1/irb.1.gz irb.1.gz /usr/share/man/man1/irb2.2.1.gz

update-alternatives --install /usr/bin/gem gem /usr/bin/gem2.2 400

yes | gem install rake bundler foreman --no-ri --no-rdoc

adduser --disabled-login --gecos 'Huginn' huginn

debconf-set-selections <<< 'mysql-server mysql-server/root_password password mysqlsecretpassword'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password mysqlsecretpassword'

apt-get install -y mysql-server mysql-client libmysqlclient-dev

mysql -uroot -pmysqlsecretpassword -e "CREATE USER 'huginn'@'localhost' IDENTIFIED BY 'huginn';"
mysql -uroot -pmysqlsecretpassword -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES ON \`huginn_production\`.* TO 'huginn'@'localhost';"


# We'll install Huginn into the home directory of the user "huginn"
cd /home/huginn

# Clone Huginn repository
sudo -u huginn -H git clone https://github.com/cantino/huginn.git -b master huginn

# Go to Huginn installation folder
cd /home/huginn/huginn

# Copy the example Huginn config
sudo -u huginn -H cp .env.example .env

# Create the log/, tmp/pids/ and tmp/sockets/ directories
sudo -u huginn mkdir -p log tmp/pids tmp/sockets

# Make sure Huginn can write to the log/ and tmp/ directories
sudo chown -R huginn log/ tmp/
sudo chmod -R u+rwX,go-w log/ tmp/

# Make sure permissions are set correctly
sudo chmod -R u+rwX,go-w log/
sudo chmod -R u+rwX tmp/
sudo -u huginn -H chmod o-rwx .env

# Copy the example Unicorn config
sudo -u huginn -H cp config/unicorn.rb.example config/unicorn.rb

sed -i -e 's/DATABASE_NAME=huginn_development/DATABASE_NAME=huginn_production/g' .env
sed -i -e 's/DATABASE_USERNAME=root/DATABASE_USERNAME=huginn/g' .env
sed -i -e 's/DATABASE_PASSWORD=""/DATABASE_PASSWORD="huginn"/g' .env
sed -i -e 's/# RAILS_ENV=production/RAILS_ENV=production/g' .env

sudo -u huginn -H bundle install --deployment --without development test

SECRET=`bundle exec rake secret`

sed -i -e "s/REPLACE_ME_NOW\!/${SECRET}/g" .env

# Create the database
sudo -u huginn -H bundle exec rake db:create RAILS_ENV=production

# Migrate to the latest version
sudo -u huginn -H bundle exec rake db:migrate RAILS_ENV=production

# Create admin user and example agents using the default admin/password login
sudo -u huginn -H bundle exec rake db:seed RAILS_ENV=production SEED_USERNAME=huginn SEED_PASSWORD=huginn123

sudo -u huginn -H bundle exec rake assets:precompile RAILS_ENV=production

sed -i -e 's/^web:/#web:/g' -e 's/^jobs/#jobs/g' Procfile

echo "web: bundle exec unicorn -c config/unicorn.rb" >> Procfile
echo "jobs: bundle exec rails runner bin/threaded.rb" >> Procfile

sudo bundle exec rake production:export
cp deployment/logrotate/huginn /etc/logrotate.d/huginn

cp deployment/nginx/huginn /etc/nginx/sites-available/huginn
ln -s /etc/nginx/sites-available/huginn /etc/nginx/sites-enabled/huginn
rm /etc/nginx/sites-enabled/default

sed -i -e "s/YOUR_SERVER_FQDN/${DOMAIN}/g" /etc/nginx/sites-available/huginn

service nginx restart

