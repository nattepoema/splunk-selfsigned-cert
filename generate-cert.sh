######
# Set Variables
export SPLUNK_HOME=/opt/splunk
export SPLUNK_APP=LogObserverCertificates
export CERTS_PREFIX=mgmtPort
export SPLUNK_SERVER_FQDN=ENTER YOUR SERVER NAME HERE
######
# Apply Prefix
export myCAPrivateKey=${CERTS_PREFIX}PrivateKey.key
export myCACertificateCsr=${CERTS_PREFIX}CACertificate.csr
export myCACertificatePem=${CERTS_PREFIX}CACertificate.pem
export mySplunkWebPrivateKey=${CERTS_PREFIX}SplunkWebPrivateKey.key
export mySplunkWebCertCsr=${CERTS_PREFIX}SplunkWebCert.csr
export mySplunkWebCertPem=${CERTS_PREFIX}SplunkWebCert.pem
export mySplunkWebCertificatePem=${CERTS_PREFIX}SplunkWebCertificate.pem
export myFinalCertPem=${CERTS_PREFIX}FinalCert.pem
######

######
# Begin
mkdir -p ${SPLUNK_HOME}/etc/apps/${SPLUNK_APP}/default
mkdir -p ${SPLUNK_HOME}/etc/apps/${SPLUNK_APP}/auth
cd ${SPLUNK_HOME}/etc/apps/${SPLUNK_APP}/auth

#######
# Generate a new root certificate to be your Certificate Authority
# … Private RSA Key (the root certificate private key)

$SPLUNK_HOME/bin/splunk cmd openssl genrsa -aes256 -out $myCAPrivateKey 2048

#######
# Generate a certificate signing request

$SPLUNK_HOME/bin/splunk cmd openssl req -new -key $myCAPrivateKey -out $myCACertificateCsr

#######
# Use the CSR file to generate a new root certificate and sign it with your private key
# Script used DNS.  IP: is an alternative. 
# https://www.openssl.org/docs/man1.1.1/man5/x509v3_config.html  (search alternative name)

echo -e "# ssl-extensions-x509.cnf\n[v3_ca]\nbasicConstraints = CA:FALSE\nkeyUsage = digitalSignature, keyEncipherment\nsubjectAltName = DNS:${SPLUNK_SERVER_FQDN}" > ssl-extensions-x509.cnf

$SPLUNK_HOME/bin/splunk cmd openssl x509 -req -in $myCACertificateCsr -signkey $myCAPrivateKey -extensions v3_ca -extfile ./ssl-extensions-x509.cnf -out $myCACertificatePem -days 3650

#######
## Create a new private key

$SPLUNK_HOME/bin/splunk cmd openssl genrsa -aes256 -out $mySplunkWebPrivateKey 2048

#######
# Remove the password from your key

$SPLUNK_HOME/bin/splunk cmd openssl rsa -in $mySplunkWebPrivateKey -out $mySplunkWebPrivateKey

#######
# Verify password was removed
$SPLUNK_HOME/bin/splunk cmd openssl rsa -in $mySplunkWebPrivateKey -text

#######
## Create and sign a server certificate

$SPLUNK_HOME/bin/splunk cmd openssl req -new  -key $mySplunkWebPrivateKey -out $mySplunkWebCertCsr

#######
# Sign the CSR with the root certificate private key $myCAPrivateKey - This is your server certificate.

$SPLUNK_HOME/bin/splunk cmd openssl x509 -req -in $mySplunkWebCertCsr -CA $myCACertificatePem -extensions v3_ca -extfile ./ssl-extensions-x509.cnf -CAkey $myCAPrivateKey -CAcreateserial -out $mySplunkWebCertPem -days 1095

#######
# Combine the server certificate and public certificates
cat $mySplunkWebCertPem $myCACertificatePem > $mySplunkWebCertificatePem
cat $mySplunkWebCertificatePem $mySplunkWebPrivateKey > $myFinalCertPem

######
# Create Splunk server.conf configuration file
cd ${SPLUNK_HOME}/etc/apps/${SPLUNK_APP}/default
cat <<_EOT_ >./server.conf
[sslConfig]
serverCert=\$SPLUNK_HOME/etc/apps/${SPLUNK_APP}/auth/${myFinalCertPem}
requireClientCert=false
_EOT_

exit 0
#
