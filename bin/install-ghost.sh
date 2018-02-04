# Create the databases that will be used in the tests
mysql -e "create database IF NOT EXISTS $DB_NAME;" -uroot

# Install Gulp CLI
npm install --global gulp-cli

# Download json parser for determining ngrok tunnel
wget https://stedolan.github.io/jq/download/linux64/jq
chmod +x jq

# Download ngrok and open tunnel to application
wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
unzip ngrok-stable-linux-amd64.zip
chmod +x ngrok
./ngrok authtoken $NGORK_AUTH

# Start ngrok and get URL
echo "13123123123"
./ngrok http 80 > /dev/null &
sleep 10
NGROK_URL_RAW=$(curl -s localhost:4040/api/tunnels/command_line | jq --raw-output .public_url)

echo NGROK_URL_RAW

$NGROKDOMAIN="${NGROK_URL_RAW##*/}"
$BASE_URL=http://
$NGROK_URL=$BASE_URL$NGROKDOMAIN
echo "13123123123"

# install WordPress in the `wordpress` folder
cd $WP_FOLDER
wp core download --version=$WP_VERSION
wp config create --dbname="$DB_NAME" --dbuser="root" --dbpass="" --dbhost="127.0.0.1" --dbprefix="$WP_TABLE_PREFIX"
wp core install --url="$NGROK_URL" --title="Test" --admin_user="admin" --admin_password="admin" --admin_email="admin@$NGROKDOMAIN" --skip-email
wp core update-db
wp option update home $NGROK_URL
wp option update siteurl $NGROK_URL

# Copy Caldera to NGROK accessible site
rsync -avzp --delete "$TRAVIS_BUILD_DIR/" "$WP_FOLDER/wp-content/plugins/caldera-forms" --exclude=".git"

# Git clone plugins
cd $WP_FOLDER
git clone https://github.com/CalderaWP/caldera-ghost-runner.git $WP_FOLDER/wp-content/plugins/caldera-ghost-runner
git clone https://github.com/calderawp/cf-connected-forms $WP_FOLDER/wp-content/plugins/cf-connected-forms
git clone https://gitlab.com/caldera-labs/cf-result-diff-plugin.git $WP_FOLDER/wp-content/plugins/cf-result-diff-plugin

# Setup and activate cf-result-diff if php7
# Install if php7
case "$TRAVIS_PHP_VERSION" in
  7.2|7.1|7.0|nightly)
    cd $WP_FOLDER/wp-content/plugins/cf-result-diff-plugin && composer install && composer update && cd $WP_FOLDER && wp plugin activate cf-result-diff-plugin
    ;;
  5.6|5.5|5.4|5.3)
    echo "PHP version does not support cf-result-diff"
    ;;
  5.2)
    echo "PHP version does not support cf-result-diff"
    ;;
  *)
    echo "PHP version does not support cf-result-diff"
    ;;
esac

# Setup caldera-ghost-runner and cf-connected-forms
cd $WP_FOLDER/wp-content/plugins/caldera-ghost-runner && composer clear-cache && composer install && composer update
cd $WP_FOLDER/wp-content/plugins/cf-connected-forms && composer install && composer update && npm install --silent && gulp

# Activate all downloaded plugins
cd $WP_FOLDER && wp plugin activate caldera-forms && wp plugin activate caldera-ghost-runner && wp plugin activate cf-connected-forms

# Copy NGINX config file, enables the site, and restart web server
cd $TRAVIS_BUILD_DIR
sudo cp bin/travis-nginx-conf /etc/nginx/sites-available/$NGROKDOMAIN
sudo sed -e "s?%WP_FOLDER%?$WP_FOLDER?g" --in-place /etc/nginx/sites-available/$NGROKDOMAIN
sudo sed -e "s?%NGROKDOMAIN%?$NGROKDOMAIN?g" --in-place /etc/nginx/sites-available/$NGROKDOMAIN
sudo ln -s /etc/nginx/sites-available/$NGROKDOMAIN /etc/nginx/sites-enabled/
sudo service php5-fpm restart
sudo service nginx restart

cd $WP_FOLDER && wp cgr import cd $TRAVIS_BUILD_DIR
exit 0