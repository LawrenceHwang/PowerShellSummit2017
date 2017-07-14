<#
    Stage 1. Build
#>
$demopath       = "$env:USERPROFILE\OneDrive\Code\github\PowerShellSummit2017"
$StackName      = 'PowerShellSummit2017Demo'
$AWSProfileName = 'myaws'
$AWSRegion      = 'us-west-2'
$KeyName        = 'powershellsummit2017'

# Push CFN
Initialize-AWSDefaults -ProfileName "$AWSProfileName"
Set-DefaultAWSRegion -Region $AWSRegion
(New-EC2KeyPair -KeyName $KeyName -Verbose).KeyMaterial | Out-File "$DemoPath\$KeyName.pem"
$ImageId = Get-EC2ImageByName -Name windows_2016_base | Select-Object -ExpandProperty ImageId
$TemplateBody = get-content -Path "$DemoPath\EC2.json" -Raw
Test-CFNTemplate -TemplateBody $TemplateBody

$param = @(
  @{ ParameterKey = "ec2instanceInstanceType"; ParameterValue = "t2.micro" },
  @{ ParameterKey = "ec2instanceImageId"; ParameterValue = "$ImageID" },
  @{ ParameterKey = "KeyName"; ParameterValue = "$KeyName"}
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
  Write-Output "******** $count ********`n`n"
  $count++
}

break # End of Stage 1.



<#
    Stage 2. Test and Validate for our opinions against the infrastructure.
        - Testing for resource deployment
        - Testing for resource relationship
        - Testing for things that shouldn't be there
        - Testing for integration (e.g. IIS site)
#>

#Run Pester
Invoke-Pester -Script @{ Path = "$demopath\Demo.tests.ps1" ; Parameters = @{ CfnStackName = "$StackName" }} -OutputFile $DemoPath\ValidationReport\ValidationResult.xml -OutputFormat NUnitXml

# Parse the XML into human friendly HTML report
& $demopath\ReportUnit.exe $demopath\ValidationReport\ValidationResult.xml
Invoke-Item $demopath\ValidationReport\ValidationResult.html

break

# Bonus: Reduce the time to initiate RDP connection.
. $demopath\get-ec2windows.ps1
. $demopath\Connect-EC2Windows.ps1
get-ec2windows -CertFolderPath $demopath
get-ec2windows | Connect-EC2Windows -CertFolderPath $demopath

break # End of Stage 2.



<#
    Stage 3. Tear Down
#>
Remove-CFNStack -StackName $StackName -Verbose -Force
Remove-EC2KeyPair -KeyName $KeyName -Verbose -Force
Remove-item -Path "$DemoPath\$KeyName.pem" -Verbose -Force

break # End of Stage 3.