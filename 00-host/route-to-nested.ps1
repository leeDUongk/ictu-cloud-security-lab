# route-to-nested.ps1 (TUY CHON)
# Them route tren Windows de truy cap truc tiep VM long (172.16.100.0/24) qua VM ONE-Lab (192.168.50.10).
# Chay trong PowerShell (Administrator).
#   .\route-to-nested.ps1          # them route
#   .\route-to-nested.ps1 -Remove  # go route
# File nay chi dung ASCII (PowerShell 5.1 doc UTF-8 khong BOM se loi font).

param(
    [switch]$Remove,
    [string]$Network = "172.16.100.0",
    [string]$Mask = "255.255.255.0",
    [string]$Gateway = "192.168.50.10"
)

$ErrorActionPreference = "Stop"

if ($Remove) {
    route delete $Network
    Write-Host "Da go route toi $Network."
} else {
    # Khong dung -p de route mat sau khi khoi dong lai (phu hop moi truong lab)
    route add $Network mask $Mask $Gateway
    Write-Host "Da them route $Network/$Mask qua $Gateway."
    Write-Host "Kiem tra: ping 172.16.100.201 (sau khi hoan thanh Bai 3)."
}
