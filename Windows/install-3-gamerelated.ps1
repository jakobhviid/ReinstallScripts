Write-Output "Installing hardware related helper tools"
winget install --id=Logitech.GHUB -e --silent

Write-Output "Installing Game Related Packages"
winget install --id=Valve.Steam -e --silent
winget install --id=ElectronicArts.EADesktop -e --silent
winget install --id=Ubisoft.Connect -e --silent
winget install --id=EpicGames.EpicGamesLauncher -e --silent
winget install --id=Nvidia.GeForceExperience -e --silent