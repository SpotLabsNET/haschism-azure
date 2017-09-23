  . .\Login-MiningFabric.ps1
  
  $Sizes = @('nc', 'nv')
  $Nums = @('a', 'b', 'c')
  $Locs = @('eastus', 'northcentralus', 'southcentralus', 'westus2', 'northeurope', 'westeurope', 'japaneast', 'southeastasia', 'uksouth')
  $Subs = (Get-AzureRmSubscription -Verbose|? {($_.State -eq 'Enabled') -and ($_.Name.StartsWith('Ent'))} | Sort-Object -Property Name) 

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

            # Resize the pools
            $CmdText = ''

            # Ensure AzureCLI is at correct subscription
            $CmdText = "& az account set --subscription `"$SubName`""
            Invoke-Expression -Verbose -Command $CmdText

            # Login to the batch account
            $CmdText = "& az batch account login --name `"$Name`" --resource-group `"$ResourceGroupName`""
            Invoke-Expression -Verbose -Command $CmdText

            if($Size -eq 'nc')
            {
                # Resize the pool 
                $CmdText = "& az batch pool resize --resize-timeout `"PT30M`" --target-low-priority-nodes 0 --target-dedicated-nodes 0 --pool-id `"$PName`""
                Invoke-Expression -Verbose -Command $CmdText
                Write-Output "Resized $PName"
            }

            
            if($Size -eq 'nv')
            {
                # Resize the pool 
                $CmdText = "& az batch pool resize --resize-timeout `"PT30M`" --target-low-priority-nodes 3 --target-dedicated-nodes 0 --pool-id `"$PName`""
                Invoke-Expression -Verbose -Command $CmdText
                Write-Output "Resized $PName"
            }
          }
      }
    }
  }
  # 