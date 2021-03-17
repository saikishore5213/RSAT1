set TestCertPath=%1
set TestCertPassword=%2
ECHO Install the CloudCtu test certificate.
set MyStoreInstallCmd="&{$pfxcert = new-object system.security.cryptography.x509certificates.x509certificate2;$pfxcert.Import('%TestCertPath%', '%TestCertPassword%', 'Exportable,PersistKeySet');$store = new-object System.Security.Cryptography.X509Certificates.X509Store('My','LocalMachine');$store.open('MaxAllowed');$store.Add($pfxcert)}"
ECHO CALL powershell -command %MyStoreInstallCmd%
CALL powershell -command %MyStoreInstallCmd%