
  $Nums = @('a', 'b', 'c')
  $Wkss = @('a', 'b', 'c')
  $Locs = @('eastus', 'northcentralus', 'southcentralus', 'westus2', 'northeurope', 'westeurope', 'japaneast', 'southeastasia', 'uksouth')
  $Subs = (Get-AzureRmSubscription |? {($_.State -eq 'Enabled') -and ($_.Name.StartsWith('Ent'))} | Sort-Object -Property Name -Descending)

  # Abreviation Variables
  $LocAbr = 'ln'
  $SubAbr = 'sn'
  $NumAbr = 'nn'
  $WksAbr = 'mm'

  # Constants
  $ResourceGroupName = 'hascism-mining'
  $ResourceGroupLoc  = 'canadacentral'

  # Enumerate the subscriptions
  foreach ($Sub in $Subs) 
  {
    $SubId   = $Sub.Id
    $SubName = $Sub.Name
    
    # Switch the subscription context
    $null = (Set-AzureRmContext -SubscriptionId $SubId)

    # Clean up the old mess    
    $ResourceGroup = (Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -ErrorAction SilentlyContinue -Verbose)
    if(($null -eq $ResourceGroup) -or ($ResourceGroup.ResourceGroupName -eq ''))
    {
      $ResourceGroup = (New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLoc -Force)
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
        
        # Get the batch context
        $Batch = Get-AzureRmBatchAccountKeys -AccountName $Name -ResourceGroupName $ResourceGroupName -Verbose -ErrorAction SilentlyContinue
        if($null -ne $Batch)
        {
          foreach($Wks in $Wkss)
          { 
            $WksAbr = "$Wks"

            $Item = "$($SubAbr)$($LocAbr)$($NumAbr)$($WksAbr)"

            $ScriptsPath = (Join-Path -Path $PsScriptRoot -ChildPath '.scripts')
            $TargetFile  = (Join-Path -Path $ScriptsPath  -ChildPath "startup.$Item.sh")

            if(-not (Test-Path -Path $ScriptsPath))
            {
              New-Item -ItemType Directory -Path $ScriptsPath | Out-Null
            }   
            
            Write-Host -Object "Producing $Item@$TargetFile"                   
            New-Item -ItemType File -Path $TargetFile -Force | Out-Null
          }      
        }     
      }
    }
  }
  # 