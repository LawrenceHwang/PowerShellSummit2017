Function Get-EC2Windows {
  <#
    .SYNOPSIS
      Retrieve certain EC2 instance information for all Windows EC2 instances.
    .DESCRIPTION
      Following information are gathered.
        Name
        StackName
        PrivateIP
        PublicIP
        KeyName
        InstanceID
        Password
      The scope is limited to the currently configured (in PowerShell) AWS account and region.
    .EXAMPLE
      PS C:\> Get-EC2Windows
          Name       : App1
          StackName  : appstack
          PrivateIP  : 10.129.10.10
          PublicIP   :
          KeyName    : prod
          InstanceID : i-0b584000926cbbbbb
          Password   :


          Name       : prod1
          StackName  : prodwindows1
          PrivateIP  : 10.129.142.49
          PublicIP   :
          KeyName    : prod
          InstanceID : i-08751e56a782bbbbb
          Password   :

    .NOTES

    .LINK
  #>
  [CmdletBinding()]
  Param(
    [string]$CertFolderPath,
    [switch]$GetLocalAdminPassword
  )

  Begin {
    Write-Verbose 'Getting instances'
    try {
      $instances = Get-EC2instance -Filter @(@{name = 'platform'; value = 'windows'}) -ErrorAction Stop
    }
    catch {
      Write-Warning 'Can not retrieve EC2 instance information.'
      throw
    }

    Write-Verbose "Total instance received: $(($instances).count)"
  }
  Process {
    foreach ($i in $instances) {
      try {
        $Name = ($i.instances.Tags.GetEnumerator() | Where-Object {$_.Key -eq 'Name'}).Value
      }
      catch {
        $Name = ''
      }
      try {
        $StackName = ($i.instances.Tags.GetEnumerator() | Where-Object {$_.Key -eq 'aws:cloudformation:stack-name'}).Value
      }
      catch {
        $StackName = ''
      }
      try {
        if ($GetLocalAdminPassword) {
          $password = Get-EC2PasswordData -InstanceId $i.instances.InstanceId -PemFile "$CertFolderPath\$($i.instances.KeyName).pem" -ErrorAction stop
        }
        else {
          $Password = ''
        }
      }
      catch {
        $Password = ''
      }
      $PrivateIP = $i.instances.PrivateIpAddress
      $KeyName = $i.instances.keyname
      $InstanceId = $i.instances.InstanceId

      $prop = [ordered]@{
        Name = $Name
        StackName = $StackName
        PrivateIP = $PrivateIP
        PublicIP = $i.instances.PublicIpAddress
        KeyName = $KeyName
        InstanceID = $InstanceId
        Password = $Password
      }

      $obj = New-Object -TypeName psobject -Property $prop
      Write-Output $obj
    }

  }
  End {}
}