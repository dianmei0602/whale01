<#
Publishes the newest successful sideload build to a fixed local path.

Usage:
    pwsh scripts/publish_ipa.ps1 -Repo owner/name -ArtifactBase App-Sideload
    pwsh scripts/publish_ipa.ps1 -Repo owner/name -RunId 123456 -ExpectedSourceSHA abc123

The script never writes the destination until every check passes: artifact name,
workflow conclusion, source SHA, manifest identity and SHA256 must all agree.
Requires: git (for the token), and an RSA private key at ~/.app/ipa-private.pem
if the artifact is encrypted.

Environment:
    GITHUB_TOKEN     optional; falls back to the git credential helper
    IPA_PASS         optional; plain passphrase for the encrypted IPA
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [string]$ArtifactBase = "App-Sideload",
    [string]$WorkflowName = "iOS Sideload IPA",
    [long]$RunId = 0,
    [string]$Destination = "",
    [string]$ExpectedSourceSHA = "",
    [switch]$AllowForkedWorkflow,
    [string]$IpaPass = $env:IPA_PASS,
    [string]$PrivateKeyPath = (Join-Path (Join-Path $env:USERPROFILE ".app") "ipa-private.pem")
)

$ErrorActionPreference = "Stop"
if (-not $Destination) { $Destination = Join-Path $env:USERPROFILE "$ArtifactBase.ipa" }

function Get-GitHubToken {
    if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
    $cred = @("protocol=https", "host=github.com", "") | git credential fill 2>$null
    $match = $cred | Select-String -Pattern '^password=(.+)$'
    if (-not $match) { throw "No GitHub token found in GITHUB_TOKEN or the git credential manager." }
    return $match.Matches[0].Groups[1].Value
}

$token = Get-GitHubToken
$headers = @{
    Authorization  = "Bearer $token"
    Accept         = "application/vnd.github+json"
    "User-Agent"   = "publish-sideload-ipa"
}

if ($RunId -eq 0) {
    $runs = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/runs?per_page=20" -Headers $headers).workflow_runs
    $run = $runs | Where-Object {
        $_.name -eq $WorkflowName -and $_.status -eq "completed" -and $_.conclusion -eq "success"
    } | Select-Object -First 1
    if (-not $run) { throw "No successful '$WorkflowName' run found." }
    $RunId = $run.id
}

$runMetadata = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/runs/$RunId" -Headers $headers
if ($runMetadata.conclusion -ne "success") { throw "Run $RunId is not a successful build." }
if ($ExpectedSourceSHA -and $runMetadata.head_sha -ne $ExpectedSourceSHA -and -not $AllowForkedWorkflow) {
    throw "The build does not belong to the expected source commit. No IPA was copied."
}

$artifacts = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/runs/$RunId/artifacts" -Headers $headers).artifacts
$artifact = $artifacts | Where-Object { $_.name -eq "$ArtifactBase-ipa-enc" } | Select-Object -First 1
$encrypted = $true
if (-not $artifact) {
    $artifact = $artifacts | Where-Object { $_.name -eq "$ArtifactBase-ipa" } | Select-Object -First 1
    $encrypted = $false
}
if (-not $artifact) { throw "Run $RunId has no '$ArtifactBase' IPA artifact." }

$work = Join-Path $env:TEMP ("publish-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    $zip = Join-Path $work "ipa.zip"
    $url = "https://api.github.com/repos/$Repo/actions/artifacts/$($artifact.id)/zip?nocache=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    Invoke-WebRequest -Uri $url -Headers $headers -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $work -Force

    $ipa = Get-ChildItem -Path $work -Recurse -Filter "$ArtifactBase.ipa" | Select-Object -First 1
    if (-not $ipa) {
        $enc = Get-ChildItem -Path $work -Recurse -Filter "$ArtifactBase.ipa.enc" | Select-Object -First 1
        if (-not $enc) { throw "Artifact did not contain a usable IPA or encrypted IPA." }
        if (-not $encrypted) { throw "Found an encrypted IPA in an unexpected artifact." }

        if (-not $IpaPass) {
            $wrapped = Get-ChildItem -Path $work -Recurse -Filter "$ArtifactBase-pass.enc" | Select-Object -First 1
            if ($wrapped -and (Test-Path -LiteralPath $PrivateKeyPath)) {
                $rsa = [System.Security.Cryptography.RSA]::Create()
                $rsa.ImportFromPem((Get-Content -LiteralPath $PrivateKeyPath -Raw))
                $passBytes = $rsa.Decrypt(
                    [System.IO.File]::ReadAllBytes($wrapped.FullName),
                    [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1
                )
                $rsa.Dispose()
                $IpaPass = [System.Text.Encoding]::UTF8.GetString($passBytes).Trim()
            }
        }
        if (-not $IpaPass) {
            throw "Artifact is encrypted. Provide -IpaPass, set IPA_PASS, or put the RSA private key at $PrivateKeyPath."
        }

        # OpenSSL compatible: "Salted__" + 8-byte salt, AES-256-CBC, PBKDF2-HMAC-SHA256, 10000 rounds.
        $raw = [System.IO.File]::ReadAllBytes($enc.FullName)
        $magic = [System.Text.Encoding]::ASCII.GetString($raw, 0, 8)
        if ($magic -ne "Salted__") { throw "Encrypted IPA is not in OpenSSL salted format." }
        $salt = $raw[8..15]
        $cipherLength = $raw.Length - 16
        $kdf = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $IpaPass, $salt, 10000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $kdf.GetBytes(32)
        $iv = $kdf.GetBytes(16)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $key
        $aes.IV = $iv
        $decryptor = $aes.CreateDecryptor()
        $plain = $decryptor.TransformFinalBlock($raw, 16, $cipherLength)
        $ipaPath = Join-Path $work "$ArtifactBase.ipa"
        [System.IO.File]::WriteAllBytes($ipaPath, $plain)
        $aes.Dispose()
        $kdf.Dispose()
        $ipa = Get-Item -LiteralPath $ipaPath
        Write-Host "decrypted IPA artifact"
    }

    $manifestFile = Get-ChildItem -LiteralPath $work -Recurse -Filter "$ArtifactBase.manifest.json" | Select-Object -First 1
    $expectedHashFile = Get-ChildItem -LiteralPath $work -Recurse -Filter "$ArtifactBase.sha256" | Select-Object -First 1
    if (-not $manifestFile -or -not $expectedHashFile) {
        throw "This artifact has no identity manifest; refusing to publish it as a verified build."
    }

    $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json
    $expectedHash = ((Get-Content -LiteralPath $expectedHashFile.FullName -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $ipa.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash -or $actualHash -ne $manifest.ipaSHA256) {
        throw "IPA checksum mismatch. No IPA was copied."
    }
    $expectedArtifactSHA = if ($ExpectedSourceSHA) { $ExpectedSourceSHA } else { $runMetadata.head_sha }
    if ($manifest.gitSHA -ne $expectedArtifactSHA) {
        throw "Artifact source identity mismatch. No IPA was copied."
    }

    $destinationDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item -LiteralPath $ipa.FullName -Destination $Destination -Force
    Copy-Item -LiteralPath $manifestFile.FullName -Destination "$Destination.manifest.json" -Force

    $hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLower()
    "$hash  $(Split-Path -Leaf $Destination)" | Set-Content -Path "$Destination.sha256" -Encoding ascii

    Write-Host "published run $RunId -> $Destination"
    Write-Host "version/build: $($manifest.version) $($manifest.installedBuild) source=$($manifest.gitSHA.Substring(0,12))"
    Write-Host "size: $((Get-Item -LiteralPath $Destination).Length) bytes"
    Write-Host "sha256: $hash"
}
finally {
    $resolvedWork = [System.IO.Path]::GetFullPath($work)
    $resolvedTemp = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedWork.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction SilentlyContinue
    }
}
