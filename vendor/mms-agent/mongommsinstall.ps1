$python64RegKey = "HKLM:\Software\Python\PythonCore\*"
$python32RegKey = "HKLM:\Software\Wow6432Node\Python\PythonCore\*"
$pythonExe = "python.exe"
$srvanyExe = "srvany.exe"
$scriptName = "agent.py"
$serviceName = "MongoMMS"
$serviceDisplayName = "MongoDB MMS"
$serviceDesc = "Service that runs the MongoDB Python MMS Script"
$serviceRegPath = Join-Path "HKLM:\SYSTEM\CurrentControlSet\Services\" $serviceName
$pyMongoTest = "pymongotest.py"
$pythonTest = "pythonversiontest.py"

function Test-PyMongo {
    Param($pythonPath)
    if ($pythonPath -eq $null) {
        return -1
    }
    $res = (Start-Process -FilePath $pythonPath `
       -ArgumentList $pyMongoTest -Wait -PassThru -NoNewWindow).ExitCode
    return $res
}

function Test-Python-Version {
    Param($pythonPath)
    if ($pythonPath -eq $null) {
        return -1
    }
    $res = (Start-Process -FilePath $pythonPath `
       -ArgumentList $pythonTest -Wait -PassThru -NoNewWindow).ExitCode
    return $res
}

function Test-ValidPython {
    Param($pythonPath)
    if ($pythonPath -eq $null) {
        return -1
    }
    $res = Test-Python-Version($pythonPath)
    if (!($res -eq 0)) {
        return $res
    }
    $res = Test-PyMongo($pythonPath)
    return $res
}
    
    

function Get-PythonPath {
    Param($location)
    if ($location -eq $null) {
        return Get-PythonRegistryPath
    }
    else {
        $pythonExePath = $null
        if (Test-Path -LiteralPath $location -PathType Leaf) {
            $pythonExePath = $location
        }
        else {
            if (Test-Path -Path $location -PathType Container) {
                $pythonExePath = Join-Path $location $pythonExe
                if (!(Test-Path -Path $pythonExePath -PathType Leaf)) {
                    $pythonExePath = $null
                }
            }
            else {
                Write-Error "Error: Python installation cannot be found. Service not installed"
                break
            }
        }
        $res = Test-ValidPython($pythonExePath)
        if ($res -eq 0) {
           return $pythonExePath
        }
    }
    return $null
}

function Get-PythonRegistryPath {
    $pythonRegPath = Get-ActualPythonRegistryPath($python64RegKey)
    if ($pythonRegPath -eq $null) {
        $pythonRegPath = Get-ActualPythonRegistryPath($python32RegKey)
    }
    return $pythonRegPath
}

function Get-ActualPythonRegistryPath {
    Param($registryBasePath)
    if (Test-Path -Path $registryBasePath -PathType Container) {
        $list = Get-Item $registryBasePath | select PSPath
        foreach ($regPath in $list) {
            $installPath = Join-Path $regPath.PSPath "InstallPath"
            if (Test-Path -Path $installPath) {
                $installPathValue = (Get-ItemProperty $installPath "(default)")."(default)"
                $installPathValue = Join-Path $installPathValue $pythonExe
                if (Test-Path -LiteralPath $installPathValue -PathType Leaf) {
                    $res = Test-ValidPython($installPathValue)
                    if ($res -eq 0) {
                       return $installPathValue
                    }
                }
            }
        }
    }
}

function Get-SrvanyPath {
    $currentPath = Resolve-Path .
    $exePath = Join-Path $currentPath $srvanyExe
    
    if (Test-Path -LiteralPath $exePath -PathType Leaf) {
        return $exePath
    }

    $progFilesPath = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    if ($progFilesPath -eq $null) {
        $progFilesPath = [Environment]::GetEnvironmentVariable("ProgramFiles")
    }
    $exePath = Join-Path $progFilesPath (Join-Path "\Windows Resource Kits\Tools" $srvanyExe)
    if (Test-Path -LiteralPath $exePath -PathType Leaf) {
        return $exePath
    }
    else {
        Write-Error "Error: Windows Resource Toolkit srvany not found"
        break
    }
}

function Create-MMSService {
    Param($execName)
    $svcList = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($svcList -eq $null -or $svcList.Count -eq 0) {
        New-Service -Name $serviceName -BinaryPathName $execName `
            -Description $serviceDesc -DisplayName $serviceDisplayName `
            -StartupType Automatic | Out-Null
    }
    else {
        Write-Error "Service already exists"
        break
    }
}

function Get-MMSScriptPath {
    $currentPath = Resolve-Path .
    $scriptPath = Join-Path $currentPath $scriptName
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
        return $scriptPath
    }
    else {
        Write-Error "Error: MMS Script not found"
        break
    }
}

function Modify-MMSService {
    $appDir = Get-Item $mmsScriptPath | Split-Path -parent
    $quotedAppDir = Quote-String($appDir)
    $quotedPythonPath = Quote-String($pythonPath)
    $quotedScriptPath = Quote-String($mmsScriptPath)
    $application = $quotedPythonPath+" "+$quotedScriptPath
    $parameterKey = Join-Path $serviceRegPath "Parameters"
    New-Item -Path  $parameterKey | Out-Null
    New-ItemProperty -Path $parameterKey -Name "Application" -Value $application | Out-Null
    New-ItemProperty -Path $parameterKey -Name "AppDir" -Value $quotedAppDir | Out-Null
}

function Start-MMSService {
    Start-Service -Name $serviceName
}

function Quote-String {
    Param($unquotedString)
    return "`"" + $unquotedString + "`""
}  

if ($args.Length -gt 0) {
    $pythonPath = Get-PythonPath($args[0])
}
else {
    $pythonPath = Get-PythonPath
}

if ($pythonPath -eq $null) {
    Write-Error -Message "Valid python install not found. Service not installed" `
    -Category NotInstalled
    Exit
}
    
$srvAnyPath = Get-SrvanyPath
$mmsScriptPath = Get-MMSScriptPath

Create-MMSService(Quote-String($srvAnyPath))
Modify-MMSService
Write-Host "Service succesfully created"
Start-MMSService
Write-Host "Service started"