<#
    DESCRIPTION: 
        Check relevant monitoring tool agent is installed and that the correct port is open to the management server



    PASS:    {0} found, Port {1} open to {2}
    WARNING:
    FAIL:    Monitoring software not found, install required / {0} found, Agent not configured with port and/or servername / {0} found, Port {1} not open to {2}
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS: Win32_Product, Test-Port
#>

Function c-com-02-scom-monitoring-installed
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-com-02-scom-monitoring-installed'

    #... CHECK STARTS HERE ...#

    Try
    {
        [boolean]$found = $false
        $script:appSettings['ProductNames'] | ForEach {
            [string]$verCheck = Win32_Product -serverName $serverName -displayName $_
            If ([string]::IsNullOrEmpty($verCheck) -eq $false)
            {
                $found            = $true
                [string]$prodName = $_
                [string]$prodVer  = $verCheck
            }
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('Software\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups')
        If ($regKey) {
            [string[]]$regSubKey = $regKey.GetSubKeyNames()
            If ($regSubKey.Count -gt 0) {
                $regKey = $null
                $regKey = $reg.OpenSubKey("Software\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups\$($regSubKey[0])\Parent Health Services\0")
                If ($regkey) {
                    [string]$valName = $regKey.GetValue('NetworkName')
                    [string]$valPort = $regKey.GetValue('Port')
                }
            }
        }
        Try {$regKey.Close() } Catch {}
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($found -eq $true)
    {
        If (([string]::IsNullOrEmpty($valName) -eq $false) -and ([string]::IsNullOrEmpty($valPort) -eq $false))
        {
            [boolean]$portTest = (Test-Port -serverName $valName -Port $valPort)
            If ($portTest -eq $true)
            {
                $result.result  = $script:lang['Pass']
                $result.message = '{0} found' -f $prodName
                $result.data    = 'Version {0},#Port {1} open to {2}' -f $prodVer, $valPort, $valName
            }
            Else
            {
                $result.result  = $script:lang['Fail']
                $result.message = '{0} found' -f $prodName
                $result.data    = 'Version {0},#Port {1} not open to {2}' -f $prodVer, $valPort, $valName
            }
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = '{0} found' -f $prodName
            $result.data    = 'Version {0},#Agent not configured with port and/or servername' -f $prodVer
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Monitoring software not found, install required'
    }

    Return $result
}
