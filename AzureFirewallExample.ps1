# https://learn.microsoft.com/en-us/azure/firewall/deploy-ps

# Create variables
$global:location = 'AustraliaSouthEast'
$global:rgName = 'Test-FW-RG'

# Create a resource group
New-AzResourceGroup -Name $rgName -Location $location

# Create a virtual network with 3 subnets (bastion, firewall, workload)
$global:bastionsub = new-azvirtualnetworksubnetconfig -name AzureBastionSubnet -addressprefix 10.0.0.0/27
$global:fwsub = new-azvirtualnetworksubnetconfig -name AzureFirewallSubnet -addressprefix 10.0.1.0/26
$global:worksub = new-azvirtualnetworksubnetconfig -name workload-sn -addressprefix 10.0.2.0/24
$global:testVnet = New-AzVirtualNetwork -Name Test-FW-VN -ResourceGroupName $rgName -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $Bastionsub, $FWsub, $Worksub

# Create public ip for Azure Bastion host
$global:publicip = New-AzPublicIpAddress -ResourceGroupName $rgName -Location $location -Name Bastion-pip -AllocationMethod static -Sku standard

# Create Azure Bastion host
New-AzBastion -ResourceGroupName $rgName -Name Bastion-01 -PublicIpAddress $publicip -VirtualNetwork $testVnet

# Create the NIC for a workload VM
$global:wsn = Get-AzVirtualNetworkSubnetConfig -Name  Workload-SN -VirtualNetwork $testvnet
$global:NIC01 = New-AzNetworkInterface -Name Srv-Work -ResourceGroupName $rgName -Location $location -Subnet $wsn

# Define the workload VM
$global:VirtualMachine = New-AzVMConfig -VMName Srv-Work -VMSize "Standard_B2s"
$global:VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC01.Id
$global:VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest
[string]$userName = 'azureuser' 
[string]$userPassword = 'JaDSwZ8LmWvdR@V'
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
$global:VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName Srv-Work -ProvisionVMAgent -EnableAutoUpdate -Credential $credObject

# Create the workload VM
New-AzVM -ResourceGroupName $rgName -Location $location -VM $VirtualMachine -Verbose

# Create a Public IP for the firewall
$global:FWpip = New-AzPublicIpAddress -Name "fw-pip" -ResourceGroupName $rgName -Location $location -AllocationMethod Static -Sku Standard

# Create the firewall
$global:Azfw = New-AzFirewall -Name Test-FW01 -ResourceGroupName $rgName -Location $location -VirtualNetwork $testVnet -PublicIpAddress $FWpip

#Save the firewall private IP address for future use
$global:AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress
$global:AzfwPrivateIP

# Create a table, with BGP route propagation disabled
$global:routeTableDG = New-AzRouteTable -Name Firewall-rt-table -ResourceGroupName $rgName -location $location -DisableBgpRoutePropagation

# Create a route
Add-AzRouteConfig -Name "DG-Route" -RouteTable $routeTableDG -AddressPrefix 0.0.0.0/0 -NextHopType "VirtualAppliance" -NextHopIpAddress $AzfwPrivateIP | Set-AzRouteTable

# Associate the route table to the subnet
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $testVnet -Name Workload-SN -AddressPrefix 10.0.2.0/24 -RouteTable $routeTableDG | Set-AzVirtualNetwork

# Configure an application rule (allow outbound access to www.google.com)
$global:AppRule1 = New-AzFirewallApplicationRule -Name Allow-Google -SourceAddress 10.0.2.0/24 -Protocol http, https -TargetFqdn www.google.com
$global:AppRuleCollection = New-AzFirewallApplicationRuleCollection -Name App-Coll01 -Priority 200 -ActionType Allow -Rule $AppRule1
$Azfw.ApplicationRuleCollections.Add($AppRuleCollection)
Set-AzFirewall -AzureFirewall $Azfw

# Configure a network rule (allow outbound access to two IP addresses at port 53 (DNS))
$global:NetRule1 = New-AzFirewallNetworkRule -Name "Allow-DNS" -Protocol UDP -SourceAddress 10.0.2.0/24 -DestinationAddress 209.244.0.3,209.244.0.4 -DestinationPort 53
$global:NetRuleCollection = New-AzFirewallNetworkRuleCollection -Name RCNet01 -Priority 200 -Rule $NetRule1 -ActionType "Allow"
$Azfw.NetworkRuleCollections.Add($NetRuleCollection)
Set-AzFirewall -AzureFirewall $Azfw

# Change the DNS address for the Srv-Work network interface
$NIC01.DnsSettings.DnsServers.Add("209.244.0.3")
$NIC01.DnsSettings.DnsServers.Add("209.244.0.4")
$global:NIC01 | Set-AzNetworkInterface

# Test the firewall
# ... connect to Srv-Work virtual machine using Bastion and do some manual testing of the firewall rules

# Clean up resources
#Remove-AzResourceGroup -Name $rgName
