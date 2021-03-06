﻿<#
    .SYNOPSIS
       Copies all of the VM Disks in a resource group
#>
Function Copy-AzureRMResourceGroupVMDisk
{
    Param(
        [Parameter(
            Mandatory = $True
        )]
        [String]
        $SourceSubscriptionName,

        [Parameter(
            Mandatory = $True
        )]
        [pscredential]
        $SourceSubscriptionAccessCredential,

        [Parameter(
            Mandatory = $False
        )]
        [String]
        $SourceSubscriptionTenant = $Null,

        [Parameter(
            Mandatory = $True
        )]
        [String]
        $TargetSubscriptionName,

        [Parameter(
            Mandatory = $True
        )]
        [pscredential]
        $TargetSubscriptionAccessCredential,

        [Parameter(
            Mandatory = $False
        )]
        [String]
        $TargetSubscriptionTenant = $Null,

        [Parameter(
            Mandatory = $True
        )]
        [String]
        $SourceResourceGroupName,

        [Parameter(
            Mandatory = $True
        )]
        [String]
        $TargetResourceGroupName,
        
        [Parameter(
            Mandatory = $True
        )]
        [String]
        $TargetStorageAccountName,

        [Parameter(
            Mandatory = $True
        )]
        [String]
        $SourceStorageAccountName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {
        $TargetStorageAccountContext = GetStorageAccountContext -Credential $TargetSubscriptionAccessCredential `
                                                                -SubscriptionName $TargetSubscriptionName `
                                                                -Tenant $TargetSubscriptionTenant `
                                                                -ResourceGroupName $TargetResourceGroupName `
                                                                -StorageAccountName $TargetStorageAccountName

        $DiskToCopy = GetResourceGroupVMDisk -Credential $SourceSubscriptionAccessCredential `
                                             -SubscriptionName $SourceSubscriptionName `
                                             -Tenant $SourceSubscriptionTenant `
                                             -ResourceGroupName $SourceResourceGroupName
        
        $BlobCopyJob = StartDiskCopy -DiskToCopy $DiskToCopy `
                                     -TargetStorageAccountContext $TargetStorageAccountContext

        WaitForDiskCopyToComplete -BlobCopyJob $BlobCopyJob
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }

    Write-CompletedMessage @CompletedParameters
}
Export-ModuleMember -Function Copy-AzureRMResourceGroupVMDisk -Verbose:$False

Function GetStorageAccountContext
{
    Param(
        $Credential,
        $SubscriptionName,
        $Tenant,
        $ResourceGroupName,
        $StorageAccountName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName -Tenant $Tenant
        $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName `
                                                    -Name $StorageAccountName
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }

    Write-CompletedMessage @CompletedParameters -Status ($StorageAccount.Context | ConvertTo-Json -Depth 1)
    Return $StorageAccount.Context
}

Function GetResourceGroupVMDisk
{
    Param(
        $Credential,
        $SubscriptionName,
        $Tenant,
        $ResourceGroupName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName -Tenant $Tenant
        $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
        
        $DiskToCopy = @()
        Foreach($_VM in $VM)
        {
            $DiskToCopy += GetVMDisk -VM $_VM `
                                     -Credential $Credential `
                                     -SubscriptionName $SubscriptionName `
                                     -Tenant $Tenant `
                                     -ResourceGroupName $ResourceGroupName
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }

    Write-CompletedMessage @CompletedParameters -Status ($DiskToCopy.Context | ConvertTo-Json -Depth 1)
    Return $DiskToCopy
}

Function GetVMDisk
{
    Param(
        $VM,
        $Credential,
        $SubscriptionName,
        $Tenant,
        $ResourceGroupName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName -Tenant $Tenant
        $DiskToCopy = New-Object -TypeName System.Collections.ArrayList

        if($VM.StorageProfile.OSDisk.VirtualHardDisk.Uri -Match '/([^/.]+).+/([^/]+)/([^/]+)$')
        {
            $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Matches[1]
            $Null = $DiskToCopy.Add(@{ 'Context' = $StorageAccount.Context ; 'Container' = $Matches[2] ; 'BlobName' = $Matches[3] })
        }
        Foreach($DataDisk in $VM.StorageProfile.DataDisks)
        {
            if($DataDisk.VirtualHardDisk.Uri -Match '/([^/.]+).+/([^/]+)/([^/]+)$')
            {
                $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Matches[1]
                $Null = $DiskToCopy.Add(@{ 'Context' = $StorageAccount.Context ; 'Container' = $Matches[2] ; 'BlobName' = $Matches[3] })
            }
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }

    Write-CompletedMessage @CompletedParameters -Status ($DiskToCopy | ConvertTo-Json -Depth 1)
    $DiskToCopy | ForEach-Object { $_ }
}

Function StartDiskCopy
{
    Param(
        $DiskToCopy,
        $TargetStorageAccountContext
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {
        $BlobCopyJob = New-Object -TypeName System.Collections.ArrayList
        Foreach($Disk in $DiskToCopy)
        {
            $BlobCopyJob += StartIndividualDiskCopy -Disk $Disk `
                                                    -TargetStorageAccountContext $TargetStorageAccountContext
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }

    Write-CompletedMessage @CompletedParameters -Status ($BlobCopyJob | ConvertTo-Json -Depth 1)
    Return $BlobCopyJob
}

Function StartIndividualDiskCopy
{
    Param(
        $Disk,
        $TargetStorageAccountContext
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -String $Disk.BlobName

    Try
    {
        Try
        {
            $Container = Get-AzureStorageContainer -Context $TargetStorageAccountContext -Name $Disk.Container
            if(-not($Container -as [bool]))
            {
                $Null = New-AzureStorageContainer -Context $TargetStorageAccountContext -Name $Disk.Container
            }
        }
        Catch
        {
            $Null = New-AzureStorageContainer -Context $TargetStorageAccountContext -Name $Disk.Container
        }

        $Job = Start-CopyAzureStorageBlob -SrcBlob $Disk.BlobName `
                                          -SrcContainer $Disk.Container `
                                          -Context $Disk.Context `
                                          -DestContainer $Disk.Container `
                                          -DestBlob $Disk.BlobName `
                                          -DestContext $TargetStorageAccountContext `
                                          -Force
        Write-CompletedMessage @CompletedParameters -Status $Job.Status
        Return $Job
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception $Exception -Stream Warning
            }
        }
    }
}

Function WaitForDiskCopyToComplete
{
    Param(
        $BlobCopyJob
    )
    $NotComplete = $False
    Do
    {
        Foreach($_BlobCopyJob in $BlobCopyJob)
        {
            if($_BlobCopyJob -as [bool])
            {
                $BlobCopyCompletedParams = Write-StartingMessage -CommandName $_BlobCopyJob.Name
                $CopyState = $_BlobCopyJob | Get-AzureStorageBlobCopyState

                $Percent = ($copyState.BytesCopied / $copyState.TotalBytes) * 100		
                if($CopyState.Status -ne 'Success') { $NotComplete = $True }
                Write-CompletedMessage @BlobCopyCompletedParams -Status "$($CopyState.Status) Completed $('{0:N2}' -f $Percent)%"
            }
        }
        if($NotComplete) { Start-Sleep -Seconds 30 }
    } While($NotComplete)
}
