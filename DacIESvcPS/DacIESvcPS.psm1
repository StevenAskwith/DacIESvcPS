# DacIESvcPS Module
# Version 1
# Written by Steven Askwith
# stevenaskwith.com
# 23/03/2012

# =============================================================================
# Useage
# =============================================================================

<#
start-DacExport -s <server> -d <database> -u <username> -p <password> -bloburl <bloburl> -blobaccesskey <key>               
start-DacImport -s <server> -d <database> -u <username> -p <password> -bloburl <bloburl> -blobaccesskey <key> -size <inGB> -edition <web/business>
get-DacJobStatus -s <server> -u <username> -p <password> [-requestid <GUID> -withInfo]
#>

# =============================================================================
# Error Action
# =============================================================================

$ErrorActionPreference = "Stop"

# =============================================================================
# Assemblies
# =============================================================================

Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System

# =============================================================================
# Functions
# =============================================================================

function get-DacJobStatus
(
	[Parameter(Mandatory=$true)][alias("s")][String]$Server,
	[Parameter(Mandatory=$true)][alias("u")][String]$Username,
	[Parameter(Mandatory=$true)][alias("p")][String]$Password,
	[GUID]$requestid,
	[String]$datacenter = "",
	[switch]$withInfo = $false
)
{
	# Pick correct DataCenter if none was provided
	if ($datacenter -eq "")
	{
		$datacenter = get-DACDataCenter $Server
	}

	$Server =  		[System.Web.HttpUtility]::UrlEncode($Server)
	$Username =  	[System.Web.HttpUtility]::UrlEncode($Username)
	$Password =  	[System.Web.HttpUtility]::UrlEncode($Password)
	$GUID =  		[System.Web.HttpUtility]::UrlEncode($GUID)
	
	# Build a URI
	$requestUri = new-object Uri ("https://$datacenter/DACWebService.svc/Status?servername=$Server&username=$Username&password=$Password&reqId=$requestid")
	
	# Create the request and specify attributes of the request.
	$request = [System.Net.WebRequest]::Create($requestUri)
	
	# Define the requred headers
	$request.Method = "GET"
	$request.ContentType = "application/xml"
	
	# Fire Request
	$response = $request.GetResponse()
	
	# Output Response
	$responseStream = $response.GetResponseStream()
	$responseReader = New-Object System.IO.StreamReader $responseStream

	[xml]$jobStatusXML = $responseReader.ReadToEnd() 
	
	if($withInfo)
	{
		Write-Host $datacenter -ForegroundColor Magenta
		#$jobStatusXML.Save([Console]::Out)
		$jobStatusXML.ArrayOfStatusInfo.StatusInfo
		Write-Host 
	}
	if(!$withInfo)
	{
		return $jobStatusXML
	}
}

function start-DacExport
(
	[Parameter(Mandatory=$true)][alias("s")][String]$Server,
	[Parameter(Mandatory=$true)][alias("d")][String]$Database,
	[Parameter(Mandatory=$true)][alias("u")][String]$Username,
	[Parameter(Mandatory=$true)][alias("p")][String]$Password,
	[Parameter(Mandatory=$true)][String]$bloburl,
	[Parameter(Mandatory=$true)][String]$blobaccesskey,
	[String]$datacenter = "" 
)
{
	# Pick correct DataCenter if none was provided
	if ($datacenter -eq "")
	{
		$datacenter = get-DACDataCenter $Server
	}

	# Build a URI
	$requestUri = new-object Uri ("https://$datacenter/DACWebService.svc/Export")
	
	# Create the request and specify attributes of the request.
	$request = [System.Net.WebRequest]::Create($requestUri)
	
	# Define the requred headers
	$request.Method = "POST"
	$request.ContentType = "application/xml"
	
	# generate XML
	$PostXML = get-DACExportRequestXML -s $Server -d $Database -u $Username -p $Password -bloburl $bloburl -blobaccesskey $blobaccesskey
	
	# setup post
	$PostStr = [System.Text.Encoding]::UTF8.GetBytes($PostXML)
	#$PostStr | Out-Host
    $request.ContentLength = $PostStr.Length
    $request.ServicePoint.Expect100Continue = $false

	# Stream XML
	$requestStream = $request.GetRequestStream()
    $requestStream.Write($PostStr, 0,$PostStr.length)
    $requestStream.Close()
	
	# Fire Request
	$response = $request.GetResponse()
	
	# Output Response
	$responseStream = $response.GetResponseStream()
	$responseReader = New-Object System.IO.StreamReader $responseStream

	[xml]$returnedXML = $responseReader.ReadToEnd() 
	return $returnedXML.guid.innerxml
}

function start-DacImport
(
	[Parameter(Mandatory=$true)][alias("s")][String]$Server,
	[Parameter(Mandatory=$true)][alias("d")][String]$Database,
	[Parameter(Mandatory=$true)][alias("u")][String]$Username,
	[Parameter(Mandatory=$true)][alias("p")][String]$Password,
	[Parameter(Mandatory=$true)][String]$bloburl,
	[Parameter(Mandatory=$true)][String]$blobaccesskey,
	[Parameter(Mandatory=$true)][int]$size,
	[Parameter(Mandatory=$true)][String]$edition,
	[String]$datacenter = ""
)
{
	# Pick correct DataCenter if none was provided
	if ($datacenter -eq "")
	{
		$datacenter = get-DACDataCenter $Server
	}

	# Build a URI
	$requestUri = new-object Uri ("https://$datacenter/DACWebService.svc/Import")
	
	# Create the request and specify attributes of the request.
	$request = [System.Net.WebRequest]::Create($requestUri)
	
	# Define the requred headers
	$request.Method = "POST"
	$request.ContentType = "application/xml"
	
	# generate XML
	$PostXML = get-DACImportRequestXML -s $Server -d $Database -u $Username -p $Password -bloburl $bloburl -blobaccesskey $blobaccesskey -size $size -edition $edition
	
	# setup post
	$PostStr = [System.Text.Encoding]::UTF8.GetBytes($PostXML)
	#$PostStr | Out-Host
    $request.ContentLength = $PostStr.Length
    $request.ServicePoint.Expect100Continue = $false

	# Stream XML
	$requestStream = $request.GetRequestStream()
    $requestStream.Write($PostStr, 0,$PostStr.length)
    $requestStream.Close()
	
	# Fire Request
	$response = $request.GetResponse()
	
	# Output Response
	$responseStream = $response.GetResponseStream()
	$responseReader = New-Object System.IO.StreamReader $responseStream

	[xml]$returnedXML = $responseReader.ReadToEnd() 
	return $returnedXML.guid.innerxml
}

Function get-DACExportRequestXML
(
	[Parameter(Mandatory=$true)][alias("s")][String]$Server,
	[Parameter(Mandatory=$true)][alias("d")][String]$Database,
	[Parameter(Mandatory=$true)][alias("u")][String]$Username,
	[Parameter(Mandatory=$true)][alias("p")][String]$Password,
	[Parameter(Mandatory=$true)][String] $blobaccesskey, 
	[Parameter(Mandatory=$true)][String] $bloburl
)
{
	$xmlns = "http://schemas.datacontract.org/2004/07/Microsoft.SqlServer.Management.Dac.ServiceTypes"
	$xmlnsi = "http://www.w3.org/2001/XMLSchema-instance"
	$itype = "BlobStorageAccessKeyCredentials"

	# Creates the xml data object
	$xmlWrite = New-Object xml
	
	# Creates the 'Root' ExportInput xml element
	$rootElement = $xmlWrite.CreateElement("ExportInput")
		# Adds the root Element attributes
		$rootElement.SetAttribute("xmlns", $xmlns)	
	$xmlWrite.AppendChild($rootElement) | Out-Null
	
	# Creates the BlobCredentials xml element
	$blobElement = $xmlWrite.CreateElement("BlobCredentials")
		# Adds the BlobCredentials Element attributes
		$blobElement.SetAttribute("i:type", $itype)	
		$blobElement.SetAttribute("xmlns:i", $xmlnsi)
	$rootElement.AppendChild($blobElement) | Out-Null
	#Write-Host $xmlWrite.outerxml
	
	# Creates the Uri xml element
	$uriElement = $xmlWrite.CreateElement("Uri")
		$uriElement.PSBase.InnerText = $bloburl
	$blobElement.AppendChild($uriElement) | Out-Null	
	
	# Creates the StorageAccessKey xml element
	$stoKeyElement = $xmlWrite.CreateElement("StorageAccessKey")
		$stoKeyElement.PSBase.InnerText = $blobaccesskey
	$blobElement.AppendChild($stoKeyElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$conInfoElement = $xmlWrite.CreateElement("ConnectionInfo")
	$rootElement.AppendChild($conInfoElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$dbNameElement = $xmlWrite.CreateElement("DatabaseName")
		$dbNameElement.PSBase.InnerText = $Database
	$conInfoElement.AppendChild($dbNameElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$pwdElement = $xmlWrite.CreateElement("Password")
		$pwdElement.PSBase.InnerText = $Password
	$conInfoElement.AppendChild($pwdElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$serverNameElement = $xmlWrite.CreateElement("ServerName")
		$serverNameElement.PSBase.InnerText = $Server
	$conInfoElement.AppendChild($serverNameElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$userNameElement = $xmlWrite.CreateElement("UserName")
		$userNameElement.PSBase.InnerText = $Username
	$conInfoElement.AppendChild($userNameElement) | Out-Null
	
	# convert to serialized string
	$xmlWriteSerialized = $xmlWrite.OuterXML
	
	# fix for i:type
	$xmlWriteSerialized = $xmlWriteSerialized.Replace("BlobCredentials type=", "BlobCredentials i:type=")
	
	return $xmlWriteSerialized
}

Function get-DACImportRequestXML
(
	[Parameter(Mandatory=$true)][alias("s")][String]$Server,
	[Parameter(Mandatory=$true)][alias("d")][String]$Database,
	[Parameter(Mandatory=$true)][alias("u")][String]$Username,
	[Parameter(Mandatory=$true)][alias("p")][String]$Password,
	[Parameter(Mandatory=$true)][String] $blobaccesskey, 
	[Parameter(Mandatory=$true)][String] $bloburl,
	[String] $edition = $null,
	[int] $size = 0 
)
{
	$xmlns = "http://schemas.datacontract.org/2004/07/Microsoft.SqlServer.Management.Dac.ServiceTypes"
	$xmlnsi = "http://www.w3.org/2001/XMLSchema-instance"
	$itype = "BlobStorageAccessKeyCredentials"

	# Creates the xml data object
	$xmlWrite = New-Object xml
	
	# Creates the 'Root' ImportInput xml element
	$rootElement = $xmlWrite.CreateElement("ImportInput")
		# Adds the root Element attributes
		$rootElement.SetAttribute("xmlns", $xmlns)
		$rootElement.SetAttribute("xmlns:i", $xmlnsi)
	$xmlWrite.AppendChild($rootElement) | Out-Null
	
	# Creates the AzureEdition xml element
	$AzureEditionElement = $xmlWrite.CreateElement("AzureEdition")
		$AzureEditionElement.PSBase.InnerText = $edition
	$rootElement.AppendChild($AzureEditionElement) | Out-Null
	
	# Creates the BlobCredentials xml element
	$blobElement = $xmlWrite.CreateElement("BlobCredentials")
		# Adds the BlobCredentials Element attributes
		$blobElement.SetAttribute("i:type", $itype)	
	$rootElement.AppendChild($blobElement) | Out-Null
	#Write-Host $xmlWrite.outerxml
	
	# Creates the Uri xml element
	$uriElement = $xmlWrite.CreateElement("Uri")
		$uriElement.PSBase.InnerText = $bloburl
	$blobElement.AppendChild($uriElement) | Out-Null	
	
	# Creates the StorageAccessKey xml element
	$stoKeyElement = $xmlWrite.CreateElement("StorageAccessKey")
		$stoKeyElement.PSBase.InnerText = $blobaccesskey
	$blobElement.AppendChild($stoKeyElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$conInfoElement = $xmlWrite.CreateElement("ConnectionInfo")
	$rootElement.AppendChild($conInfoElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$dbNameElement = $xmlWrite.CreateElement("DatabaseName")
		$dbNameElement.PSBase.InnerText = $Database
	$conInfoElement.AppendChild($dbNameElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$pwdElement = $xmlWrite.CreateElement("Password")
		$pwdElement.PSBase.InnerText = $Password
	$conInfoElement.AppendChild($pwdElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$serverNameElement = $xmlWrite.CreateElement("ServerName")
		$serverNameElement.PSBase.InnerText = $Server
	$conInfoElement.AppendChild($serverNameElement) | Out-Null
	
	# Creates the ConnectionInfo xml element
	$userNameElement = $xmlWrite.CreateElement("UserName")
		$userNameElement.PSBase.InnerText = $Username
	$conInfoElement.AppendChild($userNameElement) | Out-Null
	
	# Creates the DatabaseSizeInGB xml element
	$DatabaseSizeInGBElement = $xmlWrite.CreateElement("DatabaseSizeInGB")
		$DatabaseSizeInGBElement.PSBase.InnerText = $size
	$rootElement.AppendChild($DatabaseSizeInGBElement) | Out-Null
	
	# convert to serialized string
	$xmlWriteSerialized = $xmlWrite.OuterXML
	
	# fix for i:type
	$xmlWriteSerialized = $xmlWriteSerialized.Replace("BlobCredentials type=", "BlobCredentials i:type=")
	
	return $xmlWriteSerialized
}

function get-DACDataCenter
(
       [Parameter(Mandatory=$true)][alias("s")][String]$Server
)
{
   $dataCenters = @{
   "CH" = "ch1prod-dacsvc.azure.com";
   "SN" = "sn1prod-dacsvc.azure.com";
   "DB" = "db3prod-dacsvc.azure.com";
   "AM" = "am1prod-dacsvc.azure.com";
   "HK" = "hkgprod-dacsvc.azure.com";
   "SG" = "sg1prod-dacsvc.azure.com";
   "DATA.INT.MSCDS.COM" = "dacdc.cloudapp.net"
   }
   
   $Regex = "data\.([A-Za-z]{2})([A-Za-z0-9\-]+)\.database\.windows\.net"
   $Hostname = ([System.Net.DNS]::GetHostEntry($Server)).HostName
   $Matches = [regex]::match($Hostname,$Regex)
   $datacenter = $null
   if ($Matches.success)
   {
          $datacenter = $dataCenters.Get_Item($Matches.Groups[1].value)
   }
   else
   {
          $datacenter = $dataCenters.Get_Item("DATA.INT.MSCDS.COM")
   }
   
   return $datacenter
}


Export-ModuleMember -function get-DacJobStatus, start-DacExport, start-DacImport