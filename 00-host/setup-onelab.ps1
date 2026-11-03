# ============================================================
#  ONE-Lab: Hyper-V VM for "An toan dien toan dam may" (ICTU)
#  Runs side by side with WSL2. Nested KVM for OpenNebula miniONE.
#  Run:  powershell -ExecutionPolicy Bypass -File .\setup-onelab.ps1
#  (Admin PowerShell). Run twice if Hyper-V was not enabled yet.
# ============================================================
#Requires -RunAsAdministrator
param(
    [string]$IsoPath = "D:\setup\ubuntu-24.04.4-desktop-amd64.iso"   # or: -IsoPath "D:\path\file.iso"
)

# ============================================================
#  EDIT THIS BLOCK TO MATCH YOUR COMPUTER, THEN SAVE THE FILE
#  (open this file in Notepad, change the numbers, run the script)
# ============================================================
#
#  Check your computer first:  Task Manager > Performance > Memory (RAM) and CPU (logical processors).
#
#  Suggested VM size by the RAM of your Windows computer:
#
#      Windows RAM    $RAM (VM)   $CPU (vCPU)
#      -----------    ---------   -----------
#      24 GB or more    12 GB        6        <- the tested configuration
#      16 GB             8 GB        4
#      12 GB             6 GB        4
#       8 GB             4 GB        2        <- lowest allowed; may be slow or fail
#
#  Rules: keep at least 3 GB RAM free for Windows; $CPU must not exceed your logical processors.
#  Only 12 GB / 6 vCPU has been tested. Smaller sizes are suggestions.
#
$RAM     = 12GB                 # RAM for the VM: 4GB, 6GB, 8GB or 12GB (keep the "GB" after the number)
$CPU     = 6                    # number of virtual CPUs for the VM
$Disk    = 80GB                 # maximum size of the virtual disk (at least 40GB; it grows only as it is used)
$VMPath  = "D:\HyperV"          # folder for the VM files; no D: drive? use "C:\HyperV" (needs free space)
# ------------------------------------------------------------
#  Do not change below this line unless you know what you do
# ------------------------------------------------------------
$VMName  = "ONE-Lab"
$Switch  = "ONE-Lab"
$HostIP  = "192.168.50.1"
$Prefix  = "192.168.50.0/24"
# ============================================================

function Info($m){ Write-Host ">> $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "!! $m" -ForegroundColor Yellow }
function Fail($m){ Write-Host "XX $m" -ForegroundColor Red; exit 1 }

# 0. Windows 11 required for nested virtualization on AMD
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
Info "OS: $($os.Caption)  build $build"
if ($build -lt 22000) {
    Write-Error "Nested virtualization on AMD needs Windows 11 (build >= 22000). Use VMware + no-Hyper-V boot entry instead."
    exit 1
}

# 1. Enable Hyper-V (WSL2 keeps working)
$hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($hv.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart | Out-Null
    Warn "Hyper-V enabled. REBOOT, then run this script again."
    exit 0
}
Info "Hyper-V: enabled"

# 1b. Check the numbers you set above against this computer (stops before changing anything)
$cs        = Get-CimInstance Win32_ComputerSystem
$hostRamGB = [int][math]::Ceiling($cs.TotalPhysicalMemory / 1GB)   # a "8 GB" PC often reports ~7.4 GB; round up
$hostCpus  = [int]$cs.NumberOfLogicalProcessors
$ramGB     = [int]($RAM / 1GB)
$diskGB    = [int]($Disk / 1GB)
Info "This computer: $hostRamGB GB RAM, $hostCpus logical CPUs"
Info "VM config you set: $ramGB GB RAM (static), $CPU vCPU, $diskGB GB disk max, files in $VMPath"

if ($ramGB -lt 4)                { Fail "`$RAM is $ramGB GB. It must be at least 4GB. Edit the block at the top of this file." }
if ($hostRamGB - $ramGB -lt 3)   { Fail "`$RAM is $ramGB GB but this computer has only $hostRamGB GB. Keep at least 3 GB free for Windows (try $([math]::Max(4, $hostRamGB - 4))GB). Edit the block at the top of this file." }
if ($CPU -lt 2)                  { Fail "`$CPU is $CPU. It must be at least 2. Edit the block at the top of this file." }
if ($CPU -gt $hostCpus)          { Fail "`$CPU is $CPU but this computer has only $hostCpus logical CPUs. Edit the block at the top of this file." }
if ($diskGB -lt 40)              { Fail "`$Disk is $diskGB GB. It must be at least 40GB. Edit the block at the top of this file." }
$drive = Split-Path -Qualifier $VMPath
if (-not $drive -or -not (Test-Path "$drive\")) { Fail "Drive for `$VMPath ($VMPath) does not exist. Edit `$VMPath at the top of this file." }
$freeGB = [math]::Round((Get-PSDrive ($drive.TrimEnd(':'))).Free / 1GB, 1)
if ($freeGB -lt $diskGB) { Warn "Drive $drive has $freeGB GB free, less than the $diskGB GB maximum disk size. The disk grows with use; make room or lower `$Disk." }
if ($ramGB -lt 12 -or $CPU -lt 6) { Warn "Only 12 GB RAM and 6 vCPU were tested. With $ramGB GB and $CPU vCPU the install can be slow or fail." }

# 2. Internal switch + fixed host IP + NAT
if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name $Switch -SwitchType Internal | Out-Null
    Info "Created switch $Switch"
}
$ifAlias = "vEthernet ($Switch)"
if (-not (Get-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $HostIP -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -IPAddress $HostIP -PrefixLength 24 -InterfaceAlias $ifAlias | Out-Null
    Info "Host IP $HostIP on $ifAlias"
}
if (-not (Get-NetNat -Name "$Switch-NAT" -ErrorAction SilentlyContinue)) {
    $other = Get-NetNat -ErrorAction SilentlyContinue
    if ($other) { Warn "Existing NAT found: $($other.Name -join ', '). If New-NetNat fails, remove the old one (Remove-NetNat)." }
    New-NetNat -Name "$Switch-NAT" -InternalIPInterfaceAddressPrefix $Prefix -ErrorAction Stop | Out-Null
    Info "NAT $Prefix created"
}

# 3. VM
if (-not (Test-Path $IsoPath)) { Write-Error "ISO not found: $IsoPath"; exit 1 }
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    New-Item -ItemType Directory -Force -Path "$VMPath\$VMName" | Out-Null
    New-VM -Name $VMName -Generation 2 -MemoryStartupBytes $RAM -Path $VMPath `
           -NewVHDPath "$VMPath\$VMName\$VMName.vhdx" -NewVHDSizeBytes $Disk -SwitchName $Switch | Out-Null
    Info "Created VM $VMName"
    $vm = Get-VM -Name $VMName
}
if ($vm.State -ne "Off") { Warn "VM is not Off - shut it down to apply CPU/RAM settings."; exit 1 }

Set-VMProcessor     -VMName $VMName -Count $CPU -ExposeVirtualizationExtensions $true
Set-VMMemory        -VMName $VMName -DynamicMemoryEnabled $false -StartupBytes $RAM
Set-VMNetworkAdapter -VMName $VMName -MacAddressSpoofing On
Set-VMFirmware      -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
if (-not (Get-VMDvdDrive -VMName $VMName)) { Add-VMDvdDrive -VMName $VMName -Path $IsoPath }
Set-VMFirmware      -VMName $VMName -FirstBootDevice (Get-VMDvdDrive -VMName $VMName)
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false -CheckpointType Standard
Info "VM configured: $CPU vCPU, $($RAM/1GB) GB RAM (static), nested virt ON, MAC spoofing ON"

# 4. Start + open console
Start-VM -Name $VMName
vmconnect.exe localhost $VMName

Write-Host ""
Write-Host "=== Ubuntu Desktop installer ===" -ForegroundColor Green
Write-Host "  No DHCP on this switch: choose 'Do not connect to the internet', skip updates."
Write-Host "  After first login, open Terminal and run:"
Write-Host "    nmcli con show                       # note the wired connection NAME"
Write-Host "    sudo nmcli con mod `"<NAME>`" ipv4.method manual ipv4.addresses 192.168.50.10/24 ipv4.gateway 192.168.50.1 ipv4.dns `"8.8.8.8 1.1.1.1`""
Write-Host "    sudo nmcli con up `"<NAME>`""
Write-Host "    sudo apt update && sudo apt -y install openssh-server"
Write-Host "Then eject ISO (Set-VMDvdDrive -VMName $VMName -Path `$null) and:"
Write-Host "  Checkpoint-VM -Name $VMName -SnapshotName clean-os"
