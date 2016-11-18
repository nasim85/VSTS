Param(
    [string] $Script ,
	[string] $ScriptArguments
)



$scriptPath =  [System.IO.Path]::GetTempFileName().Replace(".tmp",".ps1")
$script >> $scriptPath


if (-not (get-command 'Import-VstsLocStrings'  -ErrorAction SilentlyContinue))
{
    $parametershash = $PSBoundParameters
    
    function Import-VstsLocStrings{
        Write-Output 'Import-VstsLocStrings'
    }

    function Trace-VstsEnteringInvocation{
        Write-Output 'Entering VstsEnteringInvocation'
    }


    function Trace-VstsLeavingInvocation{
        Write-Output 'Leaving VstsLeavingInvocation'
    }


    function Get-VstsInput{
        param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Default')]
        $Default,
        [Parameter(ParameterSetName = 'Require')]
        [switch]$Require,
        [switch]$AsBool,
        [switch]$AsInt)
        
        $result = $parametershash[$Name]

         # Write error if required.
        if ($Require) {
            Write-Error " Required $Name"
            return
        }

        # Fallback to the default if provided.
        if ($PSCmdlet.ParameterSetName -eq 'Default') {
            $result = $Default
            Write-Verbose " Defaulted to: '$result'"
        } else {
            $result = ''
        }

        # Convert to bool if specified.
        if ($AsBool) {
            if ($result -isnot [bool]) {
                $result = "$result" -in '1', 'true'
                Write-Verbose " Converted to bool: $result"
            }

            return $result
        }

        # Convert to int if specified.
        if ($AsInt) {
            if ($result -isnot [int]) {
                try {
                    $result = [int]"$result"
                } catch {
                    $result = 0
                }

                Write-Verbose " Converted to int: $result"
            }

        }

        return $result
    }
}

Import-Module $PSScriptRoot\ps_modules\VstsTaskSdk

if ($scriptArguments -match '[\r\n]') {
    throw (Get-VstsLocString -Key InvalidScriptArguments0 -ArgumentList $scriptArguments)
}

# Trace the expression as it will be invoked.
$scriptCommand = "& '$($scriptPath.Replace("'", "''"))' $scriptArguments"
Remove-Variable -Name script
Remove-Variable -Name scriptPath
Remove-Variable -Name scriptArguments

# Remove all commands imported from VstsTaskSdk, other than Out-Default.
Get-ChildItem -LiteralPath function: |
    Where-Object {
        ($_.ModuleName -eq 'VstsTaskSdk' -and $_.Name -ne 'Out-Default') -or
        ($_.Name -eq 'Invoke-VstsTaskScript') 
    } |
    Remove-Item

# For compatibility with the legacy handler implementation, set the error action
# preference to continue. An implication of changing the preference to Continue,
# is that Invoke-VstsTaskScript will no longer handle setting the result to failed.
$global:ErrorActionPreference = 'Continue'

# Run the user's script. Redirect the error pipeline to the output pipeline to enable
# a couple goals due to compatibility with the legacy handler implementation:
# 1) STDERR from external commands needs to be converted into error records. Piping
#    the redirected error output to an intermediate command before it is piped to
#    Out-Default will implicitly perform the conversion.
# 2) The task result needs to be set to failed if an error record is encountered.
#    As mentioned above, the requirement to handle this is an implication of changing
#    the error action preference.
([scriptblock]::Create($scriptCommand)) |
    ForEach-Object {
        Remove-Variable -Name scriptCommand
        Write-Host "##[command]$_"
        . $_ 2>&1
    } |
    ForEach-Object {
        # Put the object back into the pipeline. When doing this, the object needs
        # to be wrapped in an array to prevent unraveling.
        ,$_

        # Set the task result to failed if the object is an error record.
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "##vso[task.complete result=Failed]"
        }
    }
 