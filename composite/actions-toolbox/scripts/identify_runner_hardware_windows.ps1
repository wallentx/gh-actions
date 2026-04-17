# Description: This script retrieves hardware information about the CPU and memory from the local system using Windows Management Instrumentation, specifically the model, number of cores, number of threads, and total capacity. It also detects the cloud provider and, when running on AWS EC2, exports instance identity details to the local GitHub environment.

function Set-GitHubEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    $stringValue = if ($null -eq $Value) { "" } else { [string]$Value }
    Write-Host "Set $Name=$stringValue"
    Add-Content -Path $env:GITHUB_ENV -Value "$Name=$stringValue"
}

function Invoke-MetadataRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [int]$TimeoutSec = 2
    )

    try {
        return Invoke-WebRequest `
            -Uri $Uri `
            -Method $Method `
            -Headers $Headers `
            -TimeoutSec $TimeoutSec `
            -UseBasicParsing `
            -ErrorAction Stop
    } catch {
        return $null
    }
}

function ConvertFrom-JsonSafe {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return $null
    }

    try {
        return $Json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-AwsImdsToken {
    param([int]$TtlSeconds = 60)

    $response = Invoke-MetadataRequest `
        -Uri "http://169.254.169.254/latest/api/token" `
        -Method "PUT" `
        -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "$TtlSeconds" }

    if ($null -eq $response -or [string]::IsNullOrWhiteSpace($response.Content)) {
        return $null
    }

    return $response.Content.Trim()
}

function Detect-CloudProvider {
    # GitHub-hosted runners run on Azure, so avoid probing other metadata
    # services when GitHub has already identified the runner environment.
    if ($env:RUNNER_ENVIRONMENT -eq "github-hosted") {
        return "azure"
    }

    $token = Get-AwsImdsToken -TtlSeconds 60
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $awsResponse = Invoke-MetadataRequest `
            -Uri "http://169.254.169.254/latest/dynamic/instance-identity/document" `
            -Headers @{ "X-aws-ec2-metadata-token" = $token }
        $awsDocument = if ($awsResponse) { ConvertFrom-JsonSafe -Json $awsResponse.Content } else { $null }

        if ($awsDocument -and $awsDocument.instanceId -and $awsDocument.region) {
            return "aws"
        }
    }

    $azureResponse = Invoke-MetadataRequest `
        -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" `
        -Headers @{ Metadata = "true" }
    $azureDocument = if ($azureResponse) { ConvertFrom-JsonSafe -Json $azureResponse.Content } else { $null }

    if ($azureDocument -and $azureDocument.compute -and $azureDocument.compute.vmId) {
        return "azure"
    }

    $gcpResponse = Invoke-MetadataRequest `
        -Uri "http://169.254.169.254/computeMetadata/v1/instance/id" `
        -Headers @{ "Metadata-Flavor" = "Google" }

    if ($gcpResponse -and $gcpResponse.Headers["Metadata-Flavor"] -eq "Google") {
        return "gcp"
    }

    return "unknown"
}

function Identify-RunnerHardware {
    $CPU = Get-CimInstance -ClassName Win32_Processor
    $CPU_MODEL = $CPU.Name
    Set-GitHubEnv -Name "CPU_MODEL" -Value $CPU_MODEL

    $CPU_CORES = $CPU.NumberOfCores
    Set-GitHubEnv -Name "CPU_CORES" -Value $CPU_CORES

    $CPU_THREADS = $CPU.NumberOfLogicalProcessors
    Set-GitHubEnv -Name "CPU_THREADS" -Value $CPU_THREADS

    $MEM = Get-CimInstance -ClassName Win32_PhysicalMemory
    $MEM_TOTAL = "$([int64](($MEM.Capacity | Measure-Object -Sum).Sum / 1GB))GB"
    Set-GitHubEnv -Name "MEM_TOTAL" -Value $MEM_TOTAL
}

function Identify-InstanceDetails {
    $cloudProvider = Detect-CloudProvider
    Set-GitHubEnv -Name "CLOUD_PROVIDER" -Value $cloudProvider

    if ($cloudProvider -ne "aws") {
        Write-Host "Not running on AWS EC2 (detected: $cloudProvider). Skipping IMDS instance identity."
        return
    }

    $token = Get-AwsImdsToken -TtlSeconds 21600
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "AWS IMDS token fetch failed/empty; skipping instance detection."
        return
    }

    $instanceResponse = Invoke-MetadataRequest `
        -Uri "http://169.254.169.254/latest/dynamic/instance-identity/document" `
        -Headers @{ "X-aws-ec2-metadata-token" = $token }

    if ($null -eq $instanceResponse -or [string]::IsNullOrWhiteSpace($instanceResponse.Content)) {
        Write-Host "AWS IMDS instance identity document empty; skipping."
        return
    }

    $instanceDocument = ConvertFrom-JsonSafe -Json $instanceResponse.Content
    if ($null -eq $instanceDocument) {
        $previewLength = [Math]::Min(20, $instanceResponse.Content.Length)
        $preview = $instanceResponse.Content.Substring(0, $previewLength).Replace("`r", " ").Replace("`n", " ")
        Write-Host "AWS IMDS response was not valid JSON; skipping. (First bytes: $preview)"
        return
    }

    $properties = $instanceDocument.PSObject.Properties | Sort-Object Name
    if ($null -eq $properties -or $properties.Count -eq 0) {
        Write-Host "AWS IMDS JSON had no properties to export; skipping."
        return
    }

    foreach ($property in $properties) {
        $name = "IID_{0}" -f $property.Name.ToUpperInvariant()
        $value = if ($null -eq $property.Value) { "" } else { [string]$property.Value }
        Set-GitHubEnv -Name $name -Value $value
    }
}

Write-Host "::group::Identifying Runner Hardware"
Identify-RunnerHardware
Write-Host "::endgroup::"

Write-Host "::group::Identifying Instance Details"
Identify-InstanceDetails
Write-Host "::endgroup::"
