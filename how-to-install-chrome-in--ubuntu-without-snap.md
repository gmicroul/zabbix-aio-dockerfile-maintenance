

Here are the steps to get this working for Ubuntu 22.04/24.04 based on the current accepted answer. 

    Remove chromium packages (regular and snap):

sudo apt remove chromium chromium-browser chromium-browser-l10n chromium-codecs-ffmpeg
sudo snap remove --purge chromium-browser
sudo snap remove --purge chromium

    Add older bullseye deb sources (see Ubuntu codenames here), by creating /etc/apt/sources.list.d/debian.list with contents:

deb http://deb.debian.org/debian bullseye main
deb http://deb.debian.org/debian bullseye-updates main
deb http://deb.debian.org/debian-security/ bullseye-security main

    Add the deb signing keys:

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 6ED0E7B82643E131
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 605C66F00D6C9793
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 0E98404D386FA1D9

    Configure apt pinning. Create a file /etc/apt/preferences.d/chromium.pref with the following content:

# Note: 2 blank lines are required between entries
Package: *
Pin: release a=eoan
Pin-Priority: 500

Package: *
Pin: origin "deb.debian.org"
Pin-Priority: 300

# Pattern includes 'chromium', 'chromium-browser' and similarly
# named dependencies:
Package: chromium*
Pin: origin "deb.debian.org"
Pin-Priority: 700

    Install Chromium again:

sudo apt update
sudo apt install chromium

    Test:

root@<host>:~# chromium --version
Chromium 120.0.6099.224 built on Debian 11.8, running on Debian bookworm/sid

# as another user
root@<host>:~# /bin/su - ubuntu
ubuntu@<host>:~$ chromium --version
Chromium 120.0.6099.224 built on Debian 11.8, running on Debian bookworm/sid

Note: This also works on AWS Graviton arm64 arch.
