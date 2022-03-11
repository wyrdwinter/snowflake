# ----------------------------------------------------------------------------- #
#
# Copyright (C) 2022 Wyrd (https://github.com/wyrdwinter)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------------- #

$script = <<-'SCRIPT'

dnf -y install gcc-toolset-11
dnf -y install nginx
dnf -y module install nodejs:16
dnf -y module install redis:6

cp /home/vagrant/snowflake/src/config/nginx.conf /etc/nginx/nginx.conf
setsebool -P httpd_can_network_connect on
systemctl enable nginx.service
systemctl start nginx.service

sed -i 's/appendonly no/appendonly yes/g' /etc/redis.conf
systemctl enable redis.service
systemctl start redis.service

curl https://nim-lang.org/download/nim-1.6.2-linux_x64.tar.xz > nim-1.6.2-linux_x64.tar.xz
tar -xf nim-1.6.2-linux_x64.tar.xz
rm nim-1.6.2-linux_x64.tar.xz
cd nim-1.6.2
./install.sh /usr/local/bin
cp bin/* /usr/local/bin
chmod 755 /usr/local/bin/atlas
chmod 755 /usr/local/bin/nim
chmod 755 /usr/local/bin/nimble
chmod 755 /usr/local/bin/nim_dbg
chmod 755 /usr/local/bin/nim-gdb
chmod 755 /usr/local/bin/nimgrep
chmod 755 /usr/local/bin/nimpretty
chmod 755 /usr/local/bin/nimsuggest
chmod 755 /usr/local/bin/testament
cd ..
rm -rf nim-1.6.2

SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "almalinux/8"
  config.vm.box_version = "8.5.20211208"
  
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 4
  end

  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.synced_folder "./", "/home/vagrant/snowflake"
  config.vm.provision "shell", inline: $script
end
