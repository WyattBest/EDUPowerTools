Import-Module ActiveDirectory

######## Environment variables
$AzGroup = "<guid>" # ObjectId of Azure group
$SecurityGroup = "MyGroup" # Name of AD group

######## Establish connection to Azure
# There are better ways to do this, such as passing in credentials from Azure secure storage at runtime
$password = "a secure password" | ConvertTo-SecureString -asPlainText -Force
$azdcred = New-Object PSCredential "account@domain.edu", $password
Connect-AzureAD -Credential $azdcred

######## Get contents of AD and Azure groups
try {
    $Group = Get-ADGroup $SecurityGroup
    $ADUsers = Get-ADGroupMember -Identity $Group -Recursive | Get-ADUser #| Get-AzureADUser -ObjectId {$_.UserPrincipalName} | Select-Object -Property UserPrincipalName, ObjectId
    Write-Output ""
    Write-Output "AD Users"
    Write-Output "--------"
    Write-Output $ADUsers.Length
    Write-Output ""
    # $ADUsers | Where-Object {$_.UserPrincipalName -eq 'wbest@mcny.edu'} # Debug

    $AzureUsers = Get-AzureADGroupMember -ObjectId $AzGroup -All $true | Select-Object -Property UserPrincipalName, ObjectId
    Write-Output "Azure AD Users"
    Write-Output "---------"
    Write-Output $AzureUsers.Length
    Write-Output ""
}
catch {
    throw $_
}

######## Compare contents as arrays and make necessary adjustments
if (($null -ne $ADUsers) -and ($null -ne $AzureUsers)) {
    $comparedefault = Compare-Object -ReferenceObject $ADUsers -DifferenceObject $AzureUsers

    Write-Output "Group Comparison Results"
    Write-Output "---------"
    Write-Output $comparedefault
    Write-Output ""
    
    if ($comparedefault.SideIndicator -eq "<=") {
        foreach ($User in $comparedefault.InputObject) {
            Add-AzureADGroupMember -ObjectId $AzGroup -RefObjectId $User.ObjectId
            Write-Output "$User added to Azure group."
        }

    }
    elseif ($comparedefault.SideIndicator -eq "=>") {
        foreach ($User in $comparedefault.InputObject) {
            Remove-AzureADGroupMember -ObjectId $AzGroup -MemberId $User.ObjectId
            Write-Output "$User removed from Azure group."
        }

    }
    else {
        Write-Output "No changes to make."
    }
}
elseif ($null -eq $AzureUsers) {
    foreach ($User in $ADUsers) {
        Add-AzureADGroupMember -ObjectId $AzGroup -RefObjectId $User.ObjectId
        Write-Output "$User added to Azure group."
    }
}
elseif ($null -eq $ADUsers) {
    foreach ($User in $AzureUsers) {
        Remove-AzureADGroupMember -ObjectId $AzGroup -MemberId $User.ObjectId
        Write-Output "$User removed from Azure group."
    } 
}
