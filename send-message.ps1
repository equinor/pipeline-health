<#
.SYNOPSIS
Formats the Github REST API result to a Slack Message Payload for the selected Channel.
.DESCRIPTION
Inbound JSON result is classified by conclusion state and formatted by a template that supports a tabular view https://app.slack.com/block-kit-builder/ -> text fields and mrkdwn.
#>
param (
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)]$runResults,
    [Parameter(Mandatory = $true)]$Uri
)

$ResultsObjects = $runResults | ConvertFrom-Json

$BlockObject = New-Object System.Collections.Generic.List[System.Object]

$i = 0
$j = -1
# The inbound Slack message is formatted to use text fields, which support only 6 fields (array objects) at a time. 
# This groups each section, and adds the array list to the parent array "blocks" and "attachments": attachments.blocks.fields
$ResultsObjects | ForEach-Object {
    $ii = ($i % 6)
    if ($ii -eq 0) {
        $j++
        $BlockObject.Add([PSCustomObject]@{
                type   = "section"
                fields = New-Object System.Collections.Generic.List[System.Object]
            })
    }
    $WorkflowName = $_.workflow_name
    $WorkflowConclusion = $_.workflow_conclusion
    $WorkflowStatus = $_.workflow_status
    $WorkflowUrl = $_.workflow_url

    # Some of the workflow names are too long, breaking the visual symmetry.
    if ($WorkflowName.Length -gt 35) {
        $WorkflowName = $WorkflowName.Substring(0, 35)
    }
  
    # Conclusion state by using emojis, since internal/privat github badges can't be read by external services.
    if ($WorkflowStatus -eq "completed") {
        if ($WorkflowConclusion -eq "success") {    
            $ResultObject = ":large_green_square: <$WorkflowUrl | $WorkflowName>"
            $WorkflowStatusRow = [pscustomobject]@{
                type = "mrkdwn"
                text = $ResultObject   
            }
        }
        else {
            $ResultObject = ":large_red_square: <$WorkflowUrl | $WorkflowName>"
            $WorkflowStatusRow = [pscustomobject]@{
                type = "mrkdwn"
                text = $ResultObject   
            }
        }

    }
    else {
        $ResultObject = ":large_yellow_square: <$WorkflowUrl | $WorkflowName>"
        $WorkflowStatusRow = [pscustomobject]@{
            type = "mrkdwn"
            text = $ResultObject   
        }
    }
    $i++

    $BlockObject[$j].fields.add($WorkflowStatusRow)
}

$BodyObjectified = [PSCustomObject]@{
    attachments = New-Object System.Collections.Generic.List[System.Object]
}

$BodyObjectified.attachments.Add([PSCustomObject]@{
        blocks = $BlockObject
    })

$Body = $BodyObjectified | ConvertTo-Json -Depth 100

try {
    Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType 'application/json'
}
catch { 
    Write-Warning "Unable to send message to Slack! Check JSON body or the following exception message:"
    Write-Error $_.Exception
}
