automated-backup
================

Usage and intention of this project is explained in this [blog post](http://blog.synyx.de/2013/04/continuous-deployment-automatic-backup-script/)

Because every manual step implies a risk for failure, our goal is to minimize such risks as well as our amount of work by automating our processes of software delivery. In several of our applications we already use a deployment script for automatic deployment of Tomcat applications. For some applications we even use a continuous deployment script triggered by crontab (e.g. every hour) to check if Nexus has a new version of the application and if so to fetch and deploy it automatically.
However the backup process was still manual - although you always perform the same steps what is a perfect opportunity for automation. And a perfect opportunity for me to leave the Java world for a while and to learn more about shell scripting.

The typical backup steps before a deployment are:
* saving war file resp. information about the current deployed version
* saving database data in a dump
* saving directories and/or files, e.g. log files, generated error reports, etc.
