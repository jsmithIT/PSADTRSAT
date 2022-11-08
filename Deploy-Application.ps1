<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
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
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall', 'Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory = $false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory = $false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory = $false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	##* Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Remote Server Administration Tools'
	[string]$appVersion = '1.0.0'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '2022.08.26'
	[string]$appScriptAuthor = 'JBSMITH, KTEUTON'

	##* Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = "$appName ($appVersion)"
	[string]$installTitle = "$appName ($appVersion)"

	##*===============================================
	##* ANCHOR: VARIABLES - Template
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# Template array(s)/variable(s) used within the PSADT.

	## Set variables to match script variables
	# These Variable(s) keep the spaces the PSADT script removes. These can and are used in titles, messages, logs and the PIRK information for the application being installed.
	$apVendor = $appVendor
	$apName = $appName
	$apversion = $appVersion
	$apScriptVersion = $appScriptVersion

	##*===============================================
	##* ANCHOR: VARIABLES - Author
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# If the template array(s)/variable(s) aren't enough, add more array(s)/variable(s) here.

	# WUS registry key location.
	$WSUSKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

	# Stores the WSUS registry key value.
	$UseWUServer = Get-ItemProperty -Path "$WSUSKey" -Name "UseWUServer" | Select-Object -ExpandProperty UseWUServer

	# Location of key to disable the restart option in the Start Menu.
	$RestartKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideRestart"

	# Location of key to disable the shut down option in the Start Menu.
	$ShutDownKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideShutDown"

	# Name of feature being installed.
	$FeatureName = "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

	# Location of Powershell executable.
	$PSLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

	##*===============================================
	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.3'
	[string]$deployAppScriptDate = '30/09/2020'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		# Check if deployment is interactive. 
		# If yes (it is interactive), show install prompt.
		If ($DeployMode -eq "Interactive") {
			$dialog = (Show-InstallationPrompt -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Changes are going to be made to your device. `n `n Please save your work and close all windows. `n `n To defer the changes, click the defer button on the next screen.")
		}

		# Check if user accepted the install prompt.
		# If yes (it was accepted), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($dialog -eq "OK") { 
			Show-InstallationWelcome -CloseApps "None" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		# Bypass the WSUS.
		Try {
			# Remove option for user to restart or shut down.
			Write-Log -Message "Disabling Restart and Shut Down options."
			Set-ItemProperty -Path "$RestartKey" -Name "value" -Value 1
			Set-ItemProperty -Path "$ShutDownKey" -Name "value" -Value 1

			# Bypasses the WSUS by editing the server registry value.
			Write-Log -Message "Bypassing the WSUS."
			Set-ItemProperty -Path "$WSUSKey" -Name "UseWUServer" -Value 0
			Restart-Service "Windows Update"
		}
		Catch [System.Exception] {
			Write-Log -Message "Registry key changes failed."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##*===============================================
		##* ANCHOR: INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		# Show installation progress message window.
		Show-InstallationProgress -StatusMessage "Installing `n `n $apName ($apversion) `n `n Please Wait..." 

		##* Activates Feature
		# Determines if features are present.
		# Extracts AD's presence from string.
		Write-Log -Message "Detecting RSADT feature presences."
		[string]$Features = Get-WindowsCapability -Name RSAT* -Online | Select-Object -ExpandProperty State
		$ADStatus = $Features.SubString(11, 10)

		# Check if the feature is present.
		# If the feature is not present, activate it.
		# If it fails to activate because the WSUS bypass expired, bypass the WSUS again.
		# Else, log that the feature is already present.
		# Repeat for all features.
		Write-Log -Message "Activating RSADT feature."
		If ($ADStatus -match "NotPresent") {
			Try {
				Write-Log "Activating Active Directory DS-LDS Tools."
				Execute-Process -Path "$PSLocation" -Parameters "-executionpolicy bypass -File `"$dirFiles\Untitled1.ps1`""
			}
			Catch [Microsoft.Dism.Commands.AddWindowsCapabilityCommand] {
				Write-Log -Message "WSUS bypass expired. Reinitializing WSUS bypass and retrying."
				# Bypass the WSUS.
				Try {
					# Remove option for user to restart or shut down.
					Write-Log -Message "Disabling Restart and Shut Down options."
					Set-ItemProperty -Path "$RestartKey" -Name "value" -Value 1
					Set-ItemProperty -Path "$ShutDownKey" -Name "value" -Value 1

					# Bypasses the WSUS by editing the server registry value.
					Write-Log -Message "Bypassing the WSUS."
					Set-ItemProperty -Path "$WSUSKey" -Name "UseWUServer" -Value 0
					Restart-Service "Windows Update"
				}
				Catch [System.Exception] {
					Write-Log -Message "Registry key changes failed."
					Write-Log -Message "Exiting script with error."
					Exit-Script -ExitCode 1627
				}
			}
			Catch [System.Exception] {
				Write-Log -Message "Feature failed to activate."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		Else {
			Write-Log -Message "Feature already present."
		}

		##* Every package should have a package information registry key (PIRK), which details what the $apversion and $apScriptVErsion are, along with any other information.
		# Create package information registry key (PIRK).
		# If creation failed, log results. Exit script.
		Try {
			Write-Log -Message "Creating package information registry key (PIRK)."
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information" -Name "Readme" -Value "These Package Information Registry Keys (PIRKs) are used for SCCM application detection. Please do not modify unless you know what you are doing." -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apVersion" -Value "$apversion" -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apScriptVersion" -Value "$apScriptVErsion" -Type String
			Write-Log -Message "Creating package information registry key (PIRK) complete." 
		}
		# If creation failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Creating package information registry key (PIRK) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##*===============================================
		##* ANCHOR: POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		# Reinstates the WSUS.
		Try {
			# Reinstates the WSUS by editing the server registry value.
			Write-Log -Message "Reinstating WSUS."
			Set-ItemProperty -Path "$WSUSKey" -Name "UseWUServer" -Value $UseWUServer
			Restart-Service "Windows Update"

			# Reinstates the user's restart and shut down options.
			Write-Log -Message "Reinstating Restart and Shut Down options."
			Set-ItemProperty -Path "$RestartKey" -Name "value" -Value 0
			Set-ItemProperty -Path "$ShutDownKey" -Name "value" -Value 0
		}
		Catch [System.Exception] {
			Write-Log -Message "Registry key changes failed."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		# Show install completed prompt.
		Write-Log -Message "Showing installation completed prompt."
		Show-InstallationPrompt -Title "Install Completed"  -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Your installation of $apName ($apversion) has completed.`n `n Please close any remaining prompts/windows that may have opened.`n `n Questions or issues? `n Please contact the IT Service Desk: `n ITServiceDesk@co.tuolumne.ca.us"	

	}
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	# Reinstates the WSUS.
	Try {
		# Reinstates the WSUS by editing the server registry value.
		Write-Log -Message "Reinstating WSUS."
		Set-ItemProperty -Path "$WSUSKey" -Name "UseWUServer" -Value $UseWUServer
		Restart-Service "Windows Update"

		# Reinstates the user's restart and shut down options.
		Write-Log -Message "Reinstating Restart and Shut Down options."
		Set-ItemProperty -Path "$RestartKey" -Name "value" -Value 0
		Set-ItemProperty -Path "$ShutDownKey" -Name "value" -Value 0
	}
	Catch [System.Exception] {
		Write-Log -Message "Registry key changes failed."
		Write-Log -Message "Exiting script with error."
		Exit-Script -ExitCode 1627
	}
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
