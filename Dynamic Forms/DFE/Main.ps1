# Status codes:
# 0: Success
# 1: Error found in DFE's stdout/stderr
# 2: Error log txt file created by DFE
# 3: PowerShell crash handled by catch block
$StatusCode = 0
$StatusMessage = $null
$StatusTrace = $null

try {
    $DFEexe = "C:\Program Files\NextGen\Dynamic Forms Exchange\NextGen.DynamicForms.Exchange.exe"
    $FileCabinet = 'C:\DFE\TestFC'
    Set-Location 'C:\DFE'

    # Load a list of forms to download. This list can be updated in Excel.
    $FormDefinitions = Import-CSV FormDefinitions.csv

    # Execute Dynamic Forms Exchange for each form in the list
    foreach ($Form in $FormDefinitions) {
        Switch ($Form.TypeFlag) {
            '/i' { $StyleSheetFlag = '/iss' }
            '/s' { $StyleSheetFlag = '/ss' }
        }

        if ($Form.TypeFlag -eq '/i' -and [System.Convert]::ToBoolean($Form.TestMode)) { $TestFlag = '/bypassimageupdate' }
        if ($Form.TypeFlag -eq '/s' -and [System.Convert]::ToBoolean($Form.TestMode)) { $TestFlag = '/bypassdataupdate' }
        # $SetStatusFlag = $null
        if ($Form.SetStatus) { $SetStatusFlag = '/updateformstatus' }
    
        $DFEArguments = @(
            "$($Form.TypeFlag) $($Form.FormId)"
            , "$StyleSheetFlag $($Form.XSLT)"
            , "/sl `"$($Form.OutputPath)`""
            , "/imagefilename $($Form.ImageFileName)"
            , $TestFlag
            , "/statuses $($Form.GetStatuses)"
            , $SetStatusFlag
            , "/updatedformstatusvalue $($Form.SetStatus)"
            , '/silent')
        $DFEArguments = $DFEArguments | Where-Object { $_ } # Get rid of null/empty parameters
        Write-Host $DFEArguments
        Start-Process -FilePath $DFEexe -ArgumentList $DFEArguments -RedirectStandardError 'stderr.tmp' -RedirectStandardOutput 'stdout.tmp' -Wait -NoNewWindow 
        
        # Check for error output
        $DFEOut = Get-Content 'stderr.tmp'
        $DFEOut += Get-Content 'stdout.tmp'
        if ($DFEOut -like '*error*') {
            $StatusCode = 1
            $StatusMessage += "Error detected in DFE process output. "
        }
        Write-Host $DFEOut
        
        # Check for error output files, set error code, and add timestamp to filenames
        $ErrorLogs = Get-ChildItem 'ErrorLog*'
        if ($ErrorLogs) {
            $Time = Get-Date -DisplayHint Time -Format 'HHmmss'
            $StatusCode = 2
            foreach ($File in $ErrorLogs) { Rename-Item -Path $File -NewName ($File.BaseName + '_' + $Time + '.txt') }

            # Set status message (with new filenames) and archive files
            $ErrorLogs = Get-ChildItem 'ErrorLog*'
            $StatusMessage += 'DFE process wrote error log ' + $ErrorLogs.Name
            foreach ($File in $ErrorLogs) { Move-Item -Path $File -Destination ('.\ArchivedErrorLogs\' + $ErrorLogs.Name) }
        }
    
    
        if ($Form.DeleteIndex -eq $true) {
            # Delete ImageIndex_*.txt files. Caution: this could delete index files from other forms placed in the same OutputPath
            Set-Location $Form.OutputPath
            Remove-Item * -Include "ImageIndex_*.txt"
        }

        if ($Form.Autofile -eq $true) {
            # Find new PDF's to file in File Cabinet
            Set-Location $Form.OutputPath
            $RawFiles = Get-ChildItem -Path .\ -Filter '*.pdf'

            foreach ($File in $RawFiles) {
                # Extract PEOPLE_CODE_ID from beginning of each PDF's filename
                $PCID = $File.Name.Substring(0, 11)
                Write-Host 'PCID:' $PCID

                # Search for student's folder in File Cabinet
                $DestFolder = Get-ChildItem ($PCID + '*') -Path $FileCabinet -Directory
                Write-Host 'Destination Folder:' $DestFolder

                # If folder was found, rename and move file
                if ($DestFolder) {
                    $NewPath = $FileCabinet + '\' + $DestFolder + '\' + $File.Name.Substring(11)
        
                    # Check for and avoid collisions with existing files
                    $i = 1
                    while (Test-Path $NewPath) {
                        $NewPath = $FileCabinet + '\' + $DestFolder + '\' + $File.BaseName.Substring(11) + $i + '.pdf'
                        $i += 1
                    }

                    Write-Host 'New Path:' $NewPath
                    Move-Item -Path $File -Destination $NewPath
        
                }
                Write-Host '----------------'
            }
        }
    }
}
catch {
    $StatusCode = 3
    $StatusMessage = $_.Exception
    $StatusTrace = $_.ScriptStackTrace
}
finally {
    # Zeros because, insanely enough, a blank will break Invoke-Sqlcmd
    Write-Host $StatusCode, $StatusMessage, $StatusTrace
    if (!$StatusMessage) { $StatusMessage = 0 }
    if (!$StatusTrace) { $StatusTrace = 0 }

    # Write a log entry to SQL
    # This curious way of passing the parameters is called splatting, and it's way cleaner than doing everything on one line
    # https://www.dbbest.com/blog/using-powershell-invoke-sqlcmd-with-variable/
    $SqlcmdVariables = @(
        "StatusCode=$($StatusCode)",
        "StatusMessage=$($StatusMessage)",
        "StatusTrace=$($StatusTrace)"
    )
    $SqlcmdParameters = @{
        Serverinstance    = "SERVER"
        Database          = "DATABASE"
        QueryTimeout      = 5
        ConnectionTimeout = 5
        EncryptConnection = $true
        Query             = "EXEC forms.insLogDFE '`$(StatusCode)', '`$(StatusMessage)', '`$(StatusTrace)'"
        Verbose           = $true
        Variable          = $SqlcmdVariables
    }
    
    Invoke-Sqlcmd @SqlcmdParameters
}
