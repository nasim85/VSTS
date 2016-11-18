##-----------------------------------------------------------------------
## <copyright file="UpdateAssemblies.ps1">(c) Nasimuddin. All other rights reserved.</copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number. 
# Look for AssemblyFileVersion and replace with the parameter
# Look for AssemblyCompany and replace with the parameter
# Look for AssemblyCopyright and replace with the parameter
# Look for AssemblyProduct and replace with the parameter
# If found use it to version the assemblies.
#param([string]$Version="2016.5.0.B",[string]$BuildNumber="Web.16",[string]$SourceLocation="C:\RevenueCycle\Releases\R2016.6\Care\Website\PatientAccess\Accretive.DAL",[string]$AssemblyCompany="Accretive Health, Inc.",[string]$AssemblyCopyright="Copyright © Accretive Health, Inc. 2016" ,[string]$AssemblyProduct="AHtoAccess")

Trace-VstsEnteringInvocation $MyInvocation

# Get inputs.
$Version = Get-VstsInput -Name Version -Require
$BuildNumber = Get-VstsInput -Name BuildNumber -Require
$SourceLocation = Get-VstsInput -Name SourceLocation -Require
$AssemblyCompany = Get-VstsInput -Name AssemblyCompany
$AssemblyCopyright = Get-VstsInput -Name AssemblyCopyright
$AssemblyProduct = Get-VstsInput -Name AssemblyProduct

#
# For example, if the 'Build number format' build process parameter 
# $(BuildDefinitionName)_$(Year:yyyy).$(Month).$(DayOfMonth)$(Rev:.r)
# then your build numbers come out like this:
# "Build HelloWorld_2013.07.19.1"
# This script would then apply version 2013.07.19.1 to your assemblies.

# Enable -Verbose option
[CmdletBinding()]

# Regular expression pattern to find the version in the build number 
# and then apply it to the assemblies
#$VersionRegex = "\d+\.\d+\.\d+\.\d+"
$VersionRegex = 'AssemblyFileVersion\(\W+(\d+\.\d+\.\d+\.\d+|\d?)\W+\)'
$CompanyRegex = 'AssemblyCompany\(\W+([a-zA-Z0-9\W]+|\w?)\W+\)'
$CopyRightRegex = 'AssemblyCopyright\(\W+([a-zA-Z0-9\W]+|\w?)\W+\)'
$ProductRegex = 'AssemblyProduct\(\W+([a-zA-Z0-9\W]+|\w?)\W+\)'

#$SourceLocation = "C:\RevenueCycle\R2016.5\Care\Website\PatientAccess\Accretive.Services.Audits"
#$Env:BUILD_BUILDNUMBER="2015.5.0.1"

 # Function for loging events and exceptions ####################################

$logPath=$SourceLocation+"\Logs"

 Function LogFileGen([string] $SummaryTxt )
 {  
        Write-Host $SummaryTxt
        $SummaryTxt +" Time : "+$((Get-Date).ToString('yyyy,MM,dd hh:mm:ss')) |Out-File -FilePath $LogPath"\Assembly_Update_Log.txt" -Append 
  }
 # Validate log file path.#######################################################
 
    

    Try
    {
        If (!$(Test-Path -Path $LogPath)){New-Item -ItemType "directory" -Path $LogPath | Out-Null}
    }
    Catch
    {
        LogFileGen -SummaryTxt "Creating Log Folder : "$error
    }


# If this script is not running on a build server, remind user to 
# set environment variables so that this script can be debugged
if(-not ($SourceLocation -and $Version))
{
    Write-Error "You must set the following environment variables"
    Write-Error "to test this script interactively."
    Write-Host '$SourceLocation - For example, enter something like:'
    Write-Host '$SourceLocation = "C:\code\FabrikamTFVC\HelloWorld"'
    Write-Host '$Env:BUILD_BUILDNUMBER - For example, enter something like:'
    Write-Host '$Env:BUILD_BUILDNUMBER = "Build HelloWorld_0000.00.00.0"'
    exit 1
}

# Make sure path to source code directory is available
if (-not $SourceLocation)
{
    Write-Error ("BUILD_SOURCESDIRECTORY environment variable is missing.")
    exit 1
}
elseif (-not (Test-Path $SourceLocation))
{
    Write-Error "BUILD_SOURCESDIRECTORY does not exist: $SourceLocation"
    exit 1
}
Write-Verbose "BUILD_SOURCESDIRECTORY: $SourceLocation"

<#
# Make sure there is a build number
LogFileGen -SummaryTxt "Build Number : $Env:BUILD_BUILDNUMBER"
if (-not $Env:BUILD_BUILDNUMBER)
{
    Write-Error ("BUILD_BUILDNUMBER environment variable is missing.")
    exit 1
}
Write-Verbose "BUILD_BUILDNUMBER: $Env:BUILD_BUILDNUMBER"

# Get and validate the version data
$VersionData = [regex]::matches($Env:BUILD_BUILDNUMBER,$VersionRegex)
switch($VersionData.Count)
{
   0        
      { 
         Write-Error "Could not find version number data in BUILD_BUILDNUMBER."
         exit 1
      }
   1 {}
   default 
      { 
         Write-Warning "Found more than instance of version data in BUILD_BUILDNUMBER." 
         Write-Warning "Will assume first instance is version."
      }
}
#$NewVersion = $VersionData[0]
#>

$revNo=$BuildNumber.Split(".")

$NewVersion = $Version.Replace("B",$revNo[$revNo.Count-1])
Write-Verbose "Version: $NewVersion"

# Apply the version to the assembly property files
$files = gci $SourceLocation -recurse -include "*Properties*","My Project" | 
    ?{ $_.PSIsContainer } | 
    foreach { gci -Path $_.FullName -Recurse -include AssemblyInfo.* }
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."
    Write-Host "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        $filecontent = Get-Content($file)
        attrib $file -r

        <#
        $company='<Assembly: AssemblyCompany("'+$AssemblyCompany+'")>'
        $copyright='<Assembly: AssemblyCopyright("'+$AssemblyCopyright+'")>'
        $product='<Assembly: AssemblyProduct("'+$AssemblyProduct+'")>'

        if($file.Extension -eq ".cs")
        {
            $company='[Assembly: AssemblyCompany("'+$AssemblyCompany+'")]'
            $copyright='[Assembly: AssemblyCopyright("'+$AssemblyCopyright+'")]'
            $product='[Assembly: AssemblyProduct("'+$AssemblyProduct+'")]'

        }


               $CompnayContenet= $filecontent -match $CompanyRegex
               $CopyRightContent= $filecontent -match $CopyRightRegex
               $ProductContenet= $filecontent -match $ProductRegex

               if($AssemblyCompany -ne ""){$filecontent=$filecontent -Replace $CompnayContenet,$company}
               if($AssemblyCopyright -ne ""){$filecontent=$filecontent -Replace $CopyRightContent,$copyright}
               if($AssemblyProduct -ne ""){$filecontent=$filecontent -Replace $ProductContenet,$product}
               
        #>

        $company='AssemblyCompany("'+$AssemblyCompany+'")'
        $copyright='AssemblyCopyright("'+$AssemblyCopyright+'")'
        $product='AssemblyProduct("'+$AssemblyProduct+'")'
        $VersionSrting='AssemblyFileVersion("'+$NewVersion+'")'

        if($AssemblyCompany -ne ""){$filecontent=$filecontent -Replace $CompanyRegex,$company}
        if($AssemblyCopyright -ne ""){$filecontent=$filecontent -Replace $CopyRightRegex,$copyright}
        if($AssemblyProduct -ne ""){$filecontent=$filecontent -Replace $ProductRegex,$product}
        $filecontent=$filecontent -replace $VersionRegex, $VersionSrting | Out-File $file
        #$filecontent=$filecontent -replace $CompanyRegex, $company #| Out-File $file
        #$filecontent=$filecontent -replace $CopyRightRegex, $copyright #| Out-File $file
        #$filecontent=$filecontent -replace $ProductRegex, $product | Out-File $file
        Write-Verbose "$file.FullName - version applied"
        LogFileGen -SummaryTxt "$file - version applied"


    }
}
else
{
    Write-Warning "Found no files."
}