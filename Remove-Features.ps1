#Requires -RunAsAdministrator

<#
.SYNOPSIS
	Removes and disables unwanted Windows features, apps, services, and telemetry based on a configuration file.

.DESCRIPTION
	Reads a JSON configuration file and, for each defined category, removes or disables the
	matching items on the local machine. Supported categories are:
	  - Printer                  : removed with Remove-Printer
	  - WindowsPackage           : removed with Remove-WindowsPackage
	  - WindowsCapability        : removed with Remove-WindowsCapability
	  - WindowsOptionalFeature   : disabled with Disable-WindowsOptionalFeature
	  - AppxPackage              : removed for all users with Remove-AppxPackage
	                               (and matching provisioned packages with Remove-AppxProvisionedPackage)
	  - ScheduledTask            : disabled with Disable-ScheduledTask
	  - Service                  : startup type set to Disabled with Set-Service
	  - Autologger               : disabled via the registry (Start = 0)

	Names in the configuration file support wildcards (e.g. "*Xbox*"). The configuration file
	may contain // and /* */ comments, which are stripped before parsing.

	All actions are written to a log file and echoed to the console with color-coded levels.

	This script must be run in an elevated (administrator) PowerShell session.

.PARAMETER Restart
	If specified, restarts the computer after all changes have been applied.

.PARAMETER SettingsFile
	Path to the JSON/JSONC configuration file describing what to remove.
	Defaults to ".\settings.json".

.PARAMETER LogFile
	Path to the log file that actions are appended to.
	Defaults to ".\Remove-Features.log".

.EXAMPLE
	.\Remove-Features.ps1 -SettingsFile .\Remove-Features.conf.jsonc

	Applies the changes defined in Remove-Features.conf.jsonc without restarting.

.EXAMPLE
	.\Remove-Features.ps1 -SettingsFile .\Remove-Features.conf.jsonc -Restart

	Applies the changes and restarts the computer afterwards.

.NOTES
	Requires administrator privileges. Review the configuration file carefully before running,
	as removing packages, services, or features can be difficult to reverse.
#>

param (
	[Parameter(Mandatory=$false)]
	[switch]$Restart,

	[Parameter(Mandatory=$false)]
	[string]$SettingsFile = ".\settings.json",

	[Parameter(Mandatory=$false)]
	[string]$LogFile = ".\Remove-Features.log"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# write log to file
$logColor = @{
	"Debug" = "Gray"
	"Info" = "Green"
	"Warning" = "Yellow"
	"Error" = "Red"
	"Critical" = "Magenta"
}

function Write-Log {
	param (
		[Parameter(Mandatory=$true)]
		[string]$message,

		[ValidateSet("Debug", "Info", "Warning", "Error", "Critical")]
		[Parameter(Mandatory=$false)]
		[string]$level = "INFO"
	)

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$level = $level.ToUpper()

	$line = "$timestamp [$level] $message"

	$line | Write-Host -ForegroundColor $logColor[$level]
	$line | Out-File -FilePath $LogFile -Append
}


# laod settings.json and remove comments
if (-not (Test-Path $SettingsFile)) {
	Write-Log -message "settings.json not found" -level "Critical"
	exit 1
}
$settings = [regex]::Replace($(Get-Content $SettingsFile -Raw), "//.*|(?s)/\*.*?\*/", "") | ConvertFrom-Json



#region remove printers
Write-Log "Start removing printers" -level "Info"
foreach ($printer_str in $settings.printer) {
	# Get printer that match the name
	$printers = Get-Printer -Name $printer_str -ErrorAction Ignore

	# check if printer is found
	if (-not $printers) {
		# printer not found
		Write-Log -message "Printer not found: $($printer_str)" -level "Warning"
		continue
	}

	# loop through all printer that match the name
	foreach ($printer in $printers) {
		# Remove printer
		Write-Log -message "Removing printer: $($printer.Name)" -level "Info"
		try {
			Remove-Printer -Name $printer.Name | Out-Null
		} catch {
			Write-Log -message "Failed to remove printer: $($printer.Name)" -level "Error"
		}
	}	
}
#endregion


#region remove Windows Packages
Write-Log "Start removing Windows Packages" -level "Info"
foreach ($WindowsPackage_str in $settings.WindowsPackage) {
	# Get packages that match the name
	$WindowsPackages = Get-WindowsPackage -Online -PackageName $WindowsPackage_str

	# check if package is found
	if (-not $WindowsPackages) {
		# Package not found
		Write-Log "Windows Package not found: $($WindowsPackage_str)" -level "Warning"
		continue
	}

	# loop through all found packages
	foreach ($WindowsPackage in $WindowsPackages) {
		# Remove package
		Write-Log "Removing Windows Package: $($WindowsPackage.PackageName)" -level "Info"
		try {
			Remove-WindowsPackage -Online -PackageName $WindowsPackage.PackageName -NoRestart | Out-Null
		} catch {
			Write-Log "Failed to remove Windows Package: $($WindowsPackage.PackageName)" -level "Error"
		}
	}
}
#endregion


#region remove Windows Capabilities
Write-Log "Start removing Windows Capabilities" -level "Info"
foreach ($WindowsCapability_str in $settings.WindowsCapability) {
	# Get capability that match the name
	$WindowsCapabilities = Get-WindowsCapability -Online -Name $WindowsCapability_str | Where-Object { $_.State -eq "Installed" }

	# check if capability is found
	if (-not $WindowsCapabilities) {
		Write-Log "Windows Capability not found: $($WindowsCapability_str)" -level "Warning"
		continue
	}

	# loop through all found capabilities
	foreach ($WindowsCapability in $WindowsCapabilities) {
		# Remove capability
		Write-Log "Removing Windows Capability: $($WindowsCapability.Name)" -level "Info"
		try {
			Remove-WindowsCapability -Online -Name $WindowsCapability.Name | Out-Null
		} catch {
			Write-Log "Failed to remove Windows Capability: $($WindowsCapability.Name)" -level "Error"
		}
	}
}
#endregion


#region disable Windows Optional Features
Write-Log "Start disabling Windows Optional Features" -level "Info"
foreach ($WindowsOptionalFeature_str in $settings.WindowsOptionalFeature) {
	# Get feature that match the name
	$WindowsOptionalFeatures = Get-WindowsOptionalFeature -Online -FeatureName $WindowsOptionalFeature_str

	# check if optional feature is found
	if (-not $WindowsOptionalFeatures) {
		Write-Log "Windows Optional Feature not found: $($WindowsOptionalFeature_str)" -level "Warning"
		continue
	}

	# loop through all found optional features
	foreach ($WindowsOptionalFeature in $WindowsOptionalFeatures) {
		# check if optional feature is already disabled
		if ($WindowsOptionalFeature.State -ne "Enabled") {
			Write-Log "Windows Optional Feature already disabled: $($WindowsOptionalFeature.FeatureName)" -level "Warning"
			continue
		}

		# Disable optional feature
		Write-Log "Disabling Windows Optional Feature: $($WindowsOptionalFeature.FeatureName)" -level "Info"
		try {
			Disable-WindowsOptionalFeature -Online -FeatureName $WindowsOptionalFeature.FeatureName -NoRestart | Out-Null
		} catch {
			Write-Log "Failed to disable Windows Optional Feature: $($WindowsOptionalFeature.FeatureName)" -level "Error"
		}	
	}
}
#endregion


#region remove appx packages
Write-Log "Start removing appx packages" -level "Info"
foreach ($AppxPackage_str in $settings.AppxPackage) {
	# Get package that match the name
	$AppxPackages = Get-AppxPackage -AllUsers -Name $AppxPackage_str

	# check if package is found
	if (-not $AppxPackages) {
		# Package not found
		Write-Log "Appx Package not found: $($AppxPackage_str)" -level "Warning"
		continue
	}

	# loop through all found packages
	foreach ($AppxPackage in $AppxPackages) {
		# Remove package
		Write-Log "Removing Appx Package: $($AppxPackage.PackageFullName)" -level "Info"
		try {
			$AppxPackage | Remove-AppxPackage -AllUsers | Out-Null
		} catch {
			Write-Log "Failed to remove Appx Package: $($AppxPackage.PackageFullName)" -level "Error"
		}
	}
}
#endregion


#region remove appx provisioned packages
Write-Log "Start removing appx provisioned packages" -level "Info"
foreach ($AppxPackage_str in $settings.AppxPackage) {
	# Remove appx provisioned package
	$AppxProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.displayName -like $AppxPackage_str }

	# check if package is found
	if (-not $AppxProvisionedPackages) {
		# Package not found
		Write-Log "Appx Provisioned Package not found: $($AppxPackage_str)" -level "Warning"
		continue
	}

	# loop through all found packages
	foreach ($AppxProvisionedPackage in $AppxProvisionedPackages) {
		# Remove package
		Write-Log "Removing Appx Provisioned Package: $($AppxProvisionedPackage.PackageName)" -level "Info"
		try {
			Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $AppxProvisionedPackage.PackageName | Out-Null
		} catch {
			Write-Log "Failed to remove Appx Provisioned Package: $($AppxProvisionedPackage.PackageName)" -level "Error"
		}
	}
}
#endregion


#region disable scheduled tasks
Write-Log "Start disabling scheduled tasks" -level "Info"
foreach ($ScheduledTask_str in $settings.ScheduledTask) {
	# Get scheduled task that match the name
	$ScheduledTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like $ScheduledTask_str }

	# if scheduled task is found
	if (-not $ScheduledTasks) {
		# Scheduled task not found
		Write-Log "Scheduled Task not found: $($ScheduledTask_str)" -level "Warning"
		continue
	}

	# loop through all found scheduled tasks
	foreach ($ScheduledTask in $ScheduledTasks) {
		# check if scheduled task is already disabled
		if ($ScheduledTask.State -eq "Disabled") {
			# Scheduled task already disabled
			Write-Log "Scheduled Task already disabled: $($ScheduledTask.TaskName)" -level "Warning"
			continue
		}

		# Disable scheduled task
		Write-Log "Disabling Scheduled Task: $($ScheduledTask.TaskName)" -level "Info"
		try {
			$ScheduledTask | Disable-ScheduledTask | Out-Null
		} catch {
			Write-Log "Failed to disable Scheduled Task: $($ScheduledTask.TaskName)" -level "Error"
		}
	}	
}
#endregion


#TODO: Per User Services
# - CDPUserSvc

#region disable services
Write-Log "Start disabling services" -level "Info"
foreach ($Service_str in $settings.Service) {
	# Get service that match the name
	$Services = Get-Service -Name $Service_str

	# if service is found
	if (-not $Services) {
		# Service not found
		Write-Log "Service not found: $($Service_str)" -level "Warning"
		continue
	}

	# loop through all found services
	foreach ($Service in $Services) {
		# check if service is already disabled
		if ($Service.StartType -eq "Disabled") {
			# Service already disabled
			Write-Log "Service already disabled: $($Service.ServiceName)" -level "Warning"
			continue
		}

		# Disable service
		Write-Log "Disabling Service: $($Service.ServiceName)" -level "Info"
		try {
			Set-Service -Name $Service.ServiceName -StartupType "Disabled" | Out-Null
		} catch {
			Write-Log "Failed to disable Service: $($Service.ServiceName)" -level "Error"
		}
	}
}
#endregion


#region disable autologger
Write-Log "Start disabling autologger" -level "Info"
foreach ($autolooger_str in $settings.Autologger) {
	$autologger_path = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$autolooger_str"

	# check if autologger is found
	if (!(Test-Path $autologger_path)) {
		Write-Log "Autologger not found: $($autolooger_str)" -level "Warning"
		continue
	}

	# check if autologger is already disabled
	$autologger = Get-Item -Path $autologger_path
	if ($autologger.GetValue("Start") -eq "0") {
		# Autologger already disabled
		Write-Log "Autologger already disabled: $autolooger_str" -level "Warning"
		continue
	}

	# disable autologger
	Write-Log "Disabling Autologger: $autolooger_str" -level "Info"
	try {
		$autologger | Set-ItemProperty -Name "Start" -Value "0" -Force | Out-Null
	} catch {
		Write-Log "Failed to disable Autologger: $autolooger_str" -level "Error"
	}
}
#endregion


#region restart computer
if ($Restart) {
	Write-Log "Restarting computer" -level "Info"
	Restart-Computer -Force
}
#endregion
