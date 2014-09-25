jboss-deploy-latest
===================

Script and pom for deploying latest maven artefact to jboss using jboss-cli

# deploy.sh
deploy.sh finds the latest artefact, using major.minor.patch-revision as version. If a newer version than is deployed
exists it is deployed using jboss-cli.

## Usage
Run deploy.sh without parameters to see:
```
deploy.sh [-f] [-p <jboss-cli password>] [dev|test|prod]
-f              Force deploy, even if no current artifact can be found
-p <password>   Use password for jboss-cli
```
# pom.xml
pom.xml contains the needed setup for versioning and downloading jboss-cli.
