@IF NOT DEFINED _echo @ECHO OFF

SET InstallingAssembly=%1
SET ExtDir=

for /F "eol=! tokens=2*" %%I IN ('reg query HKEY_CURRENT_USER\Software\Microsoft\VisualStudio\12.0\ExtensionManager\EnabledExtensions /v "InternalDevTools..3c8f6a79-1ed0-4f7c-b3af-11852696c5fd,1.0"') do set ExtDir=%%J

if exist "%ExtDir%extension.vsixmanifest" (
  pushd "%ExtDir%AddinExtensions"
  echo.
  echo.
  echo "Copying %InstallingAssembly% to Dynamics internal addins folder %ExtDir%AddinExtensions."
  echo.
  call xcopy /q /y %InstallingAssembly% .
  echo.
  popd
) else (
  echo "Dynamics AX7 internal developer tools not installed.
  echo.
)