dim filesys, scriptsdir, installationpath, runpath 
Set filesys = CreateObject("Scripting.FileSystemObject")
scriptsdir = filesys.GetParentFolderName(WScript.ScriptFullName)
installationpath = filesys.GetParentFolderName(scriptsdir)
runpath = filesys.BuildPath(installationpath, "Microsoft.Dynamics.RegressionSuite.WpfApp.exe")
Set oShell = CreateObject("Shell.Application")
oShell.ShellExecute runpath, , , "runas", 1