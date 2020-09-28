Function Remove-OlderDuplicates {
    [CmdletBinding()]

    Param (
        [Parameter(
            Mandatory = $True,
            HelpMessage = "Please enter the Path"
        )]
        [String] ${Path}
    )

    Begin {
        ${ComputerName} = (Get-WmiObject Win32_Computersystem).Name.toLower()
    }

    Process {
        Write-Verbose "[${ComputerName}][Goal] Remove duplicates on path '${Path}'"
        Try {
            Get-ChildItem -Path "${Path}" | Group-Object {[String]$($_.FullName -Replace '[\d]','')} | ForEach-Object {
                If ($_.Count -gt 1) { 
                    $_.Group | Sort-Object -Property {[int64]$($_.FullName -Replace '[^\d]','')} | Select-Object -First 1
                }
            } | Remove-Item | Out-Null
        } Catch {
            Throw "Something went wrong during the deletion of old duplicates"
        }
    }
}