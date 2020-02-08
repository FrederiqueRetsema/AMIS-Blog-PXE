# CreateLinuxPXE.ps1
# ------------------
# Written as part of a blog on the AMIS website, see https://technology.amis.nl or the pdf in this repository for more information
#

# Please look carefully to these settings, these will be used for configuration of the Hyper-V VM on your local machine
#

# Debugging
$VerbosePreference="Continue"

# HostName = name of the physical machine where Hyper-V runs (this machine?)
# VM name  = name of the VM that we want to build
$HostName="Gebruiker-PC"
$VMName="LinuxPxe"

# Directories
$VMBaseDirPath="D:\VMs"
$VirtualHardDiskPath="$VMBaseDirPath\Virtual Hard Disks"
$VMPath="$VMBaseDirPath\Virtual Machines"
$DVDISOFile="D:\Install\CentOS\CentOS-8-x86_64-1905-dvd1.iso"

# Components of the VM
$DiskName="$VirtualHardDiskPath\$VMName.vhdx"

# Other parameters
$continue=$True
$NumberOfProcesses=2
$DiskSize=129Gb
$MemoryStartupBytes=2048Mb
$Generation=1
$SwitchType="external"
$SwitchName=""
$VMExists=$false

function createDirectory {
  param ($DirName)

  if (Test-Path $DirName -pathtype Container) {
	Write-Verbose "Path $DirName already exists, no problem"
  } else {
   	Write-Verbose "Create path $DirName"
    Try {
		New-Item -path $DirName -ItemType directory -ErrorAction Stop | Out-Null
	} Catch {
		Write-Verbose "Unable to create path $DirName"
		exit 1
	}
  }
}  

function createVHD {
   param($DiskName)

   if (Test-Path $DiskName -PathType Leaf) {
       Write-Warning "Disk $DiskName already exists, will be used for further deployment"
   } else {
       Write-Verbose "Create disk $DiskName"
	   Try {
	       New-VHD -Path "$DiskName" -SizeBytes $DiskSize -ErrorAction Stop | Out-Null
	   } Catch {
	       Write-Error "Create disk failed, command was: New-VHD -Path ${DiskName} -SizeBytes ${DiskSize} -ErrorAction Stop"
		   exit 2
	   }
	}
}

function getSwitchName {
	param($SwitchType)

   	Write-Verbose "Get name of the $SwitchType switch"
	Try {
	    $SwitchName = (Get-VMSwitch -SwitchType $SwitchType -ErrorAction Stop -ErrorVariable $ev)[0].Name
   	    Write-Verbose "Name of the $SwitchType switch = $SwitchName"
	} Catch {
	    Write-Error "Error: $v"
		Write-Error "Cannot determine switchname for $SwitchType switch"
		exit 3
	}
	return $SwitchName
}

function testVMExists {
    param($HostName, $VMName)

    Try {
      Get-VM -ComputerName $HostName -VMName $VMName -ErrorAction Stop | Out-Null
	  Write-Error "$VMName already exists on $HostName, please configure by hand"
	  exit 4
	} Catch {
	  # Assume the error is caused by a non-existing VM, continue
	  Write-Verbose "VM $VMName doesn't exist on $HostName, continue..."
	}
}

function createVM {
    param($VMName,$MemoryStartupBytes, $Generation, $VMPath, $DiskName, $SwitchName)
	Write-Verbose "Create new VM $VMName..."
	Try {
	    New-VM -Name $VMName -MemoryStartupBytes $MemoryStartupBytes -Generation $Generation -BootDevice CD -Path $VMPath -VHDPath $DiskName -SwitchName $SwitchName -ErrorAction Stop -ErrorVariable $v
	} Catch {
	    Write-Error "Error creating new VM: $v"
		exit 5
	}
}

function insertDVD {
    param($VMName, $DVDISOFile)
	
	Write-Verbose "Insert DVD $DVDISOFile ..."
	Try {
	    Set-VMDVDDrive -VMName $VMName -Path $DVDISOFile -Controllernumber 1 -ControllerLocation 0 -ErrorAction Stop
	} Catch {
	    Write-Error "Error while inserting DVD ISO $DVDISOFile in the VM $VMName"
		exit 6
	}
}

function useDynamicMemory {
    param($VMName)
	
	$currentDynamicMemoryEnabled = (Get-VMMemory -VMName $VMName | Select -Property DynamicMemoryEnabled).DynamicMemoryEnabled
	if ($CurrentDynamicMemoryEnabled) {
	  Write-Verbose "Dynamic Memory is already enabled"
	} else {
	  Try {
	    Write-Verbose "Enable Dynamic Memory"
	    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled:$true
	  } Catch {
	    Write-Error "Unable to enable Dynamic Memory, continue..."
	  }
	}
}

function numberOfProcessors {
    param($VMName, $numberOfProcessors)
	
	$currentNumberOfProcessors = (Get-VMProcessor -VMName $VMName | Select -Property Count).count
	if ($CurrentNumberOfProcessors -eq $numberOfProcessors) {
	  Write-Verbose "Already $numberOfProcessors processors"
	} else {
	  Try {
	    Write-Verbose "Change number of processors from $currentNumberOfProcessors to $numberOfProcessors"
	    Set-VMProcessor -VMName $VMName -count $numberOfProcessors
	  } Catch {
	    Write-Error "Unable to change number of processors to $numberOfProcessors ..."
	  }
	}
	
	
	return $continue
}
# Main program
createDirectory -DirName $VMBaseDirPath
createDirectory -DirName $VirtualHardDiskPath 
createDirectory -DirName $VMPath 

createVHD -DiskName $DiskName 
$SwitchName = getSwitchName -SwitchType $SwitchType

testVMExists -HostName $HostName -VMName $VMName 
createVM -VMName $VMName -MemoryStartupBytes $MemoryStartupBytes -Generation $Generation -VMPath $VMPath -DiskName $DiskName -SwitchName $SwitchName 
insertDVD -VMName $VMName -DVDISOFile $DVDISOFile 
useDynamicMemory -VMName $VMName 
numberOfProcessors -VMName $VMName -NumberOfProcessors $NumberOfProcesses 
