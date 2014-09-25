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
cd to a directory on your path. 
```
curl -o deploy.sh https://raw.githubusercontent.com/jonananas/jboss-deploy-latest/master/deploy.sh
```

## Usage
`deploy.sh dev` updates your application to the latest maven-deployed version in your development environment. 
Run deploy.sh without parameters to see:
```
deploy.sh [-f] [-p <jboss-cli password>] [dev|test|prod]
-f              Force deploy, even if no current artifact can be found
-p <password>   Use password for jboss-cli
```
# pom.xml
pom.xml contains the needed setup for versioning and downloading jboss-cli.
