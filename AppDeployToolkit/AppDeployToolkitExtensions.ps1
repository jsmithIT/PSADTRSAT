<#
.SYNOPSIS
	This script is a template that allows you to extend the toolkit with your own custom functions.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'3.8.3'
[string]$appDeployExtScriptDate = '30/09/2020'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# ADD-Path function - Adds a folder to the windows %PATH% environment variable
Function global:Add-Path() {
    [Cmdletbinding()]
    param
    ( 
        [parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            Position = 0)]
        [String[]]$AddedFolder
    )

    # Get the current search path from the environment keys in the registry.
    $OldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

    # See if a new folder has been supplied.
    IF (!$AddedFolder)
    { Return ‘No Folder Supplied. $ENV:PATH Unchanged’ }

    # See if the new folder exists on the file system.
    IF (!(TEST-PATH $AddedFolder))
    { Return ‘Folder Does not Exist, Cannot be added to $ENV:PATH’ }

    # See if the new Folder is already in the path.
    IF ($OldPath | Select-String -SimpleMatch $AddedFolder)
    { Return 'Folder already within $ENV:PATH' }

    # Set the New Path
    Write-Log "Adding Folder $AddedFolder to Path Variable"
    $NewPath = $OldPath + ’;’ + $AddedFolder

    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $newPath

    # Show our results back to the world
    $CurrentPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
    Write-Log "New Path Variable is: $CurrentPath"
        
    Return $CurrentPath
}

# Remove-Path Function:  Removes folder from Path System Variable
Function global:Remove-Path() {
    [Cmdletbinding()]
    param
    ( 
        [parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            Position = 0)]
        [String[]]$RemovedFolder
    )

    # Get the Current Search Path from the environment keys in the registry
    $NewPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

    # Find the value to remove, replace it with $NULL. If it’s not found, nothing will change.
    $NewPath = $NewPath –replace [regex]::Escape(";$RemovedFolder"), $NULL

    # Update the Environment Path
    Write-Log "Removing $RemovedFolder From Path System Variable"
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $newPath

    # Show what we just did
    Write-Log "New System Path Variable is: $NewPath"
    Return $NewPath

}

# Set Users Security Group to have "Full Control" Rights to a folder.
Function global:Set-Rights() {
    [Cmdletbinding()]
    param
    ( 
        [parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            Position = 0)]
        [String[]]$Path
    )


    # Determine if $Path is Folder or Regkey
    $objecttype = (Get-Item $Path).GetType().Name
    
    # Define folder for user rights assignment
    
    $acl = (Get-Item $path).getaccesscontrol("Access")
    
    # Define ACL rule to apply to the folder
    If ($objecttype -eq "RegistryKey") {
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Users", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
    }
    If ($objecttype -eq "DirectoryInfo") {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
    }
            
    # Apply the rule to the folder
    Try {
        Set-Acl $Path $acl
        Write-Log "Granting Users Full Control Access to Location $Path"
    }
    Catch {
        Write-Log "Failed Granting Users Full Control Access to Location $path"
    }
}

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
} Else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================
