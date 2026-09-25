' Starts the tray host with no visible window at all (powershell.exe -WindowStyle
' Hidden alone still flashes a console for a moment; running it via wscript with
' window style 0 doesn't).
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\tray.ps1""", 0, False
