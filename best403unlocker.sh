#!/usr/bin/env bash
DATABASE=best403unlocker_database_$(date +%s)
DATABASE_PATH=/tmp/$DATABASE
trap 'echo -e "\n";sudo cat /etc/resolv.conf.bakup > /etc/resolv.conf;rm /etc/resolv.conf.bakup; echo -e "/etc/resolv.conf is changed to default.\nExiting..."; exit' SIGINT
# Functions
check_run_with_root_accsses(){
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo)"
  exit 1
fi
}
install_required_packages(){
    if [[ -f /etc/os-release  ]]; then
        source /etc/os-release

        case $ID in
              debian|ubuntu|mint|elementary)
                apt update -y
                apt install -y "$1"
                ;;
              arch|manjaro|parch)
                pacman -Sy --noconfirm "$1"
                ;;
              fedora|rhel|centos|rocky|almalinux)
                dnf install -y "$1"
                ;;
              suse|opensuse)
                zypper install -y "$1"
                ;;
              alpine)
                apk update
                apk add --no-cache "$1"
                ;;
              *)
                echo "Unsupported OS. Please install ""$1"" manually." >& 2
                exit 1
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sudo -u "$(logname)" brew update
        sudo -u "$(logname)" brew install "$1"
    else
        echo "Unsupported OS. Please install ""$1"" manually." >& 2
        exit 1
    fi
}
check_required_packages_is_installed(){
PACKAGES="wget skopeo"
for package in $PACKAGES
do
       if ! [ -x "$(command -v "$package")" ]
then
    echo "$package is not installed"
    read -rp "Do you want to us install ""$package"" or cancel it? [Y/n]: " do_install
    
    if [[ -z $do_install ||
        $do_install == "Y" ||
        $do_install == "y" ||
        $do_install == "Yes" ||
        $do_install == "yes"
    ]]; then
      install_required_packages "$package"
    else
          echo "Please install $package manually" >& 2
          exit 1
    fi
fi
done
}
check_and_source_env() {
    if [ ! -f /etc/best403unlocker.conf ]; then
    wget -c https://raw.githubusercontent.com/403unlocker/best403unlocker/main/best403unlocker.conf -O /etc/best403unlocker.conf
 fi
source /etc/best403unlocker.conf
}

check_ip() {
    local input="$1"
    local regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

    if [[ $input =~ $regex ]]; then
            return 0
    else
            return 1
    fi
}

function change_dns () {

	echo 'nameserver'  "$1"> /etc/resolv.conf
	echo '############################'
	cat /etc/resolv.conf
	echo '$$$$$$$$$$$$$$$$$$$$$$$$$$$$'

}

function download() {
if [[ "$file_url" == docker://* ]]; then
    timeout "$timeout" skopeo copy "$file_url" dir:/tmp/"$1" > /dev/null 2>&1
else
    timeout "$timeout" wget -q -O /tmp/"$1"  --no-dns-cache "$file_url"
fi

}

function download_speed() {
du -s /tmp/"$1" >> "$DATABASE_PATH"
rm -rf /tmp/"$1"
}

loggin(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') "
    sed -i s/"\/tmp\/"//g "$DATABASE_PATH"
}


# Execute the functions
check_run_with_root_accsses
check_required_packages_is_installed
check_and_source_env
echo "analyzing ""$file_url"""
touch "$DATABASE_PATH"
cp /etc/resolv.conf /etc/resolv.conf.bakup
for i in $dns
do
	if check_ip "$i"; then
change_dns "$i"
download "$i"
download_speed "$i"
	fi
done
is_network_working=$( sort -rn "$DATABASE_PATH" | head -1|cut -d $'\t' -f1)

if [[ "$is_network_working" -eq 0 ]]; then
echo '*********************'
echo 'Network is not reachable'
echo '*********************'
else
echo '*********************'
echo best dns server is "$(sort -rn "$DATABASE_PATH"| head -1| cut -d'/' -f3)"
echo '*********************'
fi
loggin >> /var/log/best403unlocker.log
cat /etc/resolv.conf.bakup > /etc/resolv.conf
rm /etc/resolv.conf.bakup
