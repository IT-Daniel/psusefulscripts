<#

.SYNOPSIS

    El propósito de este script es recopilar información relevante para realizar una auditoría de la identidad y gobernanza de un tenant de Azure.

.MÓDULOS

    Install-Module Az.Accounts
    Install-Module AzureAD
    Install-Module Microsoft.Graph    

.COMANDOS

    Conexión a Azure (acceso a recursos): Connect-AzAccount
    Conexión a Azure (acceso a Azure AD): Connect-AzureAD
    Conexión a Microsoft Graph: Connect-MgGraph
    Conectar a Azure AD PIM: 
    
    Obtener ID de suscripción: Get-AzSubscription
    Seleccionar suscripción: Set-AzContext

    Listar asignación de roles: Get-AzRoleAssignment
    Listar usuarios invitados con roles asignados: Get-AzRoleAssignment | where {($_.ObjectType -eq 'User') -and ($_.SignInName -like "*#EXT#*")}
    Listar usuarios invitados: Get-AzureADUser -All $true | where {$_.UserType -eq "Guest"}

    Obtener información sobre un rol: Get-AzureADMSRoleDefinition | where {$_.Id -eq $response.roleDefinitionId}    - La variable $resposne se obtiene mediante la consulta Graph. -
        
.COMANDOS DESCARTADOS

    Hace la misma función que 'Get-AzureADUser, pero el atributo 'UserType' no devuelve valor:
    Get-AzADUser | where {$_.userPrincipalName -like "*#EXT#*"}

    Alternativa al comando utilizado para buscar los usuarios 'Guest':
    Get-AzureADUser -All $true | where {$_.userPrincipalName -like "*#EXT#*"}

    Ya no hay módulo de PowerShell para administrar PIM, ahora se hace por Graph.
    Install-Module Microsoft.Azure.ActiveDirectory.PIM.PSModule | Connect-PimService

#>

function ConexionesNecesarias {

    Connect-AzAccount
    Connect-AzureAD
    Disconnect-MgGraph
    Remove-Item "$env:USERPROFILE\.graph" -Recurse -Force
    Connect-MgGraph -Scope Directory.Read.All, Directory.ReadWrite.All, RoleManagement.Read.Directory, RoleManagement.ReadWrite.Directory

}

function CambiarContextoSuscripcion {

    $suscripcion = Get-AzSubscription | where {$_.Name -like "*Nombre de la suscripción*"} | foreach {$_.Id}
    Set-AzContext -Subscription $suscripcion

}

function ListarPermisosSuscripcion {

    $returnObj = @()
    
    $suscripciones = Get-AzSubscription
    
    foreach ($suscripcion in $suscripciones) {

        $id = $suscripcion.Id
        $nombre = $suscripcion.Name

        $roles = Get-AzRoleAssignment -Scope "/subscriptions/$id" | where {$_.DisplayName -ne '' -and ($_.ObjectType -eq 'User' -or $_.ObjectType -eq 'Group')} | Select DisplayName, RoleDefinitionName

        foreach ($usuario in $roles) {

            $obj = New-Object psobject -Property @{

                "Suscripcion" = $nombre;
                "Usuario" = $usuario.DisplayName;
                "Rol" = $usuario.RoleDefinitionName

            }
            
            $returnObj += $obj | Select Suscripcion, Usuario, Rol        

        }       

    }

    #echo $returnObj
    $returnObj | Export-CSV 'C:\List\rolesSUS.csv' -NoTypeInformation

}

function ListarPermisosRG {

    $returnObj = @()

    $suscripciones = Get-AzSubscription
    
    foreach ($suscripcion in $suscripciones) {

        Set-AzContext -Subscription $suscripcion

        $gruposderecurso = Get-AzResourceGroup | foreach {$_.ResourceGroupName}
    
        foreach ($grupo in $gruposderecurso) {

            $roles = Get-AzRoleAssignment -ResourceGroupName $grupo | where {$_.DisplayName -ne '' -and ($_.ObjectType -eq 'User' -or $_.ObjectType -eq 'Group')} | Select DisplayName, RoleDefinitionName

            foreach ($usuario in $roles) {

                $obj = New-Object psobject -Property @{

                    "Suscripcion" = $suscripcion.Name;
                    "GrupoDeRecursos" = $grupo;
                    "Usuario" = $usuario.DisplayName;
                    "Rol" = $usuario.RoleDefinitionName

                }
            
                $returnObj += $obj | Select Suscripcion, GrupoDeRecursos, Usuario, Rol        

            }               

        }

    }

    #echo $returnObj
    $returnObj | Export-CSV 'C:\List\rolesRG.csv' -NoTypeInformation

}

function ListarPermisosDirectorio {

    $returnObj = @()

    $list = Get-AzRoleAssignment | where {$_.ObjectType -eq 'User'}

    foreach ($usuario in $list) {

        if ($usuario.Scope -eq '/') {

            $usuario.Scope = 'Todo el directorio'

        }

        if ($usuario.SignInName -like "*#EXT#*") {

            $obj = New-Object psobject -Property @{

                "Usuario" = $usuario.DisplayName;
                "Tipo" = "Invitado";
                "Rol" = $usuario.RoleDefinitionName;
                "Ambito" = $usuario.Scope

            }

            $returnObj += $obj | Select Usuario, Tipo, Rol, Ambito

        } else {

            $obj = New-Object psobject -Property @{

                "Usuario" = $usuario.DisplayName;
                "Tipo" = "Miembro";
                "Rol" = $usuario.RoleDefinitionName;
                "Ambito" = $usuario.Scope

            }

            $returnObj += $obj | Select Usuario, Tipo, Rol, Ambito

        }

    }

    #echo $returnObj
    $returnObj | Export-CSV 'C:\List\rolesdirectorio.csv' -NoTypeInformation
    
}

function AzureADRoles {

    # Obtener usuarios del tenant
    $usuarios = Get-AzureADUser -All $true | where {$_.UserType -ne $null}

    $returnObj = @()

    foreach ($usuario in $usuarios) {
    
        $objectId = $usuario.ObjectId

        # Necesario tener una sesión iniciada en MgGraph previamente.
        $response = $null
        $uri = "https://graph.microsoft.com/beta/roleManagement/directory/transitiveRoleAssignments?`$count=true&`$filter=principalId eq '$objectId'"
        $method = 'GET'
        $headers = @{'ConsistencyLevel' = 'eventual'}
        $response = (Invoke-MgGraphRequest -Uri $uri -Headers $headers -Method $method -Body $null).value

        foreach ($rol in $response) {

            $roles = ""
            $rol = Get-AzureADMSRoleDefinition | where {$_.Id -eq $rol.roleDefinitionId}
            $rol = $rol.DisplayName
            
            $obj = New-Object psobject -Property @{

                "Usuario" = $usuario.DisplayName;
                "Tipo" = $usuario.UserType;
                "Rol" = $rol
    
            }

            $returnObj += $obj | Select Usuario, Tipo, Rol

        }

    }

    #echo $returnObj
    $returnObj | Export-CSV 'C:\List\azureadroles.csv' -NoTypeInformation

}


# EJECUCIÓN

ConexionesNecesarias
ListarPermisosSuscripcion
ListarPermisosRG
ListarPermisosDirectorio
AzureADRoles