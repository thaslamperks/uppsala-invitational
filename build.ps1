# Rebuilds the locked index.html for the Uppsala Invitational site.
# Usage: .\build.ps1 -MasterPath "C:\Users\thaslam\Desktop\uppsala-invitational.html" -Password "..."
param(
  [string]$MasterPath = "C:\Users\thaslam\Desktop\uppsala-invitational.html",
  [Parameter(Mandatory=$true)][string]$Password
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plainBytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($MasterPath, [Text.Encoding]::UTF8))
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$salt = New-Object byte[] 16; $iv = New-Object byte[] 16; $rng.GetBytes($salt); $rng.GetBytes($iv)
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password.ToUpper(), $salt, 310000, ([System.Security.Cryptography.HashAlgorithmName]::SHA256))
$keys = $kdf.GetBytes(64)
$aes = [System.Security.Cryptography.Aes]::Create(); $aes.Mode = 'CBC'; $aes.Padding = 'PKCS7'
$aes.Key = $keys[0..31]; $aes.IV = $iv
$ct = $aes.CreateEncryptor().TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
$hmacInput = New-Object byte[] (32 + $ct.Length)
[Array]::Copy($salt, 0, $hmacInput, 0, 16); [Array]::Copy($iv, 0, $hmacInput, 16, 16); [Array]::Copy($ct, 0, $hmacInput, 32, $ct.Length)
$tag = (New-Object System.Security.Cryptography.HMACSHA256(,$keys[32..63])).ComputeHash($hmacInput)
$gate = [IO.File]::ReadAllText((Join-Path $here 'gate-template.html'), [Text.Encoding]::UTF8)
$gate = $gate.Replace('__SALT__', [Convert]::ToBase64String($salt)).Replace('__IV__', [Convert]::ToBase64String($iv)).Replace('__TAG__', [Convert]::ToBase64String($tag)).Replace('__CT__', [Convert]::ToBase64String($ct))
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $gate, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("index.html rebuilt: " + [math]::Round((Get-Item (Join-Path $here 'index.html')).Length/1KB) + " KB")