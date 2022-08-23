The `vmcp` web application is an XProc pipeline, which is hosted by a Java web Servlet called XProc-Z, which in turn is hosted in Apache Tomcat. The web application also uses an instance of Apache Solr as a search engine. 

# Install and configure Solr

Solr should be installed as a single server (i.e. not the cloud configuration) and configured to have a single database ("core") for each distinct instance of the web application. In this document the core is called "vmcp".

Download Solr 7 from https://dlcdn.apache.org/lucene/solr/8.11.2/solr-8.11.2.tgz

Extract the install script from the tarball, and run it. This installs Solr as a service.

```bash
tar -xvf solr-8.11.2.tgz
sudo solr-8.11.2/bin/install_solr_service.sh solr-8.11.2.tgz 
```

Then create the Solr "core" (database), here called "vmcp"

```bash
cd /opt/solr/
sudo -u solr bin/solr create -c vmcp
```

# Install Apache Tomcat

Install Tomcat using the OS package repository.

# Install the `vmcp` XProc pipeline

Use `git clone` to install the application directly from the github repository, into a file system location owned by the Tomcat user, e.g. `/etc/xproc-z/`.

```bash
git clone https://github.com/Conal-Tuohy/vmcp.git
```

This will create a folder called `vmcp` containing the XProc application. The main pipeline is defined in the file `xproc-z.xpl`, within the `xproc` subfolder. 

# Install and configure XProc-Z

Download XProc-Z from https://github.com/Conal-Tuohy/XProc-Z/releases/download/1.5.2/xproc-z.war and save in a location owned by the Tomcat user, e.g. `/etc/xproc-z`

Install the XProc-Z servlet by creating a [Tomcat "context" file](https://tomcat.apache.org/tomcat-9.0-doc/config/context.html), as described in Tomcat's documentation. To make this the "default" web application (i.e. so that it can be accessed with a base URL of `/`), name the context file `ROOT.xml`.

This context file specifies the location of the XProc-Z web archive file, and two parameters:
* `xproc-z.main` tells XProc-Z where to find the file containing the XProc pipeline which it should use to handle HTTP requests.
* `solr-base-uri` tells that pipeline the address of the Solr instance to use to index the TEI corpus. Note that the final component of the Solr base URI is the name of the Solr core, as defined above.

```xml
<Context path=""
    docBase="/etc/xproc-z/xproc-z.war"
    preemptiveAuthentication="true"
    antiResourceLocking="false">
  <Valve className="org.apache.catalina.authenticator.BasicAuthenticator" />
  <Parameter name="xproc-z.main" override="false"
             value="/etc/xproc-z/vmcp/xproc-z.xpl"/>
  <!-- the Solr base URL includes the core name (here "vmcp") -->
  <Parameter name="solr-base-uri" value="http://localhost:8983/solr/vmcp/"/>
</Context>
```

# Loading the TEI XML

To complete the installation, follow the instructions for [updating data](Updating-data.md).