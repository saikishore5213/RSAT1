setx testroot "%DeploymentDirectory%"
ECHO Installing D365 prerequisites

ECHO MSIEXEC /a %DeploymentDirectory%\msodbcsql /passive /norestart IACCEPTMSODBCSQLLICENSETERMS=YES
MSIEXEC /a %DeploymentDirectory%\msodbcsql /passive /norestart IACCEPTMSODBCSQLLICENSETERMS=YES

%windir%\sysnative\windowspowershell\v1.0\powershell.exe -File %DeploymentDirectory%\install-wif.ps1
Md %DeploymentDirectory%\Common\Team\Foundation\Performance\Framework
%DeploymentDirectory%\CloudCtuFakeACSInstall.cmd %DeploymentDirectory%\KeyVaultCert.pfx