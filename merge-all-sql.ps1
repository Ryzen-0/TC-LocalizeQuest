$PSDefaultParameterValues['*:Encoding'] = 'utf8'; # no need for PowerShell 7+

Get-ChildItem -Recurse -Path . -Filter *-gtranslate.sql | Get-Content | Add-Content "itIT-gtranslate.sql";
Get-ChildItem -Recurse -Path . -Filter *-it.sql | Get-Content | Add-Content "itIT.sql";
