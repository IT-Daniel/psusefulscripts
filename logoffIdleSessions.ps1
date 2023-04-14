<#

.SYNOPSIS
    Log off disconnected local sessions that are inactive for more than 30 minutes.

#>

if (query user | Select-String "Desc") {

    foreach($linea in @(query user | Select-String "Desc") -split "\n") {

        $usuario = $linea -split '\s+'

        #$Nombre = $usuario[1]
        $ID = $usuario[2]
        $Idle = $usuario[4]

        if ($Idle -gt 30{

            logoff $ID

        }

    }

} elseif (query user | Select-String "Disc"){
    
    foreach($linea in @(query user | Select-String "Disc") -split "\n") {

        $usuario = $linea -split '\s+'

        #$Nombre = $usuario[1]
        $ID = $usuario[2]
        $Idle = $usuario[4]

        if ($Idle -gt 30{

            logoff $ID

        }

    }

}