# FreeBSD Greenbone Security Assistant

This shell script installs Greenbone Security Assistant (formerly OpenVAS) on
a freshly installed FreeBSD system. This script has been tested on FreeBSD 
13.1 GENERIC STABLE.

## Network configuration

Installation is done via binary packages. If you are operating behind a proxy
server, be advised that the Greenbone Security Assistant requires rsync to
update exploit checks (NVTs) and system-related code; without those updates,
the system will not work.

## Preinstalled packages

The installation script assumes to be run on a freshly installed system, but
attempts to skip steps if it detects already pre-installed packages. However,
testing was primarily focused on a new system (or jail). Hence, if you find
any problems, please let me know.

## Credentials

Upon starting the installation script, you are asked for password credentials
to use during the installation. If you do not enter anything, the script will
generate random secrets, which will be printed on screen at the end of the
execution.

The most important passphrase in this context is the "WEB user admin", which
you will need to log in at Greenbone Security Assistant's web interface.

## Web Interface

Once the script completes, Greenbone Security Assistant will be up and running
on your host's IP address on port 80 and 443. You can then open a web browser
and reach the web interface at

https://&lt;ip-address&gt;/

## Certificates

The installation script creates a self signed certificate for the HTTP server.
If you prefer to use your own certificate, please replace the files at
/var/lib/gvm/CA/servercert.pem and /var/lib/gvm/private/CA/serverkey.pem.

