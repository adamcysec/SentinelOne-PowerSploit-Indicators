# SentinelOne-PowerSploit-Indicators
While working in a SOC, I encountered several alerts for mimikatz activity. Upon further analysis, the mimikatz activity turned out to be a PowerShell script that simply contained the string 'mimikatz' and other references to red team tools. 

Script file `s1_powersploit_indicators_script.ps1` contains all of the PS code I could find and I encourage you to start reading this file. 

<h2>The Script Puzzle Pieces</h2>
After preforming log searches around the activity seen in the alerts, I found 3 logs that show the complete SentinelOne PowerShell script.  
<br><br/>
Adam's SentinelOne PowerSploit Indicator Script was pieced together after finding the following PowerShell logs:

1)  [part1_S1_PS_script_block_log.txt](https://raw.githubusercontent.com/adamcysec/SentinelOne-PowerSploit-Indicators/main/part1_S1_PS_script_block_log.txt) : Windows PowerShell Scriptblock log; event id 4104

2) [part2_S1_PS_script_block_log.txt](https://raw.githubusercontent.com/adamcysec/SentinelOne-PowerSploit-Indicators/main/part2_S1_PS_script_block_log.txt) : Windows PowerShell Scriptblock log; event id 4104  

3) [part3_S1_PS_script_block_log.txt](https://raw.githubusercontent.com/adamcysec/SentinelOne-PowerSploit-Indicators/main/part3_S1_PS_script_block_log.txt) : Windows PowerShell Scriptblock log; event id 4104 

senstive information has been redacted.

<h2>.PS1 Files Overview</h2>

Within this repository, I have prepared 3 different files for analysis:

1) [s1_powersploit_indicators_script.ps1](https://github.com/adamcysec/SentinelOne-PowerSploit-Indicators/blob/main/s1_powersploit_indicators_script.ps1)

    - This is the original PowerShell script that was pieced together from log messages
    - All line numbers listed in this readme reference code in this file
 
2) [s1_powersploit_indicators_deob_script.ps1](https://github.com/adamcysec/SentinelOne-PowerSploit-Indicators/blob/main/s1_powersploit_indicators_deob_script.ps1)

    - This is the original PowerShell script after removing the basic obfuscation techniques
        - The base64 has been decoded
        - Any PowerShell aliases were rewritten in their long form name

3) [s1_powersploit_indicators_deob_comments_script.ps1](https://github.com/adamcysec/SentinelOne-PowerSploit-Indicators/blob/main/s1_powersploit_indicators_deob_comments_script.ps1)

    - This is the deobfuscated script with my comments added to help explain the activity seen


<h2>Script Execution Overview</h2>
This section describes the actions preformed by the script in the order they occur.

1) Executes hook function calls starting on line 269
    - Calls function `Set-HookFunctionTabs` - line 71
        - Calls function Get-Params - line 3
        - Loads the hook function in the current session - line 88

2) Executes every `Set-PSBreakpoint` command starting on line 286
    - Sets up breakpoints on various commands that might execute and various variables that might change in the current session

3) Variable `$local:PowerSploitIndicators` is declared - line 871
    - Contains list of strings for various malicious commands

4) Executes a for-loop to set up more PSBreakpoints for each command in `$local:PowerSploitIndicators` - line 873

5) Changes the ExecutionPolicy for the current session to undefined - line 892
    - 'Undefined' is the default execution policy for a session

<h2>What Even is the Point of this Script??</h2>

So far all the script does is setup hook functions and setup PS break points. 

If those break points fire, they will try to output a file. 

**So what is the point of this script?**

Well.. lets assume this script loads in the background every time a new PS session is started.

The hook functions prevent an actor from using the following commands in the session:

    Get-PSBreakpoint
    New-Object
    Set-ExecutionPolicy
    Remove-PSBreakpoint
    Disable-PSBreakpoint
    Enable-PSBreakpoint

This is key, because without these functions you can't mess with the PS break points or create new objects with command New-Object.

If any of the commands are executed or variables changed that this script is looking for, then a new file is created. 

**My theory** is that this script is simply checking for malicious commands executed in the current session. Then another process checks for these new files.


<h2>The Mysterious File Path</h2>

Every Set-PSBreakpoint command has the potential to create a new blank file in directory path `":::::\windows\sentinel\1"` 

You can see command `'' | out-file ':::::\windows\sentinel\1'` in every Set-PSBreakpoint on lines: 300, 328, 355, 362, 381, 407, 475, 499, 532, 565, 583, 609, 636, 663, 690, 717, 742, 769, 786, 804, 821, 856, 879.

**Wait! what is this file path reference?!**

`":::::\windows\sentinel\1"`

Why are there 5 colons in the front of the path?? 

Executing this command by itself returns an error in PS. 

Error: `out-file : The given path's format is not supported.`

However.. for the sake of this analysis. Lets assume the file path was correct and a new file was made.

### Below is a mapping of which `Set-PSBreakpoint` commands output what files:

	Set-PSBreakpoint -Variable 'AgentDelay' -Mode write
	Set-PSBreakpoint -Variable 'AgentJitter' -Mode write
	Set-PSBreakpoint -Variable 'TaskURIs' -Mode write
	Set-PSBreakpoint -Variable 'KillDays' -Mode write
	Set-PSBreakpoint -Variable 'UserAgent' -Mode write

Eval: checks for specific variables being used.

'' | out-file ':::::\windows\sentinel\1'

---------------------------------------------
	Set-PSBreakpoint -Variable 'IDDELIMITER' -Mode write
	Set-PSBreakpoint -Variable 'COMMANDSDELIMITER' -Mode write
	Set-PSBreakpoint -Variable 'dojob' -Mode write
	Set-PSBreakpoint -Command 'Init'
	Set-PSBreakpoint -Variable 'HTMLReport' -Mode write
	Set-PSBreakpoint -Command 'Get-RegAlwaysInstallElevated'
	Set-PSBreakpoint -Command 'Get-VulnSchTask'
	Set-PSBreakpoint -Command 'Get-VulnAutoRun'
	Set-PSBreakpoint -Command 'Invoke-ServiceAbuse'
	Set-PSBreakpoint -Command 'Get-ModifiableFile'
	Set-PSBreakpoint -Command 'Invoke-AllChecks'
	
Eval: checks for ShinoBot
or
Eval: checks for commands installed 

'' | out-file ':::::\windows\sentinel\3'

---------------------------------
	Set-PSBreakpoint -Command 'Get-DelegateType'
	Set-PSBreakpoint -Command 'Get-Keystrokes'
	Set-PSBreakpoint -Variable 'Powershell'

'' | out-file ':::::\windows\sentinel\2'

--------------------------------
	Set-PSBreakpoint -Command 'Get-ProcessTokenGroup'

'' | out-file ':::::\windows\sentinel\6'

-----------------------------------
	Set-PSBreakpoint -Variable 'PSDefaultParameterValues' -Mode Read
	
'' | out-file ':::::\windows\sentinel\7'

---------------------------------------
	Set-PSBreakpoint -Command $local:PowerSploitIndicators

'' | out-file ':::::\windows\sentinel\8'

<br></br>
Returning back to **my theory** from before. If another process is checking for these files, then what are they used for?

The unknown of what these files are used for makes this script mysterious.

Are they simply for creating a report? What about the multiple Set-PSBreakpoints that create the same file?

<h2>([SySTEM.CoNVErT]::fROMbaSe64STriNg ..WUT WUT</h2>

You will obviously notice the giant 2,317 character blob of base64 encoded text on lines 838 and 840.

I have decoded both of these for you using CyberChef

[Line: 838](https://gchq.github.io/CyberChef/#recipe=From_Base64('A-Za-z0-9%2B/%3D',true,false)Remove_null_bytes()&input=SXdCTkFHRUFkQUIwQUNBQVJ3QnlBR0VBWlFCaUFHVUFjZ0J6QUNBQVVnQmxBR1lBYkFCbEFHTUFkQUJwQUc4QWJnQWdBRzBBWlFCMEFHZ0Fid0JrQUNBQUNnQmJBRklBWlFCbUFGMEFMZ0JCQUhNQWN3QmxBRzBBWWdCc0FIa0FMZ0JIQUdVQWRBQlVBSGtBY0FCbEFDZ0FJZ0FrQUNnQVd3QkRBRWdBUVFCeUFGMEFLQUE0QURNQUtRQXJBRnNBUXdCb0FHRUFVZ0JkQUNnQVd3QkNBRmtBZEFCbEFGMEFNQUI0QURjQU9RQXBBQ3NBV3dCREFFZ0FRUUJ5QUYwQUtBQmJBR0lBV1FCVUFFVUFYUUF3QUhnQU53QXpBQ2tBS3dCYkFFTUFhQUJCQUhJQVhRQW9BREVBTVFBMkFDc0FOUUE1QUMwQU5RQTVBQ2tBS3dCYkFFTUFTQUJoQUZJQVhRQW9BRnNBWWdCNUFIUUFaUUJkQURBQWVBQTJBRFVBS1FBckFGc0FZd0JvQUdFQVVnQmRBQ2dBV3dCaUFGa0FWQUJGQUYwQU1BQjRBRFlBWkFBcEFDc0FXd0JEQUVnQVFRQlNBRjBBS0FBMEFEWUFLZ0F5QURrQUx3QXlBRGtBS1FBckFGc0FZd0JvQUdFQWNnQmRBQ2dBTndBM0FDa0FLd0JiQUVNQWFBQmhBRklBWFFBb0FGc0FRZ0JaQUZRQVpRQmRBREFBZUFBMkFERUFLUUFyQUZzQVl3QklBRUVBVWdCZEFDZ0FOUUEwQUNzQU5RQTJBQ2tBS3dCYkFHTUFTQUJoQUZJQVhRQW9BRGdBTkFBckFERUFNd0FwQUNzQVd3QkRBR2dBWVFCU0FGMEFLQUJiQUdJQVdRQlVBR1VBWFFBd0FIZ0FOZ0EzQUNrQUt3QmJBRU1BYUFCQkFISUFYUUFvQUZzQVlnQjVBSFFBUlFCZEFEQUFlQUEyQURVQUtRQXJBRnNBWXdCb0FFRUFjZ0JkQUNnQVd3QmlBRmtBVkFCRkFGMEFNQUI0QURZQVpBQXBBQ3NBV3dCakFFZ0FZUUJ5QUYwQUtBQmJBR0lBZVFCVUFFVUFYUUF3QUhnQU5nQTFBQ2tBS3dCYkFHTUFTQUJoQUhJQVhRQW9BRnNBUWdCNUFIUUFSUUJkQURBQWVBQTJBR1VBS1FBckFGc0FZd0JvQUdFQVVnQmRBQ2dBV3dCQ0FIa0FWQUJsQUYwQU1BQjRBRGNBTkFBcEFDa0FMZ0JCQUhVQWRBQnZBRzBBWVFCMEFHa0Fid0J1QUM0QUpBQW9BQ2NBd2dCdEFITUE3Z0JWQUhRQTdBQnNBSE1BSndBdUFFNEFid0J5QUcwQVFRQnNBRWtBV2dCbEFDZ0FXd0JEQUVnQVFRQnlBRjBBS0FBM0FEQUFLUUFyQUZzQVF3QklBR0VBVWdCZEFDZ0FNUUF4QURFQUt3QXpBRGNBTFFBekFEY0FLUUFyQUZzQVF3Qm9BRUVBVWdCZEFDZ0FXd0JpQUhrQVZBQkZBRjBBTUFCNEFEY0FNZ0FwQUNzQVd3QmpBR2dBWVFCU0FGMEFLQUF4QURBQU9RQXBBQ3NBV3dCREFFZ0FRUUJ5QUYwQUtBQmJBRUlBZVFCMEFFVUFYUUF3QUhnQU5BQTBBQ2tBS1FBZ0FDMEFjZ0JsQUhBQWJBQmhBR01BWlFBZ0FGc0FRd0JJQUdFQVVnQmRBQ2dBT0FBekFDc0FPUUFwQUNzQVd3QmpBR2dBUVFCeUFGMEFLQUJiQUVJQWVRQjBBRVVBWFFBd0FIZ0FOd0F3QUNrQUt3QmJBR01BU0FCQkFGSUFYUUFvQURFQU1nQXpBQ2tBS3dCYkFHTUFhQUJCQUZJQVhRQW9BRGNBTndBcEFDc0FXd0JEQUVnQVlRQnlBRjBBS0FBekFEa0FLd0EzQURFQUtRQXJBRnNBUXdCSUFHRUFVZ0JkQUNnQVd3QmlBRmtBVkFCbEFGMEFNQUI0QURjQVpBQXBBQ2tBSWdBcEFDNEFSd0JsQUhRQVJnQnBBR1VBYkFCa0FDZ0FKQUFvQUZzQVl3Qm9BR0VBY2dCZEFDZ0FPUUEzQUNvQU53QTNBQzhBTndBM0FDa0FLd0JiQUVNQVNBQkJBRklBWFFBb0FERUFNQUE1QUNzQU1RQXdBREFBTFFBeEFEQUFNQUFwQUNzQVd3QkRBR2dBWVFCeUFGMEFLQUF4QURFQU5RQXBBQ3NBV3dCakFFZ0FRUUJTQUYwQUtBQmJBRUlBV1FCVUFFVUFYUUF3QUhnQU5nQTVBQ2tBS3dCYkFHTUFTQUJoQUhJQVhRQW9BRnNBWWdCNUFIUUFSUUJkQURBQWVBQTBBRGtBS1FBckFGc0FZd0JJQUVFQVVnQmRBQ2dBV3dCaUFGa0FkQUJsQUYwQU1BQjRBRFlBWlFBcEFDc0FXd0JEQUVnQVFRQnlBRjBBS0FBeEFEQUFOUUFyQURFQU53QXRBREVBTndBcEFDc0FXd0JEQUdnQVFRQlNBRjBBS0FCYkFHSUFlUUIwQUVVQVhRQXdBSGdBTndBMEFDa0FLd0JiQUdNQVNBQmhBRklBWFFBb0FGc0FRZ0I1QUZRQVpRQmRBREFBZUFBMEFEWUFLUUFyQUZzQVl3QklBRUVBY2dCZEFDZ0FXd0JpQUhrQVZBQmxBRjBBTUFCNEFEWUFNUUFwQUNzQVd3QkRBRWdBUVFCeUFGMEFLQUF4QURBQU5RQXBBQ3NBV3dCREFFZ0FRUUJ5QUYwQUtBQmJBRUlBZVFCVUFHVUFYUUF3QUhnQU5nQmpBQ2tBS3dCYkFHTUFTQUJCQUhJQVhRQW9BRnNBUWdCNUFIUUFaUUJkQURBQWVBQTJBRFVBS1FBckFGc0FRd0JJQUdFQVVnQmRBQ2dBV3dCaUFGa0FWQUJsQUYwQU1BQjRBRFlBTkFBcEFDa0FMQUFpQUU0QWJ3QnVBRkFBZFFCaUFHd0FhUUJqQUN3QVV3QjBBR0VBZEFCcEFHTUFJZ0FwQUM0QVJ3QmxBSFFBVmdCaEFHd0FkUUJsQUNnQUpBQnVBSFVBYkFCc0FDa0FPd0E9)

[Line: 840](https://gchq.github.io/CyberChef/#recipe=From_Base64('A-Za-z0-9%2B/%3D',true,false)Remove_null_bytes()&input=SXdCTkFHRUFkQUIwQUNBQVJ3QnlBR0VBWlFCaUFHVUFjZ0J6QUNBQWN3QmxBR01BYndCdUFHUUFJQUJTQUdVQVpnQnNBR1VBWXdCMEFHa0Fid0J1QUNBQWJRQmxBSFFBYUFCdkFHUUFJQUFLQUZzQVVnQmxBR1lBWFFBdUFFRUFjd0J6QUdVQWJRQmlBR3dBZVFBdUFFY0FaUUIwQUZRQWVRQndBR1VBS0FBaUFDUUFLQUJiQUdNQWFBQmhBRklBWFFBb0FGc0FZZ0I1QUhRQVJRQmRBREFBZUFBMUFETUFLUUFyQUZzQVl3QklBR0VBY2dCZEFDZ0FXd0JpQUhrQWRBQkZBRjBBTUFCNEFEY0FPUUFwQUNzQVd3QmpBRWdBUVFCeUFGMEFLQUJiQUVJQWVRQjBBRVVBWFFBd0FIZ0FOd0F6QUNrQUt3QmJBR01BU0FCaEFISUFYUUFvQUZzQVlnQlpBSFFBUlFCZEFEQUFlQUEzQURRQUtRQXJBRnNBWXdCb0FHRUFjZ0JkQUNnQVd3QmlBSGtBVkFCbEFGMEFNQUI0QURZQU5RQXBBQ3NBV3dCakFHZ0FZUUJTQUYwQUtBQXhBREFBT1FBckFERUFNQUF0QURFQU1BQXBBQ3NBV3dCakFHZ0FRUUJTQUYwQUtBQTBBRFlBS2dBeUFEWUFMd0F5QURZQUtRQXJBRnNBWXdCb0FHRUFjZ0JkQUNnQVd3QkNBRmtBZEFCRkFGMEFNQUI0QURRQVpBQXBBQ3NBV3dCakFHZ0FZUUJ5QUYwQUtBQmJBRUlBV1FCMEFFVUFYUUF3QUhnQU5nQXhBQ2tBS3dCYkFFTUFTQUJCQUhJQVhRQW9BRGtBTXdBckFERUFOd0FwQUNzQVd3QkRBR2dBUVFCeUFGMEFLQUE1QURjQUtRQXJBRnNBWXdCb0FHRUFjZ0JkQUNnQVd3QkNBRmtBVkFCbEFGMEFNQUI0QURZQU53QXBBQ3NBV3dCakFHZ0FZUUJ5QUYwQUtBQTRBRFVBS3dBeEFEWUFLUUFyQUZzQVF3QklBRUVBY2dCZEFDZ0FXd0JpQUhrQVZBQmxBRjBBTUFCNEFEWUFaQUFwQUNzQVd3QmpBRWdBWVFCU0FGMEFLQUJiQUdJQWVRQjBBRVVBWFFBd0FIZ0FOZ0ExQUNrQUt3QmJBRU1BU0FCaEFGSUFYUUFvQUZzQVlnQlpBSFFBWlFCZEFEQUFlQUEyQUdVQUtRQXJBRnNBUXdCb0FFRUFVZ0JkQUNnQU13QTJBQ3NBT0FBd0FDa0FLUUF1QUVFQWRRQjBBRzhBYlFCaEFIUUFhUUJ2QUc0QUxnQWtBQ2dBV3dCREFHZ0FRUUJTQUYwQUtBQmJBR0lBV1FCVUFFVUFYUUF3QUhnQU5BQXhBQ2tBS3dCYkFFTUFTQUJCQUZJQVhRQW9BRnNBWWdCNUFIUUFSUUJkQURBQWVBQTJBR1FBS1FBckFGc0FRd0JvQUVFQVVnQmRBQ2dBTVFBeEFEVUFLUUFyQUZzQVl3Qm9BR0VBY2dCZEFDZ0FOUUExQUNzQU5RQXdBQ2tBS3dCYkFFTUFhQUJCQUhJQVhRQW9BRnNBUWdCWkFGUUFaUUJkQURBQWVBQTFBRFVBS1FBckFGc0FRd0JJQUdFQVVnQmRBQ2dBTVFBeEFEWUFLZ0EzQURVQUx3QTNBRFVBS1FBckFGc0FZd0JJQUdFQVVnQmRBQ2dBV3dCaUFIa0FkQUJGQUYwQU1BQjRBRFlBT1FBcEFDc0FXd0JEQUVnQVFRQlNBRjBBS0FCYkFHSUFlUUIwQUdVQVhRQXdBSGdBTmdCakFDa0FLd0JiQUdNQWFBQkJBRklBWFFBb0FGc0FZZ0I1QUZRQVJRQmRBREFBZUFBM0FETUFLUUFwQUNJQUtRQXVBRWNBWlFCMEFFWUFhUUJsQUd3QVpBQW9BQ0lBSkFBb0FGc0FZd0JJQUdFQWNnQmRBQ2dBT1FBM0FDc0FOZ0F5QUMwQU5nQXlBQ2tBS3dCYkFFTUFTQUJoQUhJQVhRQW9BREVBTmdBckFEa0FNd0FwQUNzQVd3QkRBR2dBUVFCU0FGMEFLQUJiQUVJQWVRQjBBRVVBWFFBd0FIZ0FOd0F6QUNrQUt3QmJBR01BU0FCaEFGSUFYUUFvQUZzQVlnQjVBRlFBWlFCZEFEQUFlQUEyQURrQUtRQXJBRnNBWXdCb0FHRUFVZ0JkQUNnQVd3QkNBSGtBZEFCRkFGMEFNQUI0QURRQU13QXBBQ3NBV3dCREFHZ0FZUUJ5QUYwQUtBQmJBRUlBV1FCMEFFVUFYUUF3QUhnQU5nQm1BQ2tBS3dCYkFFTUFhQUJCQUZJQVhRQW9BRnNBWWdCNUFIUUFaUUJkQURBQWVBQTJBR1VBS1FBckFGc0FZd0JJQUdFQVVnQmRBQ2dBTVFBeEFEWUFLUUFyQUZzQVl3QklBR0VBVWdCZEFDZ0FNUUF5QUNzQU9BQTVBQ2tBS3dCYkFFTUFTQUJCQUhJQVhRQW9BREVBTWdBd0FDc0FNUUF5QUMwQU1RQXlBQ2tBS3dCYkFHTUFhQUJoQUhJQVhRQW9BRnNBUWdCWkFIUUFaUUJkQURBQWVBQTNBRFFBS1FBcEFDSUFMQUJiQUZJQVpRQm1BR3dBWlFCakFIUUFhUUJ2QUc0QUxnQkNBR2tBYmdCa0FHa0FiZ0JuQUVZQWJBQmhBR2NBY3dCZEFDSUFUZ0J2QUc0QVVBQjFBR0lBYkFCcEFHTUFMQUJUQUhRQVlRQjBBR2tBWXdBaUFDa0FMZ0JIQUdVQWRBQldBR0VBYkFCMUFHVUFLQUFrQUc0QWRRQnNBR3dBS1FBN0FBPT0)

Okay.. but now i see these `[chaR]([bytE]0x53` 

You can execute `[chaR]([bytE]0x53` directly into PS which will convert a byte into a character

After this conversion, you are left with..

Line 838: 
```	
#Matt Graebers Reflection method
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsilnitFailed','NonPublic,Static').SetValue($null,$true)
```

Line 840:
```
#Matt Graebers second Reflection method

[Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiContext",[Reflection.BindingFlags]"NonPublic,Static").GetValue($null)
```

You can view other variations of the Reflection method on [GetRektBoy724 Github Gist](https://gist.github.com/GetRektBoy724)

<h2>Is this Script Owned by SentinelOne?</h2>

Within every `Set-PSBreakpoint` command there is a code comment:  `<#sentinelbreakpoints#>`

And every `Out-File` command references parent directory `'' | out-file ':::::\windows\sentinel\'`

After searching around on SentienlOne's webisite, I found this article.. [What Is Windows PowerShell?](https://www.sentinelone.com/cybersecurity-101/windows-powershell/)

In this article, SentinelOne explains PowerShell and then explains how dangerous PowerShell can be. SentinelOne even mentions and links directly to the PowerSploit Github!!

And they of course recommend their SentinelOne agent to mitigate the scary PowerShell.

Coincidence! I think not!
