#!/bin/bash

set -e

declare -r SCRIPTDIR="$(readlink -f "$(dirname "$0")")"
source "$SCRIPTDIR/util.sh"

echo "[DCUI-Setup] Setting up Datacube UI..."

echo "[DCUI-Setup] Cloning repository of Datacube UI..."
git clone --recurse-submodules https://github.com/ceos-seo/data_cube_ui -b master "$DCUBE_HOME/data_cube_ui"

echo "[DCUI-Setup] Asking if patching is required..."
echo "Should the patches in '$PATCHDIR' be applied? [Y/n] "
read shall_patch
case "$shall_patch" in
    y|Y|'')
        echo "[DCUI-Setup] Patching Datacube UI..."
        pushd "$DCUBE_HOME/data_cube_ui"

        for patch in "${PATCHDIR}/"*.patch; do
            echo "[DCUI-Setup] Checking if patch '$patch' can be applied..."
            git apply --stat "$patch"
            git apply --check "$patch"
            echo "[DCUI-Setup] Applying patch '$patch'..."
            git apply "$patch"
            echo "[DCUI-Setup] Patch '$patch' successfully applied."
        done

        popd
        ;;
    *)
        echo "[DCUI-Setup] Skipping application of patches..."
        ;;
esac
unset shall_patch

echo "[DCUI-Setup] Installing required packages from Debian repository..."
declare -ar PACKAGES=(
apache2
redis-server
libfreeimage3
imagemagick
)

sudo apt install --assume-yes "${PACKAGES[@]}"

echo "[DCUI-Setup] Installing required python packages into conda environment..."
declare -ar PYTHON_PACKAGES=(
django
redis
imageio
django-bootstrap3
matplotlib
celery
pip
)

conda install --name "$CUBEENV" --yes "${PYTHON_PACKAGES[@]}"

_activate

# packages stringcase and mod_wsgi are not available via conda, so we fall
# back to the pip *inside* our conda environment
pip install stringcase


# install mod_wsgi into conda environment
echo "[DCUI-Setup] Installing mod_wsgi in conda environment..."
sudo apt install --assume-yes apache2-dev build-essential
pip install mod_wsgi
sudo "$(which mod_wsgi-express)" install-module | sed -n '/LoadModule/p' | sudo tee /etc/apache2/mods-available/wsgi.load
_exsed --in-place 's,(WSGIPythonHome ).*,\1'"$CONDA_PREFIX"',' "${CONFDIR}/wsgi.conf"
_exsed --in-place 's,(WSGIPythonPath ).*,\1'"${CONDA_PREFIX}/lib/python3.6/site-packages"',' "${CONFDIR}/wsgi.conf"
sudo install -vDm644 "${CONFDIR}/wsgi.conf" /etc/apache2/mods-available/wsgi.conf

_deactivate

mkdir -pv "${DATA_HOME}/ui_results"


echo "[DCUI-SETUP] Configuring Django..."
declare DJANGO_SETTINGS="${DCUBE_HOME}/data_cube_ui/data_cube_ui/settings.py"
# configure ADMIN_EMAIL
echo "Please enter the admin email address to use: "
read admin_email
_exsed --in-place "s/^(ADMIN_EMAIL = )/\1'"\
    "$(echo "$admin_email" | _sedescape)"\
    "'/" "$DJANGO_SETTINGS"
# configure LOCAL_USER
_exsed --in-place "s/^(LOCAL_USER = )/\1'"\
    "$(echo "$USER" | _sedescape)"\
    "'/" "$DJANGO_SETTINGS"
# configure RESULTS_DATA_DIR
_exsed --in-place "s/^(RESULTS_DATA_DIR = )/\1'"\
    "$(echo "$DATA_HOME/ui_results" | _sedescape)"\
    "'/" "$DJANGO_SETTINGS"
# configure DATABASES (using configuration from $HOME/.datacube.conf)
_exsed --in-place "s/^(\s*'USER': ?).*$/\1'"\
    "$(_exsed --quiet "s/^db_username: (.*)$/\1/p" "$HOME/.datacube.conf" | _sedescape)"\
    "'/" "$DJANGO_SETTINGS"
_exsed --in-place "s/^(\s*'PASSWORD': ?).*$/\1'"\
    "$(_exsed --quiet "s/^db_password: (.*)$/\1/p" "$HOME/.datacube.conf" | _sedescape)"\
    "'/" "$DJANGO_SETTINGS"
# configure TIME_ZONE (using timedatectl or /etc/timezone)
if which timedatectl > /dev/null; then
    _exsed --in-place "s/^(TIME_ZONE = )/\1'"\
        "$(timedatectl | _exsed --quiet "s%\s+Time zone: ([A-Z][a-z]*/[A-Z][a-z]*)\s.*%'\1'%p" | _sedescape)"\
        "'/" "$DJANGO_SETTINGS"
elif [[ -e "/etc/timezone" ]]; then
    _exsed --in-place "s/^(TIME_ZONE = )/\1'"\
        "$(cat /etc/timezone | _sedescape)"\
        "'/" "$DJANGO_SETTINGS"
fi


echo "[DCUI-SETUP] Installing Postfix..."
# TODO: automate interactive setup of postfix
sudo apt install --assume-yes postfix mailutils
sudo systemctl stop postfix.service

echo "[DCUI-SETUP] Configuring Postfix..."
sudo _backup /etc/postfix/main.cf
sudo _exsed --in-place 's/(inet_interfaces = ).*/\1localhost/' /etc/postfix/main.cf
sudo systemctl start postfix.service

echo "[DCUI-SETUP] Configuring Apache Web Server..."
echo "Please enter the value for ServerName (i.e. the domain name): "
read server_name
sudo cat > /etc/apache2/sites-available/dc_ui.conf <<APACHECONF
<VirtualHost *:80>
    # Admin email, Server Name (domain name) and any aliases
    ServerAdmin ${admin_email}
    ServerName ${server_name:-$HOST}

	WSGIDaemonProcess dc_ui python-path=${DCUBE_HOME}/data_cube_ui
	WSGIProcessGroup dc_ui
	WSGIApplicationGroup %{GLOBAL}

	WSGIScriptAlias / ${DCUBE_HOME}/data_cube_ui/data_cube_ui/wsgi.py

	<Directory "${DCUBE_HOME}/data_cube_ui/data_cube_ui/">
		<Files wsgi.py>
			Require all granted
		</Files>
	</Directory>

	#django static
	Alias /static/ ${DCUBE_HOME}/data_cube_ui/static/
	<Directory ${DCUBE_HOME}/data_cube_ui/static>
		Require all granted
	</Directory>

	#results.
	Alias /datacube/ ${DATA_HOME}/
	<Directory ${DATA_HOME}/>
		Require all granted
	</Directory>

	# enable compression
	SetOutputFilter DEFLATE

	ErrorLog \${APACHE_LOG_DIR}/datacube-error.log
	CustomLog \${APACHE_LOG_DIR}/datacube-access.log combined

</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
APACHECONF

# unset variables not used anymore
unset admin_email
unset server_name

# deactivating default site and activating the datacube ui
sudo a2enmod wsgi
sudo a2dissite 000-default.conf
sudo a2ensite dc_ui.conf
sudo systemctl restart apache2.service

echo "[DCUI-Setup] Finished scripted setup."
echo "[DCUI-Setup] Although the script configured Django, there are still some"
echo "[DCUI-Setup] steps to executed manually. Check correctness of the Django configuration"
echo "[DCUI-Setup] in '${DCUBE_HOME}/data_cube_ui/data_cube_ui/settings.py' and then"
echo "[DCUI-Setup] follow the steps outlined in https://github.com/ceos-seo/data_cube_ui/blob/master/docs/ui_install.md#database_initialization to initialize Django"
echo "[DCUI-Setup]"
echo "[DCUI-Setup] Currently, libpng in the conda environment is linked to zlib 1.2.9, "
echo "[DCUI-Setup] but conda has only versions 1.2.8, 1.2.10 and 1.2.11 available."
echo "[DCUI-Setup] For now, a dirty fix is to download the source of zlib 1.2.9, compile"
echo "[DCUI-Setup] it and install it with 'sudo make install' into '/usr/local/'."
