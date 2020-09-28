function Restore-Terminal {
    [CmdletBinding()]param()

    $Restore = Get-ChildItem "$Env:APPDATA\restore.*.clixml" | Where-Object { 
        $process = Get-Process -Id ($_.Name.Split('.')[1]) -ErrorAction SilentlyContinue
        -not $_.FullName.Contains($Pid.ToString()) -and $null -eq $process
    } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    if (-not $Restore)
    {
        return
    }

    $Terminal = Import-Clixml -Path $Restore.FullName

    Write-Verbose "Restoring from checkpoint: $($Restore.FullName)"
    Write-Verbose "Restoring terminal location: $($Terminal.Location)"

    Remove-Item $Restore.FullName

    Set-Location $Terminal.Location 
    $Terminal.Variables | ForEach-Object {
        try {
            Set-Variable -Name $_.Name -Value $_.Value -ErrorAction SilentlyContinue -Scope "Global"
        } catch {}
    }
    $Terminal.Modules | ForEach-Object { 
        Import-Module $_.Path -Scope "Global"
    }
}

function Clear-TerminalCheckpoint {
    $Checkpoints = Get-ChildItem "$Env:APPDATA\restore.*.clixml"

    if ($Checkpoints.Length -gt 10) {
        $Checkpoints | Sort-Object -Property LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item
    }
}

function Checkpoint-Terminal {
    $state = @{
        Location = (Get-Location).ToString()
        Variables = Get-Variable -Scope "Global" | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
        Modules = Get-Module | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Path = $_.Path } }
    }

    Start-Job -ScriptBlock {
       $args[0]  | Export-Clixml -Path "$Env:AppData\restore.$pid.clixml"
    } -ArgumentList $state
}

$Host.Runspace.add_AvailabilityChanged({Checkpoint-Terminal})
Clear-TerminalCheckpoint