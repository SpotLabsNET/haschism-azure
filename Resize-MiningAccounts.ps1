﻿  . .\Login-MiningFabric.ps1
  
  $Sizes = @('nc', 'nv')
  $Nums = @('a', 'b', 'c')
  $Locs = @('eastus', 'northcentralus', 'southcentralus', 'westus2', 'northeurope', 'westeurope', 'japaneast', 'southeastasia', 'uksouth')
  $Subs = (Get-AzureRmSubscription -Verbose|? {($_.State -eq 'Enabled') -and ($_.Name.StartsWith('Ent'))} | Sort-Object -Property Name -Descending) 

  # Abreviation Variables
  $LocAbr = 'ln'
  $SubAbr = 'sn'
  $NumAbr = 'nn'

  # Constants
  $ResourceGroupName = 'hascism-mining'
  $ResourceGroupLoc  = 'canadacentral'

  # Enumerate the subscriptions
  foreach ($Sub in $Subs) 
  {
    $SubId   = $Sub.Id
    $SubName = $Sub.Name
    
    # Switch the subscription context
    $null = (Set-AzureRmContext -SubscriptionId $SubId -Verbose)

    # Clean up the old mess    
    $ResourceGroup = (Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -ErrorAction SilentlyContinue -Verbose)
    if(($null -eq $ResourceGroup) -or ($ResourceGroup.ResourceGroupName -eq ''))
    {
      $ResourceGroup = (New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -Force -Verbose)
      #Write-Output "ResourceGroup $ResourceGroupName - Created"
    }
    else
    {
        #Write-Output "ResourceGroup $ResourceGroupName - Verified"
    }

    # Abreaviate the subscription
    $SubAbr = $null
    if($Sub.Name.EndsWith('06')) {$SubAbr = 'f'}
    if($Sub.Name.EndsWith('05')) {$SubAbr = 'e'}
    if($Sub.Name.EndsWith('04')) {$SubAbr = 'd'}
    if($Sub.Name.EndsWith('03')) {$SubAbr = 'c'}
    if($Sub.Name.EndsWith('02')) {$SubAbr = 'b'}
    if($Sub.Name.EndsWith('01')) {$SubAbr = 'a'}
    if($null -eq $SubAbr) { throw "Bad Sub" }
        
    # Enumerate the Locations
    foreach($Loc in $Locs)
    {
      if($Loc -eq 'westeurope')     
      {
        $LocAbr = 'euwa' 
      }
      if($Loc -eq 'northeurope')    
      {
        $LocAbr = 'euna' 
      }
      if($Loc -eq 'westus2')        
      {
        $LocAbr = 'uswb' 
      }
      if($Loc -eq 'southcentralus') 
      {
        $LocAbr = 'ussc' 
      }
      if($Loc -eq 'northcentralus') 
      {
        $LocAbr = 'usnc' 
      }
      if($Loc -eq 'eastus')         
      {
        $LocAbr = 'usea' 
      }
      if($Loc -eq 'uksouth')        
      {
        $LocAbr = 'uksa' 
      }
      if($Loc -eq 'southeastasia')  
      {
        $LocAbr = 'apse' 
      }
      if($Loc -eq 'japaneast')      
      {
        $LocAbr = 'jpea' 
      }

      # Enumerate the Numbers
      foreach($Num in $Nums)
      {
        $NumAbr = "$Num"

        # Batch Name
        $Name = "$($SubAbr)$($LocAbr)$($NumAbr)"

        #$Store = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue -Verbose)
        #if($null -eq $Store)
        #{
        #  $Store = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Name -SkuName Standard_LRS -Location $Loc -Verbose
        #}
            
        $Batch = (Get-AzureRmBatchAccount -AccountName $Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -Verbose)
        if($null -eq $Batch)
        {
          $Batch = New-AzureRmBatchAccount -AccountName $Name -Location $Loc -ResourceGroupName $ResourceGroupName -Verbose #-AutoStorageAccountId $Store.Id
            Write-Output "Batch   $Name - Created"
        }
        else
        {
            Write-Output "Batch   $Name"
        }

        $BCntx = Get-AzureRmBatchAccountKeys -AccountName $Name -ResourceGroupName $ResourceGroupName
       
        foreach($Size in $Sizes)
        {
            $PName = "$Name$Size"
            $Pool = (Get-AzureBatchPool -Id $PName -BatchContext $BCntx -ErrorAction SilentlyContinue)
            if($null -eq $Pool)
            {
              $TaskPol   = [Microsoft.Azure.Commands.Batch.Models.PSTaskSchedulingPolicy]::new([Microsoft.Azure.Batch.Common.ComputeNodeFillType]::Spread)
              $ImageRef  = [Microsoft.Azure.Commands.Batch.Models.PSImageReference]::new('UbuntuServer', 'Canonical', '16.04-LTS')
              $VmConfig  = [Microsoft.Azure.Commands.Batch.Models.PSVirtualMachineConfiguration]::new($ImageRef, 'batch.node.ubuntu 16.04')
              $StartTask = [Microsoft.Azure.Commands.Batch.Models.PSStartTask]::new('/bin/sh -c "curl -s https://gist.githubusercontent.com/SpotLabsNET/ed5d8930351eb827f0ae2bdb3351cb8b/raw/batch-miner-startup.sh | bash"')
              $StartTask.WaitForSuccess = $true		
              $StartTask.RunElevated = $true
          
              try
              {
                  if($Size -ne 'nd')
                  {
                    $Pool = (New-AzureBatchPool -Id $PName -VirtualMachineSize "standard_$($Size)6" -StartTask $StartTask -BatchContext $BCntx -DisplayName $Name -TaskSchedulingPolicy $TaskPol -VirtualMachineConfiguration $VmConfig -TargetDedicated 0)
                    Write-Output "Pool    $PName - Created"
                  }
                  else
                  {
                    $Pool = (New-AzureBatchPool -Id $PName -VirtualMachineSize "standard_$($Size)6s" -StartTask $StartTask -BatchContext $BCntx -DisplayName $Name -TaskSchedulingPolicy $TaskPol -VirtualMachineConfiguration $VmConfig -TargetDedicated 0)
                    Write-Output "Pool    $PName - Created"
                  }
              }
              catch
              {
                Write-Output "Pool    $PName - Failed"
              }
            }
            else
            {
                Write-Output "Pool    $PName"
            }

             # Resize the pools
             $CmdText = ''

            # Ensure AzureCLI is at correct subscription
            $CmdText = "& az account set --subscription `"$SubName`""
            Invoke-Expression -Verbose -Command $CmdText

            # Login to the batch account
            $CmdText = "& az batch account login --name `"$Name`" --resource-group `"$ResourceGroupName`""
            Invoke-Expression -Verbose -Command $CmdText
            
            $Nodes = Get-AzureBatchComputeNode -PoolId $PName -BatchContext $BCntx
            foreach($Node in $Nodes)
            {
                while($Node.State -ne [Microsoft.Azure.Batch.Common.ComputeNodeState]::Idle)
                {
                    Write-Output "Wait  $PName"
                    Start-Sleep -Seconds 60
                }

                $StartTask = [Microsoft.Azure.Commands.Batch.Models.PSStartTask]::new('/bin/sh -c "curl -s https://gist.githubusercontent.com/SpotLabsNET/ed5d8930351eb827f0ae2bdb3351cb8b/raw/batch-miner-startup.sh | bash"')
                $StartTask.WaitForSuccess = $true		
                $StartTask.RunElevated = $true

                $Pool.StartTask = $StartTask
                Set-AzureBatchPool -Pool $Pool -BatchContext $BCntx

                if($Node.State -eq [Microsoft.Azure.Batch.Common.ComputeNodeState]::Idle)
                {
                    $Files = Get-AzureBatchNodeFile -ComputeNodeId $Node.Id -BatchContext $BCntx -PoolId $PName -Recursive
                    foreach($File in $Files)
                    {
                        if($File.Name.ToLower().Contains('stdout'))
                        {
                            if($File.Properties.ContentLength -gt 300000)
                            {
                                Restart-AzureBatchComputeNode -ComputeNode $Node -RebootOption Requeue -BatchContext $BCntx
                                Write-Output "Reboot  $PName"
                            }
                        }
                    }
                }
            }
          }
      }
    }
  }
  # 