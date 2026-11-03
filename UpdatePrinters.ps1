#!PS
# Removes legacy IP-based printers/ports and deploys new office printers.

# --- Configuration ---
$TargetIPs = @(
    "192.168.55.10"
    "192.168.55.11"
    "192.168.55.12"
)

$NewPrinters = @(
    @{ Name = "Main Office Printer"; Address = "10.138.56.47" }
    @{ Name = "Sales Printer";       Address = "10.138.56.135" }
    @{ Name = "Upstairs Printer";    Address = "10.138.56.238" }
)

# --- Driver Discovery ---
$CanonDrivers = Get-PrinterDriver | Where-Object Name -like "*Canon*" | Select-Object -ExpandProperty Name

if ($CanonDrivers) {
    if ($CanonDrivers -is [array]) {
        Write-Host "Found multiple Canon drivers:" -ForegroundColor Yellow
        $CanonDrivers | ForEach-Object { Write-Host " - $_" }
        
        $PrimaryCanonDriver = $CanonDrivers[0]
        Write-Host "`nAssigned '$PrimaryCanonDriver' as `$PrimaryCanonDriver (First available)" -ForegroundColor Green
    }
    else {
        $PrimaryCanonDriver = $CanonDrivers
        Write-Host "Found a single Canon driver: $PrimaryCanonDriver" -ForegroundColor Green
    }
}
else {
    Write-Warning "No Canon drivers found on this system. Printer deployment may fail or use default fallback."
    $PrimaryCanonDriver = $null
}



# --- Legacy Cleanup Loop ---
foreach ($IP in $TargetIPs) {
       
    # Identify legacy printers hitting this IP
    $Printers = Get-Printer | Where-Object PortName -like "*$IP*"

    if ($Printers) {
        foreach ($Printer in $Printers) {
            # Clear print jobs to avoid 'printer in use' blocks
            $Jobs = Get-PrintJob -PrinterName $Printer.Name -ErrorAction SilentlyContinue
            if ($Jobs) {
                $Jobs | Remove-PrintJob -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }

            Write-Host "  -> Removing printer: $($Printer.Name)" -ForegroundColor Yellow
            Remove-Printer -Name $Printer.Name
        }
    }
    else {
        Write-Host "  -> No printers found associated with IP: $IP" -ForegroundColor DarkGray
    }

    # Identify and clean legacy ports
    $Ports = Get-PrinterPort | Where-Object Name -like "*$IP*"

    if ($Ports) {
        foreach ($Port in $Ports) {
            Write-Host "  -> Removing printer port: $($Port.Name)" -ForegroundColor Red
            Remove-PrinterPort -Name $Port.Name
        }
    }
    else {
        Write-Host "  -> No printer ports found matching IP: $IP" -ForegroundColor DarkGray
    }
}

# --- New Printer Provisioning ---
Write-Host "`nDeploying new network printers..." -ForegroundColor Cyan

foreach ($Printer in $NewPrinters) {
    Write-Host "Installing: $($Printer.Name) ($($Printer.Address))" -ForegroundColor Green
    
    Add-PrinterPort -Name $Printer.Name -PrinterHostAddress $Printer.Address -ErrorAction SilentlyContinue
    
    $PrinterParams = @{
        Name       = $Printer.Name
        PortName   = $Printer.Name
        DriverName = $PrimaryCanonDriver
    }
    Add-Printer @PrinterParams
}

#List All installed Printers
Get-Printer | Format-Table Name, ComputerName, PortName