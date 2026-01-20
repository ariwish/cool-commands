function Show-Welcome {
    $e = [char]27
    $blu = "$e[36m"; $mag = "$e[35m"; $grn = "$e[32m"; $rst = "$e[0m"
    $osObj = Get-CimInstance Win32_OperatingSystem
    $os = $osObj.Caption
    $cpu = (Get-CimInstance Win32_Processor).Name
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    
    $memUsed = [math]::Round(($osObj.TotalVisibleMemorySize - $osObj.FreePhysicalMemory)/1KB)
    $memTotal = [math]::Round($osObj.TotalVisibleMemorySize/1KB)
    $uptime = (Get-Date) - $osObj.LastBootUpTime
    $disk = Get-PSDrive C | % { "{0}GB / {1}GB" -f [math]::Round(($_.Used/1GB),2), [math]::Round(($_.Used + $_.Free)/1GB) }

    $f = "{0,-46} {1}" # Increased width slightly for the new offset
    Write-Host ""      # Blank line at the top
    
    $lines = @(
        ($f -f " ${blu}          .=:!!t3Z3z.,", "${mag}$env:USERNAME@$env:COMPUTERNAME"), # Added 1 space
        ($f -f " ${blu}         :tt:::tt333EE3", "${rst}-------------------"),       # Added 1 space
        ($f -f " ${blu}         Et:::ztt333EEEL @Ee.,  . .", "${grn}OS: ${rst}$os"), # Added 1 space
        ($f -f "${blu}         ;tt:::tt333EE7 ;EEEEEttttt33#", "${grn}Host: ${rst}$env:COMPUTERNAME"),
        ($f -f "${blu}        :Et:::zt333EEQ. `$EEEEEttttt33", "${grn}Kernel: ${rst}$([Environment]::OSVersion.Version)"),
        ($f -f "${blu}       it::::tt333EEF @EEEEEttttt33F", "${grn}Uptime: ${rst}$($uptime.Hours)h $($uptime.Minutes)m"),
        ($f -f "${blu}      ;3=^\ ^^^`"4EEV :EEEEEttttt33@.", "${grn}Packages: ${rst}Scoop/Winget"),
        ($f -f "${blu}     ,.=::::!t=.,  `` @EEEEEtttz33QF", "${grn}Shell: ${rst}PS $($PSVersionTable.PSVersion)"),
        ($f -f "${blu}    ;::::::::zt33)", "${grn}CPU: ${rst}$cpu"),
        ($f -f "${blu}   :t:::::::tt33.:Z3z..  `` ,..g.", "${grn}GPU: ${rst}$gpu"),
        ($f -f "${blu}  i::::::::zt33F AEEEtttt::::ztF", "${grn}Memory: ${rst}$memUsed MiB / $memTotal MiB"),
        ($f -f "${blu} ;::::::::t33V  ;EEettttt::::t3", "${grn}Disk (C:): ${rst}$disk"),
        ($f -f "${blu} E::::::::zt33L @EEetttt::::z3F", ""),
        ($f -f "${blu}{3=*^\`"````*4E3} ;EEetttt::::zZ`"", ""),
        ($f -f "              ${blu}:EEetttt::::z7", ""), # Added 1 space
        ($f -f "${blu}               `"VEzjt:;;;z>`"", "$e[40m  $rst$e[41m  $rst$e[42m  $rst$e[43m  $rst$e[44m  $rst$e[45m  $rst$e[46m  $rst$e[47m  $rst")
    )

    foreach ($l in $lines) { Write-Host $l }
    Write-Host "" 
}

Clear-Host
Show-Welcome