# deobfuscated SentinelOne script
# Adam's comments

# remove variable 'toInvoke' if it already exists
try { Remove-Item "variable:toInvoke" -ErrorAction SilentlyContinue | Out-Null } catch {} ; 

<#
function Get-Params

Takes in a PowerShell function as an object.

Returns a string containing the non-default paramaters to be used in the hook function

#>
function Get-Params { 
    param( $functionObj ) # orginal PS function as an object
    
    $local:invokedExpression = '[CmdletBinding(DefaultParametersetName="' + $functionObj.defaultParameterSet + '")]' + "`n" # build string
    
    $invokedExpression += "param(" # build string
    $local:properties = $functionObj.Parameters # [Dict]: all parameters of orginal function
    
    # declare temp function
    function Temp-Function { 
        [CmdletBinding()] param() 
    } 
    
    $local:tempFunction = Get-Command Temp-Function # select Temp-Function as object
    
    $local:commonParametersArr = $tempFunction.Parameters.keys # get default parameters of a function
    
    # remove Temp-Function that was declared
    Remove-Item function:Temp-Function 
    
    # for each parameter in orginal PS function
    foreach ($key in $properties.keys) { 
        # skip all defualt parameters
        if ($commonParametersArr -contains $key) 
        { continue } 
        
        # for each parameterset 
        foreach ($ParameterSet in $properties[$key].ParameterSets) { 
            $invokedExpression += "`n[parameter(" # build string
            $values = $ParameterSet.values | Select-Object if ($values.IsMandatory) { $invokedExpression += 'Mandatory = $True,' } 
            
            if ($values.Position -ge 0) { 
                $invokedExpression += 'Position = ' + $values.Position + ',' 
            } 
                
            if ($values.ValueFromPipeline) { 
                $invokedExpression += 'ValueFromPipeline = $True,' 
            } 
                
            if ($values.ValueFromPipelineByPropertyName) { 
                $invokedExpression += 'ValueFromPipelineByPropertyName = $True,' 
            } 
                
            if ($values.ValueFromRemainingArguments) { 
                $invokedExpression += 'ValueFromRemainingArguments = $True,' 
            } 
                
            $invokedExpression += 'ParameterSetName = "' + $($ParameterSet.Keys | Select-Object -First 1) + '",' 
            $invokedExpression = $invokedExpression.Substring(0, $invokedExpression.Length - 1) 
            $invokedExpression += ")]`n" 
        } 
            
        # this loop causes the "error at line:24" due to a parameter not having an alias. A non fatal error
        foreach ($Alias in $properties[$key].Aliases) { 
            $invokedExpression += '[alias("' 
            $invokedExpression += $Alias 
            $invokedExpression += '")]' + "`n" 
        } 
                
        if ($properties[$key].SwitchParameter) { 
            $invokedExpression += "[switch]`n" 
        }   
        else { 
            $invokedExpression += "[" + $properties[$key].ParameterType + "]`n" 
        } 
                
        $invokedExpression += "`$$key," 
    } 
            
    $invokedExpression = $invokedExpression.Substring(0, $invokedExpression.Length - 1) 
    $invokedExpression += ")" 
            
    return $invokedExpression 

    <#
    EX. for $functionObj = a Get-PSBreakpoint object

        $invokedExpression = 

        [CmdletBinding(DefaultParametersetName="Script")]
        param(
        [parameter(ParameterSetName = "Variable")]
        [string[]]
        $Script,
        [parameter(ParameterSetName = "Id")]
        [int[]]
        $Id,
        [parameter(ParameterSetName = "Variable")]
        [string[]]
        $Variable,
        [parameter(ParameterSetName = "Command")]
        [string[]]
        $Command,
        [parameter(ParameterSetName = "Type")]
        [Microsoft.PowerShell.Commands.BreakpointType[]]
        $Type)

        This is the start of declaring your own function parameters
    #>
} 

function Set-HookFunctionTabs { 
    param( $hookFunctionName ) 
    
    # a clever way to call their hook functions
    $local:origFunction = Get-Command "$hookFunctionName`_Hook" -CommandType Function | Select-Object -first 1 # select hook function as object
    # $local:origFunction = Get-Command "Get-PSBreakpoint_Hook" -CommandType Function | Select-Object -first 1

    $local:toInvoke = "function global:$hookFunctionName {`n" # build string
    
    $local:originalFunctionObj = Get-Command $hookFunctionName -Type cmdlet # select original PS command as an object
    
    # call their custom Get-Params function 
    # pass orginial function as an object
    # returns non-default paramaters for hook function to use
    $toInvoke += Get-Params $originalFunctionObj # build string
    
    $toInvoke += $origFunction.scriptBlock.ToString() # get code under hook function
    
    $toInvoke += '}' 
    
    $local:invokeEx = $(Get-Command Invoke-Expression -Type cmdlet) # select invoke-expression command as an object

    # load the hook function into the current session
    # this hook function will over take priority from orginal PS command
    . $invokeEx $toInvoke # execute string using invoke-expression
    <# EX. $toInvoke would contain:

        function global:Get-PSBreakpoint {
        [CmdletBinding(DefaultParametersetName="Script")]
        param(
        [parameter(ParameterSetName = "Variable")]
        [string[]]
        $Script,
        [parameter(ParameterSetName = "Id")]
        [int[]]
        $Id,
        [parameter(ParameterSetName = "Variable")]
        [string[]]
        $Variable,
        [parameter(ParameterSetName = "Command")]
        [string[]]
        $Command,
        [parameter(ParameterSetName = "Type")]
        [Microsoft.PowerShell.Commands.BreakpointType[]]
        $Type)
            $local:origGetPsbreakpoint = Get-Command Get-PSBreakpoint -Type cmdlet
            if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) {
                return ((& $origGetPsbreakpoint @psBoundParameters) | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#/>')) })
            }
            else {
                return ((& $origGetPsbreakpoint @args) | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#/>')) })
            }
        }
    #>
    
    # clear the following variables to be used in the next Set-HookFunctionTabs call
    try {
        Remove-Item 'variable:invokeEx' -ErrorAction SilentlyContinue | Out-Null
    }
    catch {} 
    
    try {
        Remove-Item 'variable:toInvoke' -ErrorAction SilentlyContinue | Out-Null
    }
    catch {} 
    
    try {
        Remove-Item 'variable:hookfunctionname' -ErrorAction SilentlyContinue | Out-Null
    }
    catch {} 
    
    try {
        Remove-Item 'variable:origfunction' -ErrorAction SilentlyContinue | Out-Null
    }
    catch {} 
    
    try {
        Remove-Item 'variable:originalfunctionobj' -ErrorAction SilentlyContinue | Out-Null
    }
    catch {} 
} 

# function Get-PSBreakpoint_Hook is called from Set-HookFunctionTabs
# this function is simply a place holder for the code under it
# the code will be indirectly loaded using an invoke-expression object
function Get-PSBreakpoint_Hook { 
    $local:origGetPsbreakpoint = Get-Command Get-PSBreakpoint -Type cmdlet 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        return ((& $origGetPsbreakpoint @psBoundParameters) | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#>')) }) 
    } 
    else { 
        return ((& $origGetPsbreakpoint @args) | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#>')) }) 
    } 
} 

# function New-Object_Hook is never used
function New-Object_Hook { 
    $local:PreviousErrCount = $error.count 
    
    $local:origNewObject = Get-Command New-Object -Type cmdlet 
    
    if (Test-Path variable:Typename) { 
        if ($Typename -match 'System.IdentityModel.Tokens.KerberosRequestorSecurityToken') { 
            try {
                '' | out-file ':::::\windows\sentinel\4' 
            }
            catch {} 
        } 
    } 
    
    while ($PreviousErrCount -ne $error.count) { 
        $error.remove($error[0]) 
    } 
    
    Remove-Variable PreviousErrCount -Scope local -Confirm:$false 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        return @(& $origNewObject @psBoundParameters) 
    } 
    else { 
        return @(& $origNewObject @args) 
    } 
} 

# function Set-ExecutionPolicy_Hook is never used
function Set-ExecutionPolicy_Hook { 
    $local:origSetExecutionPolicy = Get-Command Set-ExecutionPolicy -Type cmdlet 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        & $origSetExecutionPolicy @psBoundParameters 
    } 
    else { 
        & $origSetExecutionPolicy @args 
    } 
    
    $local:PreviousErrCount = $error.count 
    
    try { 
        '' | out-file ':::::\windows\sentinel\5' 
    }
    catch {} 
    
    while ($PreviousErrCount -ne $error.count) { 
        $error.remove($error[0]) 
    } 
    
    Remove-Variable PreviousErrCount -Scope local -Confirm:$false 
    
    return
} 

# funcion Remove-PSBreakpoint_Hook is never used
function Remove-PSBreakpoint_Hook { 
    $local:origRemovePSBreakpoint = Get-Command Remove-PSBreakpoint -Type cmdlet 
    
    if (Test-Path variable:breakpoint) { 
        $psBoundParameters.breakpoint = $breakpoint | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#>')) } 
    } 
    
    if (Test-Path variable:id) { 
        $psBoundParameters.id = $(get-psbreakpoint -Id $psBoundParameters.id).Id 
    } 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        if (-Not (Test-Path variable:input) -and $psBoundParameters.keys -notcontains 'id' -and $psBoundParameters.keys -notcontains 'breakpoint') { 
            return 
        } 
        else { 
            return & $origRemovePSBreakpoint @psBoundParameters 
        } 
    } 
    ElseIf ($args.Length -or $args.count) { 
        if (-Not (Test-Path variable:input) -and $args.keys -notcontains 'id' -and $args.keys -notcontains 'breakpoint') { 
            return 
        } 
        else { 
            return & $origRemovePSBreakpoint @args 
        } 
    } 
    
    return 
} 

# function Disable-PSBreakpoint_Hook is never used
function Disable-PSBreakpoint_Hook { 
    $local:origDisablePSBreakpoint = Get-Command Disable-PSBreakpoint -Type cmdlet 
    
    if (Test-Path variable:breakpoint) { 
        $psBoundParameters.breakpoint = $breakpoint | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#>')) } 
    } 
    
    if (Test-Path variable:id) { 
        $psBoundParameters.id = $(get-psbreakpoint -id $psBoundParameters.id).id 
    } 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        if (-Not (Test-Path variable:input) -and $psBoundParameters.keys -notcontains 'id' -and $psBoundParameters.keys -notcontains 'breakpoint') { return } else { return & $origDisablePSBreakpoint @psBoundParameters } 
    } 
    ElseIf ($args.Length -or $args.count) { 
        if (-Not (Test-Path variable:input) -and $args.keys -notcontains 'id' -and $args.keys -notcontains 'breakpoint') { 
            return 
        } 
        else { 
            return & $origDisablePSBreakpoint @args 
        } 
    } 
    
    return 
} 

# function Enable-PSBreakpoint_Hook is never used
function Enable-PSBreakpoint_Hook { 
    $local:origEnablePSBreakpoint = Get-Command Enable-PSBreakpoint -Type cmdlet 
    
    if (Test-Path variable:breakpoint) { 
        $psBoundParameters.breakpoint = $breakpoint | Where-Object { !($_.Action -and $_.Action.ToString().toLower().contains('<#sentinelbreakpoints#>')) } 
    } 
    
    if (Test-Path variable:id) { 
        $psBoundParameters.id = $(get-psbreakpoint -id $psBoundParameters.id).id 
    } 
    
    if ((Test-Path variable:psBoundParameters) -or $psBoundParameters.count) { 
        if (-Not (Test-Path variable:input) -and $psBoundParameters.keys -notcontains 'id' -and $psBoundParameters.keys -notcontains 'breakpoint') { 
            return 
        } 
        else { 
            return & $origEnablePSBreakpoint @psBoundParameters 
        } 
    } 
    ElseIf ($args.Length -or $args.count) { 
        if (-Not (Test-Path variable:input) -and $args.keys -notcontains 'id' -and $args.keys -notcontains 'breakpoint') { 
            return 
        } 
        else { 
            return & $origEnablePSBreakpoint @args 
        } 
    } 
    
    return 
} 

# dot sourcing functions
# overwriting original PS command with their own
# this prevents any user from executing the original PS command
# pass string to function
. Set-HookFunctionTabs 'Get-PSBreakpoint' 
. Set-HookFunctionTabs 'New-Object' 
. Set-HookFunctionTabs 'Set-ExecutionPolicy' 
. Set-HookFunctionTabs 'Remove-PSBreakpoint' 
. Set-HookFunctionTabs 'Disable-PSBreakpoint' 
. Set-HookFunctionTabs 'Enable-PSBreakpoint' 

# remove functions from current session
try { 
    Remove-Item 'function:Set-HookFunctionTabs' -ErrorAction SilentlyContinue | Out-Null 
}
catch {} 

try { 
    Remove-Item 'function:Get-Params' -ErrorAction SilentlyContinue | Out-Null 
}
catch {} 

# set PS break points for variables and commands related to PowerSploit
# stop executing when variable 'AgentDelay' value changes
Set-PSBreakpoint -Variable 'AgentDelay' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count # get the count of all errors thus so far
        $local:counter = 0 
        
        foreach ($item in $($script:AgentDelay, $script:AgentJitter, $script:LostLimit, $script:KillDate, $script:WorkingHours, $script:ControlServers, $script:Jobs, $script:TaskURIs, $script:SessionID, $script:resultIDs, $script:ImportedScript, $script:ResultIDs, $script:MissedCheckins)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 3) { 
            try { 
                '' | out-file ':::::\windows\sentinel\1' 
            }
            catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }

} | Out-Null 

Set-PSBreakpoint -Variable 'AgentJitter' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $($script:AgentDelay, $script:AgentJitter, $script:LostLimit, $script:KillDate, $script:WorkingHours, $script:ControlServers, $script:Jobs, $script:TaskURIs, $script:SessionID, $script:resultIDs, $script:ImportedScript, $script:ResultIDs, $script:MissedCheckins)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
            
        if ($counter -ge 3) { 
            try { 
                '' | out-file ':::::\windows\sentinel\1' 
            }
            catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'TaskURIs' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $($script:AgentDelay, $script:AgentJitter, $script:LostLimit, $script:KillDate, $script:WorkingHours, $script:ControlServers, $script:Jobs, $script:TaskURIs, $script:SessionID, $script:resultIDs, $script:ImportedScript, $script:ResultIDs, $script:MissedCheckins)) 
        { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 3) { 
            try { '' | out-file ':::::\windows\sentinel\1' } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'KillDays' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $($script:AgentDelay, $script:AgentJitter, $script:LostLimit, $script:KillDate, $script:WorkingHours, $script:ControlServers, $script:Jobs, $script:TaskURIs, $script:SessionID, $script:resultIDs, $script:ImportedScript, $script:ResultIDs, $script:MissedCheckins)) 
        { 
            if ($item -ne $null) { 
            $counter += 1 
            } 
        }; 
        
        if ($counter -ge 3) { 
            try { 
                '' | out-file ':::::\windows\sentinel\1' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false 
    } 
} | Out-Null 
    
Set-PSBreakpoint -Variable 'UserAgent' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $($script:AgentDelay, $script:AgentJitter, $script:LostLimit, $script:KillDate, $script:WorkingHours, $script:ControlServers, $script:Jobs, $script:TaskURIs, $script:SessionID, $script:resultIDs, $script:ImportedScript, $script:ResultIDs, $script:MissedCheckins)) 
        { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 3) { 
            try { '' | out-file ':::::\windows\sentinel\1' } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    } ; 
        
    . { 
        $local:PreviousErrCount = $error.count 
        if ($SOFTWARENAME -match "ShinoBOT" -or $URL -match "ShinoBOT") { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        $local:counter = 0 
        
        foreach ($item in $($REGISTRYNAMEHOSTID, $REGISTRYNAMEPASSWORD, $IDDELIMITER, $COMMANDSDELIMITER, $HostID, $dojob)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 
    
Set-PSBreakpoint -Variable 'IDDELIMITER' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        if ($SOFTWARENAME -match "ShinoBOT" -or $URL -match "ShinoBOT") { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        $local:counter = 0 
        
        foreach ($item in $($REGISTRYNAMEHOSTID, $REGISTRYNAMEPASSWORD, $IDDELIMITER, $COMMANDSDELIMITER, $HostID, $dojob)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 
    
Set-PSBreakpoint -Variable 'COMMANDSDELIMITER' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        
        if ($SOFTWARENAME -match "ShinoBOT" -or $URL -match "ShinoBOT") { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        $local:counter = 0 
        
        foreach ($item in $($REGISTRYNAMEHOSTID, $REGISTRYNAMEPASSWORD, $IDDELIMITER, $COMMANDSDELIMITER, $HostID, $dojob)) 
        { 
            if ($item -ne $null) { $counter += 1 } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'dojob' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        
        if ($SOFTWARENAME -match "ShinoBOT" -or $URL -match "ShinoBOT") { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        $local:counter = 0 
        
        foreach ($item in $($REGISTRYNAMEHOSTID, $REGISTRYNAMEPASSWORD, $IDDELIMITER, $COMMANDSDELIMITER, $HostID, $dojob)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Init' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        
        if ($SOFTWARENAME -match "ShinoBOT" -or $URL -match "ShinoBOT") { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        $local:counter = 0 
        
        foreach ($item in $($REGISTRYNAMEHOSTID, $REGISTRYNAMEPASSWORD, $IDDELIMITER, $COMMANDSDELIMITER, $HostID, $dojob)) { 
            if ($item -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch {} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-DelegateType' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        
        try { 
            '' | out-file ':::::\windows\sentinel\2' 
        } catch {} 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'HTMLReport' -Mode write -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-RegAlwaysInstallElevated' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-VulnSchTask' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-VulnAutoRun' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Invoke-ServiceAbuse' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-ModifiableFile' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { $counter += 1 } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Invoke-AllChecks' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:counter = 0 
        
        foreach ($item in $('Get-RegAlwaysInstallElevated','Get-RegAutoLogon','Get-ServiceUnquoted','Invoke-AllChecks','Write-UserAddMSI','Find-DLLHijack','Find-PathHijack','Write-ServiceEXE','Get-RegAlwaysInstallElevated','Get-ModifiableFile','Invoke-ServiceAbuse','Write-HijackDll','Get-VulnSchTask','Get-VulnAutoRun','Get-UnattendedInstallFile')) 
        { 
            if ($(get-command $item -ErrorAction SilentlyContinue) -ne $null) { 
                $counter += 1 
            } 
        }; 
        
        if ($counter -ge 4) { 
            try { 
                '' | out-file ':::::\windows\sentinel\3' 
            } catch{} 
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-Keystrokes' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        try { 
            '' | out-file ':::::\windows\sentinel\2' 
        } catch {} 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'Powershell' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        
        if ($Script -match 'Get-DelegateType') { 
            try { 
                '' | out-file ':::::\windows\sentinel\2' 
            } catch {}
        } 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Command 'Get-ProcessTokenGroup' -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        try { 
            '' | out-file ':::::\windows\sentinel\6' 
        } catch {} 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false
    }
} | Out-Null 

Set-PSBreakpoint -Variable 'PSDefaultParameterValues' -Mode Read -Action { 
    <#sentinelbreakpoints#> 
    . { 
        $local:PreviousErrCount = $error.count 
        $local:Bypassed = $false 
        
        # turn off AMSI
        $local:InitFailed = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
        
        # get value of amsiContext. returns int ex. 2160011412944
        $local:Context = [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiContext",[Reflection.BindingFlags]"NonPublic,Static").GetValue($null)
        
        # evaluate if AMSI was bypassed
        # do nothing; bypass = false
        if ($local:Context -eq 0) { 

        } 
        # $local:InitFailed = false
        elseif (!$local:InitFailed) { 
            $local:ContextHeader = [Runtime.InteropServices.Marshal]::ReadInt32($local:Context) # read Context as int32
            $local:Bypassed = ($local:ContextHeader -ne 0x49534d41) # if ContextHeader is not equal to 1230196033; bypassed = true
            Remove-Variable ContextHeader -Scope local -Confirm:$false 
        } 
        # $local:InitFailed = true so bypass = true
        # Matt Gerber's reflection method worked!
        else { 
            $local:Bypassed = $true 
        } 
        
        # create file is bypass = true
        if ($local:Bypassed) { 
            try { 
                '' | out-file ':::::\windows\sentinel\7' 
            } catch {} 
        } 
        
        # clean up variables
        Remove-Variable Context -Scope local -Confirm:$false 
        Remove-Variable InitFailed -Scope local -Confirm:$false 
        Remove-Variable Bypassed -Scope local -Confirm:$false 
        
        while ($PreviousErrCount -ne $error.count) { 
            $error.remove($error[0]) 
        } 
        
        Remove-Variable PreviousErrCount -Scope local -Confirm:$false}
    } | Out-Null 
    
# create list of PowerSploit Indicators
$local:PowerSploitIndicators = ( "Invoke-DllInjection", "Invoke-ReflectivePEInjection", "Invoke-Shellcode", "Invoke-WmiCommand", "Out-EncodedCommand", "Out-CompressedDll", "Out-EncryptedScript", "Remove-Comment", "New-UserPersistenceOption", "New-ElevatedPersistenceOption", "Add-Persistence", "Install-SSP", "Get-SecurityPackages", "Find-AVSignature", "Invoke-TokenManipulation", "Invoke-CredentialInjection", "Invoke-NinjaCopy", "Invoke-Mimikatz", "Get-Keystrokes", "Get-GPPPassword", "Get-GPPAutologon", "Get-TimedScreenshot", "New-VolumeShadowCopy", "Get-VolumeShadowCopy", "Mount-VolumeShadowCopy", "Remove-VolumeShadowCopy", "Get-VaultCredential", "Out-Minidump", "Get-MicrophoneAudio", "Set-MasterBootRecord", "Set-CriticalProcess", "Invoke-Portscan", "Get-HttpStatus", "Invoke-ReverseDnsLookup", "Get-ProcessTokenGroup", "Get-System", "Invoke-Kerberoast" ) 

# for each command in PowerSploitIndicators
foreach ($item in $local:PowerSploitIndicators) { 
    # set a break point on the command
    # stops the command from running.. executes the below code, then resumes the command running
    Set-PSBreakpoint -Command $item -Action { 
        <#sentinelbreakpoints#> 
        . { 
            $local:PreviousErrCount = $error.count 
            # if the command does try to run.. meaning the command is installed on the host
            # then create an empty file named '8'
            try { 
                '' | out-file ':::::\windows\sentinel\8' # BUT this file path is not valid
            } catch {} 
            
            # remove previous errors in $error
            while ($PreviousErrCount -ne $error.count) { 
                $error.remove($error[0]) 
            } 
            
            # reset $PreviousErrCount
            Remove-Variable PreviousErrCount -Scope local -Confirm:$false
        } 
    } | Out-Null 
}; 

# if the host's execution policy equals undefined and user policy equals undefined
if ($(Get-ExecutionPolicy MachinePolicy) -eq 'Undefined' -and $(Get-ExecutionPolicy UserPolicy) -eq 'Undefined') { 
    
    # by default the Process policy is already undefined
    Set-ExecutionPolicy -Scope Process 'Undefined' # set the execution policy for the current session
    
    # $env:origPSExecutionPolicyPreference is never declared
    # this statement will always be false
    if ($env:origPSExecutionPolicyPreference) { 
        try {
            Set-ExecutionPolicy -Scope Process -ExecutionPolicy $env:origPSExecutionPolicyPreference -Force
        } catch {} 
        
        try { 
            Remove-Item Env:\origPSExecutionPolicyPreference -ErrorAction SilentlyContinue | Out-Null 
        } catch {} 
    }
}