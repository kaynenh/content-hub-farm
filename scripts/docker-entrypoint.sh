#!/bin/bash

profile="standard"
site_admin="admin"
site_password="admin"
site_mail="test@test.com"

# If the site is not persistent then delete it and start over.
if [ ${PERSISTENT} = false ]; then
  chmod -R 777 /var/www/html/web/sites/${HOSTNAME}
  rm -Rf /var/www/html/web/sites/${HOSTNAME}
fi

# Verifying if site is installed.
FILE=/var/www/html/web/sites/${HOSTNAME}/settings.php
echo "Checking file: ${FILE}"
if [ -f "$FILE" ]; then
  echo "Site ${HOSTNAME} is already installed."
else
  echo "Installing Drupal for site ${HOSTNAME}."
  # Give everything back to nginx user
  mkdir /var/www/html/web/sites/${HOSTNAME}
  chmod -R 777 /var/www/html/web/sites/${HOSTNAME}
  chown -R nginx:nginx /var/www/html/web/sites/${HOSTNAME}

  cd /var/www/html/web
  mkdir -p ./sites/${HOSTNAME}/files
  cp /var/www/html/web/sites/default/default.settings.php ./sites/${HOSTNAME}/settings.php
  chmod 777 ./sites/${HOSTNAME}/settings.php

  # Site installation.
  ../vendor/drush/drush/drush si -y $profile install_configure_form.enable_update_status_emails=NULL -y --account-name=${site_admin} --account-pass=${site_password} --account-mail=${site_mail} --site-mail=${site_mail} --site-name=${HOSTNAME} --sites-subdir=${HOSTNAME} --db-url=mysql://root:db@localhost:3306/db
  DRUSH="/var/www/html/vendor/bin/drush -l ${HOSTNAME}"
  echo "Done."

  # Enable shared contrib modules.
  echo "Enabling shared contributed modules..."
  $DRUSH pm-enable -y admin_toolbar \
    admin_toolbar_tools \
    devel \
    environment_indicator
  echo "Done."

  # Customize site according to site role.
  case ${SITE_ROLE} in
  'publisher')
    /usr/local/bin/publisher_install.sh
    ;;
  'subscriber')
    /usr/local/bin/subscriber_install.sh
    ;;
  esac

  # Run any related updates and share status
  # echo "Running database updates..."
  # $DRUSH updatedb
  # $DRUSH updatedb-status
  # echo "Done."

  # Disable aggregation and rebuild cache (helps with non-port/hostname alignment issues)
  echo "Setting up variables."
  $DRUSH -y config-set system.performance js.preprocess 0
  $DRUSH -y config-set system.performance css.preprocess 0
  $DRUSH cr
  echo "Done."
fi