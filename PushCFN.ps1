Initialize-AWSDefaults -ProfileName myaws
Set-DefaultAWSRegion -Region 'us-west-2'

$Template = "$env:USERPROFILE\OneDrive\Code\github\PowerShellSummit2017\EC2.yaml"
$TemplateBody = get-content -Path $Template -Raw
Test-CFNTemplate -TemplateBody $TemplateBody -OutVariable cfn

$ImageId = Get-EC2ImageByName -Name windows_2016_base | Select-Object -ExpandProperty ImageId
$StackName  = 'PowerShellSummit2017Demo'
$param = @(
  @{ ParameterKey = "ec2instanceInstanceType"; ParameterValue = "t2.micro" },
  @{ ParameterKey = "ec2instanceImageId"; ParameterValue = "$ImageID" },
  @{ ParameterKey = "KeyName"; ParameterValue = "powershellsummit2017"}
)
function Test-CFNTemplateResult {
  [CmdletBinding()]
  [Alias()]
  [OutputType([bool])]
  param([parameter (Mandatory = $true)][string]$templateBody)

  try {
    Test-CFNTemplate -TemplateBody $TemplateBody
    return $true
  }
  catch {
    Write-Warning "CFN issue $($error[-1].exception)"
    return $false
  }
}

if (Test-CFNTemplateResult -templatebody $TemplateBody) {
  New-CFNStack -Parameter $param -StackName $StackName -TemplateBody $TemplateBody -Capability CAPABILITY_IAM -Verbose
}

Add-Type -AssemblyName System.speech
$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speak.Speak("Stack creation started.")

$count = 1
while ($true) {

  Get-CFNStackEvent -StackName $StackName | Select-Object resourcetype, resourcestatus, timestamp
  if ((Get-CFNStack -StackName $stackname).StackStatus.Value -like '*complete*') {
    $speak.Speak("The stack is now created")
    break
  }

  Start-Sleep 5
  Write-Output "******** $count ********"
  $count++
}