# EnableAppRouting.psm1
function Enable-AppRouting {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$ClusterName
    )

    # Set Kubernetes context
    az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName

    # Enable application routing
    az aks approuting enable --resource-group $ResourceGroupName --name $ClusterName

}

Export-ModuleMember -Function Enable-AppRouting