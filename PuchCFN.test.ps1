[CmdletBinding()]
param(
  [string]$CfnStackName
)
Initialize-AWSDefaults -ProfileName myaws
Set-DefaultAWSRegion 'us-west-2'
$stack = Get-CFNStack -StackName $CfnStackName
$SecurityGroup = Get-EC2SecurityGroup -filter @(@{name = 'tag:aws:cloudformation:stack-id'; values = $Stack.StackId})
$instance = get-ec2instance -filter @(@{name = 'tag:aws:cloudformation:stack-id'; values = $Stack.StackId})

Describe 'PowerShell Summit 2017 EC2 CloufFormation Deployment Validation' {
  It 'deploys one ec2 instance' {
    $instance.count | Should Be 1
  }
  It 'ec2 instance uses latest ami' {
    $LatestImageId = Get-EC2ImageByName -Name windows_2016_base | Select-Object -ExpandProperty ImageId
    $instance.instances.ImageId | Should Be "$LatestImageId"
  }
  It 'starts the ec2 instance' {
    $instance.Instances.State.Name | Should Be 'Running'
  }
  It 'attaches a public IP to the instance' {
    $instance.instances.PublicIpAddress | Should Match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"
  }
  It 'creates one security group' {
    $SecurityGroup.count | Should Be 1
  }
  It 'attaches the created security group to the instance' {
    $instance.Instances.SecurityGroups.GroupId | Should Be $SecurityGroup.GroupId
  }
  It 'has no instance iam role' {
    $instance.Instances.IamInstanceRole | Should Be $null
  }
  It 'the IIS default site is accessible' {
    $uri = $instance.instances.PublicIpAddress
    $HttpStatusCode = (Invoke-WebRequest -Uri $URI).statuscode
    $HttpStatusCode | Should Be 200
  }
}