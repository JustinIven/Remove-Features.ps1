# Remove-Features

A PowerShell script for debloating and hardening a Windows installation. It removes or disables
unwanted apps, features, services, scheduled tasks, and telemetry based on a single JSON
configuration file.

## Features

The script processes the following categories, each driven by a list of names (wildcards supported):

| Category                 | Action                                                    |
| ------------------------ | --------------------------------------------------------- |
| `Printer`                | Removes printers                                          |
| `WindowsPackage`         | Removes Windows packages (FoD / capabilities packages)    |
| `WindowsCapability`      | Removes Windows capabilities                              |
| `WindowsOptionalFeature` | Disables Windows optional features                        |
| `AppxPackage`            | Removes Appx packages (all users) and provisioned packages |
| `ScheduledTask`          | Disables scheduled tasks                                  |
| `Service`                | Sets service startup type to `Disabled`                   |
| `Autologger`             | Disables ETW autologgers via the registry                 |

All actions are logged to a file and echoed to the console with color-coded levels.

## Requirements

- Windows with PowerShell 5.1 or later
- An **elevated** (administrator) PowerShell session

## Usage

```powershell
# Apply the changes defined in the configuration file
.\Remove-Features.ps1 -SettingsFile .\Remove-Features.conf.jsonc

# Apply the changes and restart the computer afterwards
.\Remove-Features.ps1 -SettingsFile .\Remove-Features.conf.jsonc -Restart
```

### Parameters

| Parameter       | Description                                              | Default                  |
| --------------- | -------------------------------------------------------- | ------------------------ |
| `-SettingsFile` | Path to the JSON/JSONC configuration file.               | `.\settings.json`        |
| `-LogFile`      | Path to the log file that actions are appended to.       | `.\Remove-Features.log`  |
| `-Restart`      | Restart the computer after all changes are applied.      | *(off)*                  |

> **Note:** The default `-SettingsFile` value is `.\settings.json`. The included configuration
> file is named `Remove-Features.conf.jsonc`, so pass it explicitly as shown above (or rename it).

## Configuration

Edit [Remove-Features.conf.jsonc](Remove-Features.conf.jsonc) to control what gets removed or
disabled. Each top-level key maps to a category listed above and contains an array of names.
Names may include wildcards (for example `"*Xbox*"`), and the file supports `//` and `/* */`
comments, which are stripped before parsing.

```jsonc
{
    "AppxPackage": [
        "Microsoft.XboxApp",
        "*Microsoft.549981C3F5F10*" // Cortana
    ],
    "Service": [
        "DiagTrack" // Connected User Experiences and Telemetry
    ]
}
```

## Warning

Removing packages, services, and features can be difficult or impossible to reverse. Review the
configuration carefully and test on a non-production machine before applying broadly.

## License

See [LICENSE](LICENSE).
