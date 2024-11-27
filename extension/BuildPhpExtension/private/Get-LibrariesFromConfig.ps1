Function Get-LibrariesFromConfig {
    <#
    .SYNOPSIS
        Get the Libraries from the config.w32 file
    .PARAMETER ConfigW32Content
        config.w32 content
    .PARAMETER VsVersion
        Visual Studio Version
    .PARAMETER Arch
        Architecture
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0, HelpMessage='config.w32 content')]
        [string] $ConfigW32Content,
        [Parameter(Mandatory = $true, Position=1, HelpMessage='Visual Studio Version')]
        [string] $VsVersion,
        [Parameter(Mandatory = $true, Position=2, HelpMessage='Architecture')]
        [string] $Arch
    )
    begin {
        $jsonPath = [System.IO.Path]::Combine($PSScriptRoot, '..\config\vs.json')
    }
    process {
        $jsonData = (
        Invoke-WebRequest -Uri "https://downloads.php.net/~windows/pecl/deps/libmapping.json"
        ).Content | ConvertFrom-Json

        Function Find-Library {
            param (
                [Parameter(Mandatory=$true, Position=0)]
                [string]$MatchString,
                [Parameter(Mandatory=$true, Position=1)]
                [string[]]$VsVersions
            )
            foreach ($vsVersion in $VsVersions) {
                foreach ($vsVersionData in $JsonData.PSObject.Properties) {
                    if($vsVersionData.Name -eq $VsVersion) {
                        foreach ($archData in $vsVersionData.Value.PSObject.Properties) {
                            if($archData.Name -eq $Arch) {
                                foreach ($libs in $archData.Value.PSObject.Properties) {
                                    if ($libs.Value -eq $MatchString) {
                                        return $libs.Name.split('-')[0]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return $null
        }

        $jsonContent = Get-Content -Path $jsonPath -Raw
        $VsConfig = ConvertFrom-Json -InputObject $jsonContent
        $VsVersions = @($VsVersion)
        $VsVersions += $($VsConfig.vs | Get-Member -MemberType *Property).Name | Where-Object {
            # vs15 and above builds are compatible.
            ($_ -lt $VsVersion -and $_ -ge "vc15")
        }

        $foundItems = @()
        [regex]::Matches($ConfigW32Content, 'CHECK_LIB\("([^"]+)"') | ForEach-Object {
            $_.Groups[1].Value.Split(';') | ForEach-Object {
                $library = Find-Library $_ $VsVersions
                if($library -and (-not($foundItems.Contains($library)))) {
                    $foundItems += $library
                }
            }
        }

        return $foundItems
    }
    end {
    }
}