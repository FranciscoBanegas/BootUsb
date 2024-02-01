# PowerShell Script for UEFI Version Gui
# Author: Francisco Banegas
# Repository: https://github.com/franciscobanegas
# Date: 12/01/2024

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.drawing
$form = New-Object System.Windows.Forms.Form -Property @{
    Font = "Comic Sans MS"
    Text = "Bootloader UEFI"
    Size = '300, 500'
    # TopMost = $true
}
#####################################
######Seleciona Unidad Usb###########
#####################################
$selecUsb = New-Object System.Windows.Forms.ComboBox -Property @{
    Text     = "Seleciona Unidad Usb"
    Location = '40,40'
    Size     = '200, 50'
    AutoSize = $true
}
#Bucle
Get-Disk | ForEach-Object {
    if ($_.BusType -eq 'USB') {
        $selecUsb.Items.AddRange(@($_.FriendlyName))
    }
}
########################################
############Elegir ISO##################
#######################################
$SelectImage = New-Object System.Windows.Forms.button -Property @{
    Location = '80,80'
    Size     = '120, 50'
    Text     = "Elegir ISO"
}
$ImageIso = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('Desktop')
    Filter           = 'ISO (*.iso)|*.iso'
}
########################################
############Input Name##################
#######################################
$Nombre = New-Object System.Windows.Forms.TextBox -Property @{
    Location = '40,160'
    Size     = '200, 50'
    Text     = "Nombre de la unidad USB"
}
########################################
############MBR or GPT##################
#######################################
$Group = New-Object System.Windows.Forms.GroupBox -Property @{
    Location = '40,200'
    Size     = '200, 50'
    Text     = "Tipo de Particion"
}
$GPT = New-Object System.Windows.Forms.RadioButton -Property @{
    Location  = '40,20'
    Size      = '50, 20'
    Text      = "GPT"
    Checked   = $true
    BackColor = "transparent"
}
$MBR = New-Object System.Windows.Forms.RadioButton -Property @{
    Location  = '110,20'
    Size      = '50, 20'
    Text      = "MBR"
    BackColor = "transparent"
}
$Group.Controls.AddRange(@($GPT, $MBR))
$Iniciar = New-Object System.Windows.Forms.Button -Property @{
    Location = '80,380'
    Size     = '120, 50'
    AutoSize = $true
    Text     = "Iniciar"
}
function USBBootloader {
    $usbDrive = $selecUsb.Text
    Write-Host $usbDrive
    #Limpiar USB 
    Clear-Disk -FriendlyName $usbDrive -RemoveData -Confirm:$false -PassThru
    $Number = Get-Disk -FriendlyName $usbDrive | Select-Object -ExpandProperty Number
    Write-Host $Number
    # Inicializar el disco con el estilo de partición seleccionado
    # if ($GPT.Checked -eq $true) {
    #     Initialize-Disk -Number $Number -PartitionStyle "GPT" -PassThru
    # } elseif ($MBR.Checked -eq $true) {
    #     Initialize-Disk -Number $Number -PartitionStyle "MBR" -PassThru 
    # }
    $ubsPartition = New-Partition -DiskNumber $Number -UseMaximumSize
    Write-Host $ubsPartition
    $ubsPartition | Format-Volume -FileSystem FAT32 -NewFileSystemLabel $Nombre.Text  -Confirm:$false
    Add-PartitionAccessPath -DiskNumber $Number -PartitionNumber $ubsPartition.PartitionNumber -AssignDriveLetter
    #Montar image ISO
    Mount-DiskImage -ImagePath $ImageIso.FileName
    $isoDrive = (Get-DiskImage -ImagePath $ImageIso.FileName | Get-Volume).DriveLetter
    $IsoRouter = $isoDrive + ":\"
    #Copiar ISO
    $DestinationPath = Get-Volume -FriendlyName $Nombre.Text | Select-Object -ExpandProperty DriveLetter
    Write-Host $DestinationPath
    $ResultDestinationPath = $DestinationPath + ":\"
    Write-Host $ResultDestinationPath
    <##
     Copiamos los archivos de la ISO a la ruta de destino pero no copiamos el install.win 
     Hasta su conversion a .swm
     ##>
    robocopy $IsoRouter $ResultDestinationPath /E /COPYALL /R:0 /W:0 /V
    ########################################
    ##########Conversion a .Swm############
    #######################################
    if (test-path 'C:\temp') { 
        Write-Host 'ya existe la carpeta por favor remueva o renombrela para poder continuar'
    }
    else {
        New-Item -Path 'C:\' -Name "temp" -ItemType "directory"
        #  Filter router
        $origin = $IsoRouter + "sources\install.wim"
        $destination = 'C:\temp\install.swm'
        Write-Host $destination
        #Create format .swm
        Dism /Split-Image /ImageFile:$origin /SWMFile:$destination /FileSize:3500
        #Copy .swm
        start-sleep -Seconds 5
        Write-Host 'Copiando .swm'
        robocopy "C:\temp" "$ResultDestinationPath\sources" "*.swm" /COPYALL /R:3 /W:5 
        #Desmontar ISO
        Write-Host 'Limpiando residuos'
        Start-Sleep -Seconds 5
        Dismount-DiskImage -ImagePath $ImageIso.FileName    
        start-sleep -Seconds 5
        Remove-Item -Path 'C:\temp' -Recurse -Force
    }
}
$Iniciar.add_click({
        USBBootloader
    })
$SelectImage.add_click({
        $ImageIso.ShowDialog()
        $form.Text = $ImageIso.FileName
    })
$form.Controls.AddRange(@($Iniciar, $SelectImage, $Nombre, $selecUsb))
$form.showdialog()
$form.dispose()