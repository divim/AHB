#Get all subscriptions
$azSubs = Get-AzSubscription
$dot = "....................."
$AzureVM = @()
$AzureSQLVM = @()
#Iterate through all subscriptions
foreach ($azSub in $azSubs)
{
    $string = "Checking subscription: "
    $string + $azSub.Name + $dot
    Set-AzContext -Subscription $azSub | Out-Null

    #Iterate through all VMs
    foreach ($azVM in Get-AzVM)
    {
        #If AHUB is not applied for Windows Server
        if ($azVM.StorageProfile.OsDisk.OsType -ceq "Windows") 
        {   
            if ((!$azVM.LicenseType) -or ($azVM.LicenseType -ceq "None"))
            {
                $string = "[UPDATE] Updating VM License with AHUB (Windows Server): "
                $string + $azVM.Name + $dot
                $azVM.LicenseType = "Windows_Server"
                #Apply AHUB
                Update-AzVM -ResourceGroupName $azVM.ResourceGroupName -VM $azVM
                #Adding details for CSV file
                $props = @{
                    SubName = $azSub.Name
                    VMName = $azVM.Name
                    Region = $azVM.Location
                    OsType = $azVM.StorageProfile.OsDisk.OsType
                    ResourceGroupName = $azVM.ResourceGroupName
                    LicenseType = $azVM.LicenseType
                }
                $ServiceObject = New-Object -TypeName PSObject -Property $props
                $AzureVM += $ServiceObject
            }
        }
    }
    #Iterate through all SQL Server VMs
    foreach ($azSqlVM in Get-AzSqlVM)
    {
        #Only Enterprise or Standard SKUs are supported for AHUB
        if (($azSqlVM.Sku -ceq 'Standard') -or ($azSqlVM.Sku -ceq 'Enterprise'))
        {
            if ($azSqlVM.LicenseType -ceq "PAYG")
            {
                $string = "[UPDATE] Updating VM License with AHUB (Microsoft SQL): "
                $string + $azSqlVM.Name + $dot
                Update-AzSqlVM -ResourceGroupName $azSqlVM.ResourceGroupName -Name $azSqlVM.Name -LicenseType "AHUB"
                # Adding details for CSV file
                $propsSQL = @{
                    SubName = $azSub.Name
                    VMName = $azSqlVM.Name
                    Region = $azSqlVM.Location
                    Sku = $azSqlVM.Sku
                    ResourceGroupName = $azSqlVM.ResourceGroupName
                }
                $SQLServiceObject = New-Object -TypeName PSObject -Property $propsSQL
                $AzureSQLVM += $SQLServiceObject
            }
        }
        else {
            $string = "[WARNING] Az SQL VM SKU for "
            $string2 = " does not support AHUB License"
            $string + $azSqlVM.Name + $azSqlVM.Sku + $string2
        }
    }

    #Iterate through all SQL Servers
    $AzureSQLServers = Get-AzResource  | Where-Object ResourceType -EQ Microsoft.SQL/servers
    foreach ($AzureSQLServer in $AzureSQLServers)
    {
        #Iterate through all SQL Server DBs that are not masters and have vCore-based purchasing model
        $AzureSQLServerDataBases = Get-AzSqlDatabase -ServerName $AzureSQLServer.Name -ResourceGroupName $AzureSQLServer.ResourceGroupName | Where-Object DatabaseName -NE "master" | ?{$_.Edition -match $AzureSQLDB_License}
        {
            
        } 
    }
}
$AzureVM | Export-Csv -Path "$($home)\AzVM-Windows_Server-Licensing-Change.csv" -NoTypeInformation -force
$AzureSQLVM | Export-Csv -Path "$($home)\AzVM-SQL_Std_Ent-Licensing-Change.csv" -NoTypeInformation -force
echo "Check AzVM-Windows_Server-Licensing-Change.csv for results on Windows Server license type changes......"
echo "Check AzVM-SQL_Std_Ent-Licensing-Change.csv for results on SQL Standard/Enterprise license type changes......"
