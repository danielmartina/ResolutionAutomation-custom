## Fun fact, most of this code is generated entirely using GPT-3.5

## CHATGPT PROMPT 1
## Explain to me how to parse a conf file in PowerShell.

## AI EXPLAINS HOW... this is important as it invokes reflective thinking.
## Having AI explain things to us first before asking 
## your question, significantly improves the quality of the response.


### PROMPT 2
### Okay, using this conf, can you write a powershell script that saves a new value to the global_prep_cmd?

### AI Generates valid code for saving to conf file

## Prompt 3
### I think I have found a mistake, can you double check your work?

## Again, this is important for reflective thinking, having the AI
## check its work is important, as it may improve quality. 

## Response: Did not find any errors.

## Prompt 4: I tried this and unfortunately my config file requires admin to save.

## AI Responses solutions

## Like before, I already knew the solution but having the AI
## respond with tips, greatly improves the quality of the next prompts

## Prompt 5 (Final with GPT3.5): Can you make this script self elevate itself.
## Repeat the same prompt principles, and basically 70% of this script is entirely written by Artificial Intelligence. Yay!

## Refactor Prompt (GPT-4): Please refactor the following code, remove duplication and define better function names, once finished you will also add documentation and comments to each function.
param($scriptPath)



# This script modifies the global_prep_cmd setting in the Sunshine configuration file
# to add a command that runs ResolutionMatcher.ps1

# Check if the current user has administrator privileges
$isAdmin = [bool]([System.Security.Principal.WindowsIdentity]::GetCurrent().groups -match 'S-1-5-32-544')

# If the current user is not an administrator, re-launch the script with elevated privileges
if (-not $isAdmin) {
    Start-Process powershell.exe  -Verb RunAs -ArgumentList "-NoExit -File `"$($MyInvocation.MyCommand.Path)`" `"$(Join-Path -Path (Get-Location) -ChildPath "ResolutionMatcher.ps1")`" $($MyInvocation.MyCommand.UnboundArguments)"
    exit
}

# Define the path to the Sunshine configuration file
$confPath = "C:\Program Files\Sunshine\config\sunshine.conf"
$scriptRoot = Split-Path $scriptPath -Parent



function FillOut-VariableOnPowerShellScript($scriptFilePath, $variableName, $value) {
    # Define the path to the file you want to modify

    # Define the regular expression to search for and the new value you want to replace it with
    $searchPattern = "(\`$$variableName\s*=\s*)`"([^`"]*)`""

    # Read the contents of the file into a variable
    $content = Get-Content $scriptFilePath
    

    # Loop through each line in the file
    for ($i = 0; $i -lt $content.Count; $i++) {
        # If the current line matches the search pattern, replace it with the new value
        if ($content[$i] -match $searchPattern) {
            $content[$i] = $content[$i] -replace $searchPattern, "`$1`"$value`""
        }
    }

    # Write the modified contents back to the file
    $content | Set-Content $scriptFilePath

}

# Get the current value of global_prep_cmd from the configuration file
function Get-GlobalPrepCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $ConfigPath

    # Find the line that contains the global_prep_cmd setting
    $globalPrepCmdLine = $config | Where-Object { $_ -match '^global_prep_cmd\s*=' }

    # Extract the current value of global_prep_cmd
    if ($globalPrepCmdLine -match '=\s*(.+)$') {
        return $matches[1]
    }
    else {
        Write-Information "Unable to extract current value of global_prep_cmd, this probably means user has not setup prep commands yet."
        return [object[]]@()
    }
}

# Remove any existing commands that contain ResolutionMatcher from the global_prep_cmd value
function Remove-ResolutionMatcherCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    # Get the current value of global_prep_cmd as a JSON string
    $globalPrepCmdJson = Get-GlobalPrepCommand -ConfigPath $ConfigPath

    # Convert the JSON string to an array of objects
    $globalPrepCmdArray = $globalPrepCmdJson | ConvertFrom-Json
    $filteredCommands = @()

    # Loop through the array in reverse order and remove any commands that contain ResolutionMatcher
    for ($i = $globalPrepCmdArray.Count - 1; $i -ge 0; $i--) {
        if (-not ($globalPrepCmdArray[$i].do -like "*ResolutionMatcher*")) {
            $filteredCommands += $globalPrepCmdArray[$i]
        }
    }


    # Return the modified array of objects
    return [object[]]$filteredCommands
}

# Set a new value for global_prep_cmd in the configuration file
function Set-GlobalPrepCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        # The new value for global_prep_cmd as an array of objects
        [Parameter(Mandatory)]
        [object[]]$Value
    )

    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $ConfigPath

    # Get the current value of global_prep_cmd as a JSON string
    $currentValueJson = Get-GlobalPrepCommand -ConfigPath $ConfigPath

    # Convert the new value to a JSON string
    $newValueJson = ConvertTo-Json -InputObject $Value -Compress

    # Replace the current value with the new value in the config array
    try {
        $config = $config -replace [regex]::Escape($currentValueJson), $newValueJson
    }
    catch {
        # If it failed, it probably does not exist yet.
        $config += "global_prep_cmd = $($newValueJson)"
    }



    # Write the modified config array back to the file
    $config | Set-Content -Path $ConfigPath -Force
}

# Add a new command to run ResolutionMatcher.ps1 to the global_prep_cmd value
function Add-ResolutionMatcherCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        # The path to the ResolutionMatcher script
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    # Remove any existing commands that contain ResolutionMatcher from the global_prep_cmd value
    $globalPrepCmdArray = Remove-ResolutionMatcherCommand -ConfigPath $ConfigPath

    # Create a new object with the command to run ResolutionMatcher.ps1
    $ResolutionMatcherCommand = [PSCustomObject]@{
        do       = "powershell.exe -executionpolicy bypass -file `"$($ScriptPath)`""
        elevated = "false"
        undo     = "powershell.exe -executionpolicy bypass -file `"$($scriptRoot)\ResolutionMatcher-Functions.ps1`" $true"
    }

    # If the Monitor Swapper is also installed, we need to reverse the undo commands because Sunshine executes undo commands backwards.
    # This would cause resolution to revert on the primary display instead of the intended behavior.
    foreach ($command in $globalPrepCmdArray) {
        if ($command.do -like '*MonitorSwapAutomation*') {
            $old = $ResolutionMatcherCommand.undo
            $ResolutionMatcherCommand.undo = $command.undo
            $command.undo = $old
        }
    }

    # Add the new object to the global_prep_cmd array
    $globalPrepCmdArray = @($globalPrepCmdArray, $ResolutionMatcherCommand) | Where-Object { $_ }



    # Set the new value for global_prep_cmd in the configuration file
    Set-GlobalPrepCommand -ConfigPath $ConfigPath -Value $globalPrepCmdArray
}

FillOut-VariableOnPowerShellScript -variableName "path" -value $scriptRoot -scriptFilePath $scriptPath
FillOut-VariableOnPowerShellScript -variableName "path" -value $scriptRoot -scriptFilePath "$scriptRoot/ResolutionMatcher-Functions.ps1"
# Invoke the function to add the ResolutionMatcher command
Add-ResolutionMatcherCommand -ConfigPath $confPath -ScriptPath $scriptPath

Write-Host "If you didn't see any errors, that means the script installed without issues! You can close this window."
