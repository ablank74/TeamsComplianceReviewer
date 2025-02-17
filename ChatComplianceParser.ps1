# Ensure Outlook is closed before running this script.
<# Powershell 5
Add-Type -Assembly "Microsoft.Office.Interop.Outlook"
$Outlook = New-Object -ComObject Outlook.Application
$Namespace = $Outlook.GetNamespace("MAPI")
#>

<#Powershell 7#>

# Instantiate the Outlook COM object
$outlookType = [Type]::GetTypeFromProgID("Outlook.Application")
$Outlook = [Activator]::CreateInstance($outlookType)
$Namespace = $Outlook.GetNamespace("MAPI")

# Load the PST file into Outlook
$PSTPath = "C:\Users\ABlank205\Downloads\ITSD-576547_Export\ITSD-576547_Export\10.19.2023-1516PM\Exchange\Exchange.pst"
$Namespace.AddStore($PSTPath)

# Find the PST in the folders list
$PSTRoot = $Namespace.Folders | Where-Object { $_.Name -eq "ITSD-576547" }

# Initialize results array
#$ParsedData = @()

# Recursive function to process messages in the TeamsMessageData folder
function ProcessTeamsFolder($folder) {
    $tmp = @()
    $j = 0
    foreach ($item in $folder.Items) {
        $j++
        $percent = $(($j/$folder.items.count)*100)
        Write-Progress -Activity "processing items" -PercentComplete $percent -ParentId 0 -Id 1 -Status "$j of $($folder.Items.Count)"
        
        if ($item.MessageClass -eq "IPM.SkypeTeams.Message") {
            if ($item.ConversationID -notin $parsedData.ConversationID){
                $group=@()
                $recipients = $(($item.Recipients |select -ExpandProperty address) -join "|")
                $group += $($item.Recipients |select -ExpandProperty address)
                $group += $item.SenderEmailAddress
                $group = $group -join "|"
                $tmp += [PSCustomObject]@{
                    'Sender' = $item.SenderEmailAddress
                    'Recipients' = $recipients
                    'Group'    = $group 
                    'User'     = $folder.Parent.Name
                    'Received' = $item.ReceivedTime
                    'Body'     = $item.Body
                    'ConversationID' = $item.ConversationID
                    'ConversationIndex' = $item.ConversationIndex
                    # Add other desired fields here
                }
            }
        }
    }
    return $tmp
}

# Process each user's TeamsMessageData folder
$parsedData = @()

$i = 0
foreach ($userFolder in $PSTRoot.Folders) {
    $i++
    $percent = $(($i/$PSTRoot.Folders.count)*100)
    Write-Progress -Activity "Parsing $($userFolder.Name) $i of $($pstRoot.Folders.count)" -PercentComplete $percent -Id 0 -Status "Items Count $($parsedData.count)"
    $teamsFolder = $userFolder.Folders | Where-Object { $_.Name -eq 'TeamsMessagesData' }
    if ($teamsFolder) {
        $parsedData += ProcessTeamsFolder($teamsFolder)
    }
}
Write-Progress -Activity "Parsing $($userFolder.Parent.Name)" -Completed

$parsedData.Count
$($parsedData | select ConversationID -Unique).count

# Export results to CSV
$ParsedData | sort Received | Export-Csv -Path "C:\Temp\Chatoutput.csv" -NoTypeInformation

$alldata = $parsedData

$parsedData | select group -Unique

# Remove the PST from Outlook (disconnect it)
#$Namespace.RemoveStore($PSTRoot)

# Close Outlook
#$Outlook.Quit()
$parsedData | group Group | sort Count