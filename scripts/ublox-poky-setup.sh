#!/bin/bash
#
# ublox-poky-setup.sh -- u-blox poky setup and update script
#
# Copyright (C) 2014 Johan Hovold <johan@hovoldconsulting.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

UBLOX_GIT="git@github.com/u-blox"
UBLOX_GIT_PROTOCOL="ssh"

branch=daisy

rev_poky=daisy-11.0.1
rev_meta_openembedded=518cd119a8724dbd485a5d5c5047de59e8fbd652
rev_meta_ublox=elin-w16_v0.9.0.0
rev_meta_ublox_extras=elin-w16_v0.9.0.0

backup_suffix="backup-$(date +%F-%H%M%S)"

print_usage() {
	echo "Usage: `basename $0` [-f][-h]"
	echo
	echo "Setup or update u-blox meta layers and scripts."
	echo
	echo -e "\t-f\toverwrite any previous branch backups from today"
	echo -e "\t-h\tdisplay this help"
	echo
	echo "Note that current $branch branches will be renamed" \
			"$branch-$backup_suffix"
}

git_branch_mv="-m"

while getopts "fh" opt; do
	case $opt in
		f)
			git_branch_mv="-M"
			;;
		h)
			print_usage
			exit 0
			;;
		\?)
			print_usage
			exit 1
			;;
	esac
done

git_setup() {
	local url=$1
	local branch=$2
	local tag=$3
	local path=$(basename $url .git)

	if [ ! -d $path ]; then
		echo "Setting up $path"
		git clone --single-branch --branch $branch $url
		if [ $? -ne 0 ]; then
			echo "Single branch not supported"
			git clone --branch $branch $url
		fi
		cd $path
		git reset --hard $tag
	else
		echo "Updating $path"
		cd $path
		git fetch
		git branch $git_branch_mv $branch "$branch-$backup_suffix"
		git checkout -b $branch $tag
	fi

	cd ..
}

# poky
#
git_setup git://git.yoctoproject.org/poky.git $branch $rev_poky
cd poky

# meta-openembedded
#
git_setup git://git.openembedded.org/meta-openembedded $branch \
		$rev_meta_openembedded

# u-blox meta layers
#
git_setup $UBLOX_GIT_PROTOCOL://$UBLOX_GIT/meta-ublox.git $branch \
		$rev_meta_ublox
git_setup $UBLOX_GIT_PROTOCOL://$UBLOX_GIT/meta-ublox-extras.git $branch \
		$rev_meta_ublox_extras

# ublox-init-build-env
#
if [ ! -f ublox-init-build-env ]; then
	cat > ublox-init-build-env <<-EOF
	#!/bin/bash

	export TEMPLATECONF="meta-ublox-extras/conf"
	. "\`dirname \$BASH_SOURCE\`/oe-init-build-env" "\$1"

	export UBLOX_GIT="$UBLOX_GIT"
	export UBLOX_GIT_PROTOCOL="$UBLOX_GIT_PROTOCOL"
	export BB_ENV_EXTRAWHITE="\$BB_ENV_EXTRAWHITE UBLOX_GIT UBLOX_GIT_PROTOCOL"
EOF
	chmod a+x ublox-init-build-env
fi

cd ..
