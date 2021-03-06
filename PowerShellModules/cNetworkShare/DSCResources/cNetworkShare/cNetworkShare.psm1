function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $DriveLetter,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )
    $ErrorActionPreference = 'Stop'
    Try
    {
        $DriveConfig = Get-PSDrive -Name $DriveLetter
        $ReturnValue = @{
            DriveLetter = $DriveLetter
            SharePath = $DriveConfig.DisplayRoot
            Ensure = $Ensure
            Credential = $null
        }
    }
    Catch
    {
        Write-Debug -Message 'Drive is not mapped'
        $ReturnValue = @{
            DriveLetter = $DriveLetter
            SharePath = [System.String]::Empty
            Ensure = $Ensure
            Credential = $null
        }
    }

    return $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $DriveLetter,

        [System.String]
        $SharePath,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Management.Automation.PSCredential]
        $Credential
    )
    $ErrorActionPreference = 'Stop'

    if($Ensure -eq 'Present')
    {
        Try
        {
            $DriveConfig = Get-PSDrive -Name $DriveLetter
            if($DriveConfig -as [bool])
            {
                Remove-PSDrive -Name $DriveLetter -Force
            }
        }
        Catch { }
        $null = New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $SharePath -Persist -Credential $Credential
    }
    else
    {
        Remove-PSDrive -Name $DriveLetter -Force
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $DriveLetter,

        [System.String]
        $SharePath,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Management.Automation.PSCredential]
        $Credential
    )
    $ErrorActionPreference = 'Stop'

    Try
    {
        $DriveConfig = Get-PSDrive -Name $DriveLetter
        
        $DriveConfiguredToSharePath = ($DriveConfig.DisplayRoot -eq $SharePath) -as [bool]

        if($Ensure -eq 'Present')
        {
            return $DriveConfiguredToSharePath
        }
        else
        {
            return (-not $DriveConfiguredToSharePath)
        }

    }
    Catch 
    { 
        if($Ensure -eq 'Present')
        {
            return $false
        }
        else
        {
            return $true
        }
    }
}


Export-ModuleMember -Function *-TargetResource

