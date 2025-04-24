# PowerShell script to export Yammer groups, members, and admins
# Token hint: https://support.office.com/en-us/article/export-yammer-group-members-to-a-csv-file-201a78fd-67b8-42c3-9247-79e79f92b535#step2
# Token hint2: https://www.yammer.com/client_applications
# Remember to clean up token & revert Content Mode when complete
# BEFORE RUN THE SCRIPT, PLEASE RUN: Install-Module Microsoft.Graph -Scope CurrentUser 
# THEN RUN: Connect-MgGraph
# THEN RUN:     Connect-MgGraph -Scopes "Group.Read.All"


# Set variables
$Token = “INSERT DEV TOKEN HERE”
$Headers = @{
    "Authorization" = "Bearer" + $Token
}

# Initialize variables
$YammerGroups = @()
$GroupAdmins = @()
$GroupMembers = @()
$GroupSummary = @()
$OutputCollection = @()  # Inicializar a variável

# Get a list of Yammer groups. Calls in pages as each search is limited to 50 results
$GroupCycle = 1
DO {
    $GetMoreGroupsUri = "https://www.yammer.com/api/v1/groups.json?page=$GroupCycle"
    Write-Host ($GetMoreGroupsUri)
    $MoreYammerGroups = (Invoke-WebRequest -Uri $GetMoreGroupsUri -Method Get -Headers $Headers).Content | ConvertFrom-Json
    $YammerGroups += $MoreYammerGroups
    $GroupCycle++
} While ($MoreYammerGroups.Count -gt 0)

$YammerGroups | Export-Csv group-export.csv -NoTypeInformation
$YammerGroups | Select type, id, full_name, privacy, created_at

# For each group, list the members and the admins. Calls in pages as each search is limited to 50 results
foreach ($group in $YammerGroups) {
    $GroupId = $group.id
    [string]$GroupCreatedAt = $group.created_at
    $GroupCycle = 1
    $AdminCount = 0
    $GroupCount = 0
    DO {
        $GetGroupMembersUri = "https://www.yammer.com/api/v1/groups/$GroupId/members.json?page=$GroupCycle"
        Write-Host ("REST API CALL : $GetGroupMembersUri")
        $MoreGroupMembers = ((Invoke-WebRequest -Uri $GetGroupMembersUri -Method Get -Headers $Headers).Content | ConvertFrom-Json).users | Select @{N='group_id';E={$group.id}}, @{N='group_name';E={$group.full_name}}, @{N='group_privacy';E={$group.privacy}}, @{N='group_show_in_directory';E={$group.show_in_directory}}, @{N='group_created_at';E={$GroupCreatedAt}}, type, @{N='user_id';E={$_.id}}, full_name, email, state, is_group_admin
        foreach ($member in $MoreGroupMembers) {
            if ($member.is_group_admin -eq "True") {
                $GroupAdmins += $member
                $AdminCount++
            }
            $GroupMembers += $member
            $GroupCount++
        }
        $GroupCycle++
    } While ($MoreGroupMembers.Count -gt 0)
    
    $groupResult = @{
        Group_Name = $group.full_name
        ID = $group.id
        State = $group.state
        Privacy = $group.privacy
        Show_In_Directory = $group.show_in_directory
        Created = $group.created_at
        Member_Count = $GroupCount
        Admin_Count = $AdminCount
        MgGroupOwner = $ownerDetails.UserPrincipalName
    }
    $groupObject = New-Object -TypeName PSObject -Property $groupResult
    $GroupSummary += $groupObject
    $OutputCollection += $groupObject  # Preencher a variável
    Write-Output $groupObject

    # Get group owners using Microsoft Graph API
    $groupName = $group.full_name
    $group = Get-MgGroup -Filter "displayName eq '$groupName'"
    if ($group) {
        $owners = Get-MgGroupOwner -GroupId $group.Id
        if ($owners) {
            Write-Host "Owners of '$groupName':"
            foreach ($owner in $owners) {
                $ownerDetails = Get-MgUser -UserId $owner.Id
                Write-Host "- $($ownerDetails.DisplayName) ($($ownerDetails.UserPrincipalName))"
            }
        }
    }
}

# Export the results to CSV files
$GroupSummary | Select Group_Name, ID, State, Privacy, Show_In_Directory, Created, Member_Count, Admin_Count, MgGroupOwner| Export-Csv group-summary.csv -NoTypeInformation
$GroupAdmins | Export-Csv group-admin-export.csv -NoTypeInformation
$GroupMembers | Export-Csv group-member-export.csv -NoTypeInformation

# Export the results to a single CSV file
$date = Get-Date -Format "yyyyMMdd"
$filename = "$date-YAMMER"
#INSERT THE PATH TO SAVE THE CSV HERE
$OutputCollection | Export-Csv "" -NoTypeInformation


