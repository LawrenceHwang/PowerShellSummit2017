Function Connect-EC2Windows {
  <#
    .SYNOPSIS
      Launch a RDP session to remote windows EC2 instance.
    .DESCRIPTION
      Launch a RDP session to remote windows EC2 instance with local admin credential.
      There is no need to specify the individual pem file. The function will automatically match the pem file based on name in the provided folder path.
      The local admin credential is decrypted then with the pem file in the folders at runtime by querying AWS API.
      RDP file is generated dynamically and removed after RDP session launched.
    .EXAMPLE
      Launch a RDP session to the i-05f9d2f88bbbbbbbb instance
      Connect-SCEC2Windows -InstanceId i-05f9d2f88bbbbbbbb -CertFolderPath 'D:\certs'
    .EXAMPLE
      Using the Get-EC2Instance, filtering the desired instances and pipe to the Connect-SCEC2Windows.
      (Get-EC2Instance -Filter @(@{name='tag:Name'; value = 'prod-windowsbastion-1'}) | %{ $_.Instances}).instanceid | Connect-SCEC2Windows -CertFolderPath D:\certs
    .NOTES


    .LINK
  #>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [String] $InstanceId,
    [Parameter(Mandatory = $true
    )]
    [String] $CertFolderPath
  )

  Begin {}
  Process {
    foreach ($i in $InstanceId) {
      $instance = Get-EC2instance -InstanceId $i -Filter @(@{name = 'platform'; value = 'windows'}) -ErrorAction Stop
      write-verbose "$instance.instances.PublicIpAddress"
      $RDPhost = $instance.instances.PublicIpAddress
      if ($RDPhost -notmatch "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
        Write-Warning "No public IP for the instance: $i"
        break
      }
      if (test-path ("$CertFolderPath\$($instance.instances.KeyName).pem")) {
        $Password = Get-EC2PasswordData -InstanceId $i -PemFile "$CertFolderPath\$($instance.instances.KeyName).pem" -ErrorAction stop
      }
      else {
        throw "PEM not found for the instance: $i"
      }

      # Generate the encrypted password binary
      Add-Type -AssemblyName System.Security
      $EncryptArray = [System.Security.Cryptography.ProtectedData]::Protect($([System.Text.Encoding]::Unicode.GetBytes($Password)), $Null, "CurrentUser")
      $PasswordBinary = ($EncryptArray | ForEach-Object -Process { "{0:X2}" -f $_ }) -join ""
      $Password = ''
      $RDPfile = "$env:TEMP\$RDPhost.rdp"
      #Dynamically generate the RDP file
      $RDPFileContent = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1278
desktopheight:i:1386
session bpp:i:32
winposstr:s:0,1,0,0,1368,882
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$RDPhost
audiomode:i:0
redirectprinters:i:0
redirectcomports:i:0
redirectsmartcards:i:0
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
username:s:administrator
password 51:b:$PasswordBinary
"@
      $RDPFileContent | out-file $RDPFile
      $MSTSCprocess = Start-Process $RDPfile -PassThru
      Write-Verbose "PID $($MSTSCprocess.Id)"
      Start-Sleep -Milliseconds 200
      Remove-Item -Path $RDPfile -Force
    }
  }
}