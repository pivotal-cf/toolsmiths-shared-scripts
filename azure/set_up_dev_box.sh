#!/bin/bash

cd ~
echo "Start to update package lists from repositories..."
apt-get update

echo "Start to update install prerequisites..."
apt-get install -y build-essential ruby2.0 ruby2.0-dev libxml2-dev libsqlite3-dev libxslt1-dev libpq-dev libmysqlclient-dev zlibc zlib1g-dev openssl libxslt-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev sqlite3 libffi-dev

rm /usr/bin/ruby /usr/bin/gem /usr/bin/irb /usr/bin/rdoc /usr/bin/erb
ln -s /usr/bin/ruby2.0 /usr/bin/ruby
ln -s /usr/bin/gem2.0 /usr/bin/gem
ln -s /usr/bin/irb2.0 /usr/bin/irb
ln -s /usr/bin/rdoc2.0 /usr/bin/rdoc
ln -s /usr/bin/erb2.0 /usr/bin/erb

gem update --system
gem pristine --all

echo "Start to install bosh_cli..."
gem install bosh_cli --no-ri --no-rdoc

echo "Start to install bosh-init..."
# Update bosh-init version to the latest version
wget –O bosh-init https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.94-linux-amd64
chmod +x ./bosh-init-*
sudo mv ./bosh-init-* /usr/local/bin/bosh-init

echo "Finish"
