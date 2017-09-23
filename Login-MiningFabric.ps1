function Login([String]$Username, [String]$Password)
{
    $User = $Username
    $Pass = ConvertTo-SecureString�-String $Password -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ($User, $Pass)    

    Add-AzureRmAccount -Credential $Cred
    (& az login -t bd175e15-2fcf-4232-8faa-644497ae6da0 -u "$Username" -p "$Password")
}

function GetLocations([String]$SubscriptionName, [String]$ComputeSeries)
{
    Set-AzureRmContext -SubscriptionName $SubscriptionName

    # Result list
    $Results = @()

    # Get a list of locations
    $Locations = Get-AzureRmLocation

    # Enumerate the locations
    foreach($Location in $Locations)
    {
        $Sizes = Get-AzureRmVMSize -Location $Location.Location
        if($ComputeSeries -in ($Sizes.Name))
        {
            $Abbr = GetLocAbbr -Location ($Location.Location)
            $Results += ($Location | Select -Property @{Name="Name"; Expression={$_.Location}}, @{Name="Abr"; Expression={$Abbr}})
        }
    }

    # Return
    return ($Results | Sort-Object -Property Location)
}

function GetMachineSizes()
{
    return @('standard_f4', 'standard_nc6', 'standard_nv6', 'standard_nd6s')
}

function GetSubscriptions()
{
    $Subscriptions = Get-AzureRmSubscription |? { (($_.State -eq 'Enabled') -and ($_.Name.StartsWith('@'))) }
    return ($Subscriptions | Sort -Property Id -Descending | Select -Property Id, Name, @{Name="Abr"; Expression={$_.Id.Split('-')[1]}})
}

function GetLocAbbr([String]$Location)
{
    $Location = $Location.Replace('australia', 'au')
    $Location = $Location.Replace('canada', 'ca')
    $Location = $Location.Replace('india', 'in')
    $Location = $Location.Replace('korea', 'ko')
    $Location = $Location.Replace('brazil', 'bz')    
    $Location = $Location.Replace('europe', 'eu')
    $Location = $Location.Replace('japan',  'jp')
    $Location = $Location.Replace('asia',   'ap')
    $Location = $Location.Replace('central', 'c')
    $Location = $Location.Replace('north', 'n')
    $Location = $Location.Replace('south', 's')
    $Location = $Location.Replace('east',  'e')
    $Location = $Location.Replace('west',  'w')
    $Location = $Location.Replace('2',     'b')

    if($Location.Length -eq 3) 
    {
        $Location = "$($Location)a"
    }

    return $Location
}