#!/bin/bash

test "$JBOSS_HOME" == "" && { echo "JBOSS_HOME not set, need it to find jboss-cli.sh, example: export JBOSS_HOME=~/jboss-7" >&2; exit 255; }
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
	echo "Usage: deploy.sh [-f] [-p <jboss-cli password>] [localhost|dev|test|prod|<hostname>|upgrade]"
	echo "upgrade         Will fetch the latest version of deploy.sh from github"
        echo "-f              Force deploy, even if no current artifact can be found"
	echo "-p <password>   Use password for jboss-cli"
}

# Parse cmdline
while getopts ":fp:" opt; do
	case $opt in
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

case $1 in
localhost)
	hostname=localhost
	;;
dev)
	hostname=$HOSTNAME_DEV
	;;
test)
	hostname=$HOSTNAME_TEST
	;;
prod)
	hostname=$HOSTNAME_PROD
	;;
upgrade)
	curl -o deploy.sh https://raw.githubusercontent.com/jonananas/jboss-deploy-latest/master/deploy.sh
	echo "deploy.sh has been updated"
	exit 0
	;;
*)
	if [[ "$1" == "" ]]; then usage; exit 255; fi
	hostname=$1
	echo "Target hostname: $hostname"
	;;
esac

# Find latest version
latest_version=`curl http://$MAVENREPO/$ARTIFACT_PATH/$ARTIFACT_ID/ 2>/dev/null| egrep $ARTIFACT_ID | tail -1 | sed "s/.*$ARTIFACT_ID\/\(.*\)\/\".*/\1/"`
latest_war=$ARTIFACT_ID-$latest_version.$ARTIFACT_EXT
#if [[ "$latest_version" != [0-9]\.[0-9]\.[0-9]\-[0-9]+ ]]; then
if [[ "$latest_version" != [0-9]\.[0-9]\.[0-9]\-[0-9]* ]]; then
	echo "Failed finding latest version, was $latest_version"
	exit 1
fi
echo "Latest version at $MAVENREPO is $latest_war"

# Retrieve password from user
if [[ "$PASSWORD" = "" ]]; then
	read -s -p "Enter $hostname jboss-cli password:" PASSWORD
	echo ""
fi

# Find deployed version
deployed_version=`/bin/sh $JBOSS_HOME/bin/jboss-cli.sh --connect --controller="$hostname" --command="ls deployment" --user=admin --password=$PASSWORD |grep $ARTIFACT_ID`
if [[ "$deployed_version" != $ARTIFACT_ID-[0-9]\.[0-9]\.[0-9]\-[0-9]*\.$ARTIFACT_EXT ]]; then
	echo "Failed finding deployed version, was $deployed_version"
	test "$forceDeploy" == "deploy" || exit 1
fi
echo "Deployed version at $hostname is $deployed_version"

# Undeploy current version and deploy latest
if [ "$deployed_version" == "$latest_war" ]; then
	echo "Latest version is already deployed"
	exit 0
else
	curl "http://$MAVENREPO/$ARTIFACT_PATH/$ARTIFACT_ID/$latest_version/$latest_war" > /tmp/$latest_war
	echo "Updating $hostname to $latest_war, when done list of deploys will appear"
	commands="undeploy $deployed_version, deploy /tmp/$latest_war, ls deployment"
	/bin/sh $JBOSS_HOME/bin/jboss-cli.sh --connect --controller="$hostname" --user=admin --password=$PASSWORD --commands="$commands"
	if [ $? -eq 0 ]; then 
		echo -- Deploy succeeded --
	else
		echo -- Deploy failed --
	fi
	rm /tmp/$latest_war
fi
