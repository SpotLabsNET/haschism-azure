  . .\Login-MiningFabric.ps1
  
  # Constants
  $ResourceGroupName = 'hascism-mining'
  $ResourceGroupLoc  = 'canadacentral'

  # Enumerate the subscriptions
  foreach ($Sub in GetSubscriptions) 
  {        
    # Switch the subscription context
    $null = (Set-AzureRmContext -SubscriptionId $Sub.Id -Verbose)

    # Clean up the old mess    
    $ResourceGroup = (Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -ErrorAction SilentlyContinue -Verbose)
    if(($null -eq $ResourceGroup) -or ($ResourceGroup.ResourceGroupName -eq ''))
    {
      $ResourceGroup = (New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -Force -Verbose)
    }
            
    $Locations = (GetLocations -SubscriptionName ($Sub.Name) -ComputeSeries 'standard_f4')
    foreach($Loc in $Locations)
    {      
        if($null -eq $Loc.Name)
        {
            continue
        }

      $Quota = (Get-AzureRmBatchLocationQuotas -Location $Loc.Name).AccountQuota
      for($Num=0;$Num -lt $Quota;$Num++)
      {
        $NumAbr = "$Num"

        # Batch Name
        $Name = "$($Loc.Abr)$($Sub.Abr)$($NumAbr)"

        # Batch Item            
        $Batch = (Get-AzureRmBatchAccount -AccountName $Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -Verbose)
        if($null -eq $Batch)
        {
            $Batch = New-AzureRmBatchAccount -AccountName $Name -Location $Loc.Name -ResourceGroupName $ResourceGroupName -Verbose #-AutoStorageAccountId $Store.Id
            Write-Output "Batch   $Name - Created"
        }
        else
        {
            Write-Output "Batch   $Name"
        }

        $BCntx = Get-AzureRmBatchAccountKeys -AccountName $Name -ResourceGroupName $ResourceGroupName
       
            $PName = "$Name"
            $Pool = (Get-AzureBatchPool -Id $PName -BatchContext $BCntx -ErrorAction SilentlyContinue)
            if($null -eq $Pool)
            {
              $TaskPol   = [Microsoft.Azure.Commands.Batch.Models.PSTaskSchedulingPolicy]::new([Microsoft.Azure.Batch.Common.ComputeNodeFillType]::Spread)
              $ImageRef  = [Microsoft.Azure.Commands.Batch.Models.PSImageReference]::new('UbuntuServer', 'Canonical', '16.04-LTS')
              $VmConfig  = [Microsoft.Azure.Commands.Batch.Models.PSVirtualMachineConfiguration]::new($ImageRef, 'batch.node.ubuntu 16.04')
              $StartTask = [Microsoft.Azure.Commands.Batch.Models.PSStartTask]::new('/bin/sh -c "curl -s https://gist.githubusercontent.com/SpotLabsNET/879f9f571e4dcd5185d8e51f033097b2/raw | bash"')
              $StartTask.WaitForSuccess = $true		
              $StartTask.RunElevated = $true
          
              try
              {
                $Pool = (New-AzureBatchPool -Id $PName -VirtualMachineSize "standard_f4" -StartTask $StartTask -BatchContext $BCntx -DisplayName $Name -TaskSchedulingPolicy $TaskPol -VirtualMachineConfiguration $VmConfig -TargetDedicated 0)
                Write-Output "Pool    $PName - Created"
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
            $CmdText = "& az account set --subscription `"$($Sub.Id)`""
            Invoke-Expression -Verbose -Command $CmdText

            # Login to the batch account
            $CmdText = "& az batch account login --name `"$Name`" --resource-group `"$ResourceGroupName`""
            Invoke-Expression -Verbose -Command $CmdText
            
            # Resize the pool 
            $CmdText = "& az batch pool resize --resize-timeout `"PT30M`" --target-low-priority-nodes 5 --target-dedicated-nodes 0 --pool-id `"$PName`""
            Invoke-Expression -Verbose -Command $CmdText
            Write-Output "Resized $PName"
           
      }
    }
  }
  