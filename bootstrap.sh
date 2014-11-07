## to use: idemp a && echo "a"
function idemp() {
    IDEMPDIR="$HOME/.idempotency"
    mkdir -p $IDEMPDIR
    FLAG="$IDEMPDIR/$1"
    if [ ! -f "$FLAG" ]; then
        touch "$FLAG"
        return 0
    else
        return 1
    fi
}

if idemp "firstrun"; then
  #set some default values for the mysql. user root, pw root
  echo "mysql-server-5.5 mysql-server/root_password password root" | debconf-set-selections
  echo "mysql-server-5.5 mysql-server/root_password_again password root" | debconf-set-selections

  export DEBIAN_FRONTEND=noninteractive
  apt-get update

  #standalone bc grub messed our stuff up
  apt-get -o Dpkg::Options::="--force-confnew" --force-yes -uy update

  apt-get install -y mysql-server php5-mysql php5-curl apache2 php5-dev php5-gd php5 libapache2-mod-php5 php-pear make git zip unzip
fi


# install drush

if idemp "drushsetup"; then
  PREV=`pwd`
  H=/home/vagrant
  mkdir $H/bin
  cd $H/bin
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar composer
  echo "PATH=\$PATH:~/bin:~/.composer/vendor/bin" >> $H/.bashrc
  su vagrant -c "$H/bin/composer global require drush/drush:dev-master"
  chown vagrant:vagrant $H -R
  cd $PREV
fi

#set up db initially

if idemp "databasesetup" ; then
    echo "CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY 'drupaluser'" | mysql --user=root --password=root
    echo "CREATE DATABASE camministorici" | mysql --user=root --password=root
    echo "GRANT ALL ON camministorici.* TO 'drupaluser'@'localhost' IDENTIFIED BY 'drupaluser'" | mysql --user=root --password=root
    echo "flush privileges" | mysql --user=root --password=root
fi

# symlinking our drupal directory
rm -rf /var/www/website
cp /vagrant/public /var/www/website -Rf
chown vagrant:vagrant /var/www/website -Rf

# check to see if the configuration is there
if [ ! -h /etc/apache2/sites-available/drupal ]; then
  # cahnge default port to 8081
  if [ ! -e /etc/apache2/ports.conf.bck ]; then
    sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.bck
    sed 's/Listen 80/Listen 8081/g' /etc/apache2/ports.conf.bck > /etc/apache2/ports.conf
  fi

  # copy the config file
  ln -sf /vagrant/drupal.conf /etc/apache2/sites-available/drupal.conf

  # enable apache modules
  a2enmod rewrite php5
  # disable the default site
  a2dissite 000-default
  # this comman makes the symlink in sites-enabled
  a2ensite drupal.conf
  # restart apache so we gotz the new setting
  service apache2 restart
fi
