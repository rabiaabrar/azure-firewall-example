# Azure firewall example
This is the code from an [Azure Firewall example](https://learn.microsoft.com/en-us/azure/firewall/deploy-ps) that I did while doing an [Intro to Azure course](https://www.coursera.org/learn/cloud-azure-intro/home/welcome).

## AzureFirewallExample.ps1
I put all the code from the example into a .ps1 file. 
The file can be run on the whole, but I ran it by uncommenting it in batches while I worked through the example.

I made the following modifications to the provided code:

- Make all variables global, so that they persist in a powershell session when I run the file again and again.
- Create variables for Location and Resource Group.
- Change location to SouthEastAustralia.
- Fix the invocation of `Set-AzVMOperatingSystem` to include hardcoded Credentials.

## Cleanup
To cleanup, just remove the whole resource group. There is a commented out line at the end of AzureFirewallExample.ps1 to do this.

## Set-AzVMOperatingSystem bug
There is a bug in `Set-AzVMOperatingSystem` that if you don't provide Credentials, it throws a null reference error instead of asking for them. I reported it [here](https://github.com/Azure/azure-powershell/issues/22956).

