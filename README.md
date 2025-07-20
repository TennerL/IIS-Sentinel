# IIS-Sentinel
## Configuration ##

By executing ScanWebsite.ps1 you create a JSON of all active Websites running on your IIS-Webserver. 
This must be done firstly. You can modify the .JSON afterwards.

Set a daily scheduled Task of "ExecuteAll.ps1" after adding your Vulners and AbudeIPDb API-Keys to 
AnalyzeIISLogs.ps1 and DepVulns.ps1 

You can decide by yourself how often you want the Server checked for software vulnerabilitys 
by setting a scheduled task for DepVulns.ps1 accordingly.

![alt text](/screenshot.png)
