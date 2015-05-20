jboss-deploy-latest
===================

Script and pom for deploying latest maven artefact to jboss using jboss-cli

# deploy.sh
deploy.sh finds the latest artefact, using major.minor.patch-revision as version. If a newer version than is deployed
exists it is deployed using jboss-cli.

## Installing
With homebrew:
```
brew tap jonananas/j
brew install jboss-deploy-latest
rehash
```

With curl:
```
cd <to a directory on your path>
curl -o deploy.sh https://raw.githubusercontent.com/jonananas/jboss-deploy-latest/master/deploy.sh
```
You can then get the latest version by running `deploy.sh upgrade`.

## Usage
`deploy.sh dev` updates your application to the latest maven-deployed version in your development environment. 
Run deploy.sh without parameters to see:
```
deploy.sh [-f] [-p <jboss-cli password>] [dev|test|prod]
-f              Force deploy, even if no current artifact can be found
-p <password>   Use password for jboss-cli
```

## Configuration
Put project specific configuration in each project root, see example file deploy.cfg
You may create a global config, only git repos are supported at the moment. Add ~/.deploy.sh with the line (edit to point to your repo):
DEPLOY_REPO=ssh://git@stash.dev.company.se:7999/MCONF/deploy.git

# pom.xml
pom.xml contains the needed setup for versioning and downloading jboss-cli.
