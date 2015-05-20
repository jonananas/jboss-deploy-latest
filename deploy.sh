#!/bin/bash

test "$JBOSS_HOME" == "" && { echo "JBOSS_HOME not set, need it to find jboss-cli.sh, example: export JBOSS_HOME=~/jboss-7" >&2; exit 255; }
if [ -f ~/.deploy.cfg ]; then 
	source ~/.deploy.cfg
	echo Downloading global ~/.deploy.cfg from $DEPLOY_REPO
	(cd ~; git archive --remote=$DEPLOY_REPO HEAD .deploy.cfg|tar -x )
	source ~/.deploy.cfg
else
	echo "Create ~/.deploy.cfg to use global.cfg, example line:"
	echo DEPLOY_REPO=ssh://git@stash.dev.company.se:7999/MCONF/deploy.git
fi
source ./deploy.cfg

function checkConfig {
	eval param=\$$1
	test "$param" == "" && { echo "$1 not set, please edit deploy.cfg" >&2; exit 255; }
}

checkConfig ARTIFACT_ID
checkConfig MAVENREPO
checkConfig ARTIFACT_PATH
checkConfig HOSTNAME_DEV
checkConfig HOSTNAME_TEST
checkConfig HOSTNAME_PROD

function usage {
	echo "Usage: deploy.sh [-f] [-p <jboss-cli password>] [-l <directory>] [localhost|dev [idx]|test [idx]|prod [idx]|upgrade]"
	echo "idx             Index starting with 0 if dev/test/prod host is comma-separated list, default is 0"
	echo "upgrade         Will fetch the latest version of deploy.sh from github. DO NOT USE WITH HOMEBREW!"
	echo "-f              Force deploy, even if no current artifact can be found"
	echo "-l <dir>        Find latest version in directory instead of nexus"
	echo "-p <password>   Use password for jboss-cli"
}

# Parse cmdline
while getopts ":fp:l:" opt; do
	case $opt in
		l)
			local_dir=$OPTARG
		;;
		f)
			forceDeploy=deploy
		;;
		p)
			PASSWORD=$OPTARG
		;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
		;;
	esac
done
shift $(($OPTIND-1))

function set_hostname {
	IFS=', ' read -a hosts <<< "$1"
        hostidx=0
        [[ "$2" =~ [0-9] ]] && hostidx=$2
        (( $hostidx >= ${#hosts[@]} )) && { echo "Invalid hostidx $hostidx in $1"; exit 255; }
        hostname="${hosts[hostidx]}"
}

case $1 in
localhost)
	hostname=localhost
	;;
dev)
	set_hostname $HOSTNAME_DEV $2
	;;
test)
	set_hostname $HOSTNAME_TEST $2
	;;
prod)
	set_hostname $HOSTNAME_PROD $2
	;;
upgrade)
	DIR="$( cd "$( dirname "$0" )" && pwd )"
	DEPLOY_SH=$DIR/deploy.sh
	curl -o $DEPLOY_SH https://raw.githubusercontent.com/jonananas/jboss-deploy-latest/master/deploy.sh
	echo "$DEPLOY_SH has been updated"
	exit 0
	;;
*)
	usage
        exit 255
	;;
esac

# Find latest version
if [ "$local_dir" != "" ]; then
	local_file=`ls -1 $local_dir/$ARTIFACT_ID-[0-9]\.[0-9]\.[0-9]*.$ARTIFACT_EXT`
	echo "Latest version at $local_dir is $local_file"
else
	latest_version=`curl http://$MAVENREPO/$ARTIFACT_PATH/$ARTIFACT_ID/ 2>/dev/null| egrep $ARTIFACT_ID | sed "s/.*$ARTIFACT_ID\/\(.*\)\/\".*/\1/" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1`
	latest_war=$ARTIFACT_ID-$latest_version.$ARTIFACT_EXT
	if [[ ! "$latest_version" =~ [0-9]+\.[0-9]+\.[0-9]+(\-[0-9]+|\-SNAPSHOT)? ]]; then
		echo "Failed finding latest version, was $latest_version"
		exit 1
	fi
	echo "Latest version at $MAVENREPO is $latest_war"
fi

# Retrieve password from user
if [[ "$PASSWORD" = "" ]]; then
	read -s -p "Enter $hostname jboss-cli password:" PASSWORD
	echo ""
fi

# Find deployed version
deployed_version=`/bin/sh $JBOSS_HOME/bin/jboss-cli.sh --connect --controller="$hostname" --command="ls deployment" --user=admin --password=$PASSWORD |grep $ARTIFACT_ID`
if [[ ! "$deployed_version" =~ $ARTIFACT_ID-[0-9]+\.[0-9]+\.[0-9]+(\-[0-9]+|\-SNAPSHOT)?\.$ARTIFACT_EXT ]]; then
	echo "Failed finding deployed version, was $deployed_version"
	test "$forceDeploy" == "deploy" || exit 1
fi
echo "Deployed version at $hostname is $deployed_version"


function deploy {
	deployable=$1
	echo "Deploying $deployable onto $hostname, when done list of deploys will appear"
	commands="undeploy $deployed_version, deploy $deployable, ls deployment"
	/bin/sh $JBOSS_HOME/bin/jboss-cli.sh --connect --controller="$hostname" --user=admin --password=$PASSWORD --commands="$commands"
	if [ $? -eq 0 ]; then 
		echo -- Deploy succeeded --
	else
		echo -- Deploy failed --
	fi
}

# Undeploy current version and deploy latest
if [ "$local_file" != "" ]; then
	deploy $local_file
elif [ "$deployed_version" == "$latest_war" ]; then
	echo "Latest version is already deployed"
	exit 0
else
	curl "http://$MAVENREPO/$ARTIFACT_PATH/$ARTIFACT_ID/$latest_version/$latest_war" > /tmp/$latest_war
	deploy /tmp/$latest_war
	rm /tmp/$latest_war
fi
