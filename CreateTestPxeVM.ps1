# Debugging
$VerbosePreference="Continue"

# HostName = name of the physical machine where Hyper-V runs (this machine?)
# VM name  = name of the VM that we want to build
$HostName="Gebruiker-PC"
$VMName="TestPxe"

# Directories
$VMBaseDirPath="D:\VMs"
$VirtualHardDiskPath="$VMBaseDirPath\Virtual Hard Disks"
$VMPath="$VMBaseDirPath\Virtual Machines"

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
  $continue=$true
  if (Test-Path $DirName -pathtype Container) {
	Write-Verbose "Path $DirName already exists, no problem"
  } else {
   	Write-Verbose "Create path $DirName"
    Try {
		New-Item -path $DirName -ItemType directory -ErrorAction Stop | Out-Null
	} Catch {
		Write-Verbose "Unable to create path $DirName"
		${global:continue}=$false
	}
  }
  return $continue
}  

function createVHD {
   param($DiskName)

   $continue=$true   
   if (Test-Path $DiskName -PathType Leaf) {
       Write-Warning "Disk $DiskName already exists, will be used for further deployment"
   } else {
       Write-Verbose "Create disk $DiskName"
	   Try {
	       New-VHD -Path "$DiskName" -SizeBytes $DiskSize -ErrorAction Stop | Out-Null
	   } Catch {
	       Write-Error "Create disk failed, command was: New-VHD -Path ${DiskName} -SizeBytes ${DiskSize} -ErrorAction Stop"
		   $continue=$false
	   }
	}
	return $continue
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
	}
	return $SwitchName
}

function testVMExists {
    param($HostName, $VMName)
	$continue=$true
    Try {
      Get-VM -ComputerName $HostName -VMName $VMName -ErrorAction Stop | Out-Null
	  Write-Error "$VMName already exists on $HostName, please configure by hand"
      $VMExists=$true
	  $continue=$false
	} Catch {
	  # Assume the error is caused by a non-existing VM, continue
	  Write-Verbose "VM $VMName doesn't exist on $HostName, continue..."
	  $VMExists=$false
	}
	return $continue
}

function createVM {
    param($VMName,$MemoryStartupBytes, $Generation, $VMPath, $DiskName, $SwitchName)
	Write-Verbose "Create new VM $VMName..."
	Try {
	    New-VM -Name $VMName -MemoryStartupBytes $MemoryStartupBytes -Generation $Generation -BootDevice LegacyNetworkAdapter -Path $VMPath -VHDPath $DiskName -SwitchName $SwitchName -ErrorAction Stop -ErrorVariable $v
	} Catch {
	    Write-Error "Error creating new VM: $v"
		$continue = $false
	}
}

function useDynamicMemory {
    param($VMName)
	
	$continue=$true
	$currentDynamicMemoryEnabled = (Get-VMMemory -VMName $VMName | Select -Property DynamicMemoryEnabled).DynamicMemoryEnabled
	if ($CurrentDynamicMemoryEnabled) {
	  Write-Verbose "Dynamic Memory is already enabled"
	} else {
	  Try {
	    Write-Verbose "Enable Dynamic Memory"
	    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled:$true
	  } Catch {
	    Write-Warning "Unable to enable Dynamic Memory, continue..."
	  }
	}
	return $continue
}

function numberOfProcessors {
    param($VMName, $numberOfProcessors)
	
	$continue = $true
	
	$currentNumberOfProcessors = (Get-VMProcessor -VMName $VMName | Select -Property Count).count
	if ($CurrentNumberOfProcessors -eq $numberOfProcessors) {
	  Write-Verbose "Already $numberOfProcessors processors"
	} else {
	  Try {
	    Write-Verbose "Change number of processors from $currentNumberOfProcessors to $numberOfProcessors"
	    Set-VMProcessor -VMName $VMName -count $numberOfProcessors
	  } Catch {
	    Write-Warning "Unable to change number of processors to $numberOfProcessors ..."
	  }
	}
	
	
	return $continue
}

function addNetworkAdapter {
  param($VMName,$SwitchName)
  
  $continue=$true
  Try {
    Write-Verbose "Add network adapter"
	Add-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName -IsLegacy:$false 
  } Catch {
    Write-Verbose "Error while adding network adapter"
  }
  return $continue
}

# Main program
$continue = createDirectory -DirName $VMBaseDirPath
if ($continue) { $continue   = createDirectory -DirName $VirtualHardDiskPath }
if ($continue) { $continue   = createDirectory -DirName $VMPath }
if ($continue) { $continue   = createVHD -DiskName $DiskName }
if ($continue) { $SwitchName = getSwitchName -SwitchType $SwitchType ; $continue = ($SwitchName -ne "")}
if ($continue) { $continue   = testVMExists -HostName $HostName -VMName $VMName }
if ($continue) { $continue   = createVM -VMName $VMName -MemoryStartupBytes $MemoryStartupBytes -Generation $Generation -VMPath $VMPath -DiskName $DiskName -SwitchName $SwitchName }
if ($continue) { $continue   = useDynamicMemory -VMName $VMName }
if ($continue) { $continue   = numberOfProcessors -VMName $VMName -NumberOfProcessors $NumberOfProcesses }
if ($continue) { $continue   = addNetworkAdapter -VMName $VMName -SwitchName $SwitchName }
