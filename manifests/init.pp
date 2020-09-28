# @summary Deploy highpoint classes to PS_CFG_HOME/class folder
#
# @param ensure
#   Standard puppet ensure
#
# @param packages
#   An array of zip files containing class files that need to be deployed
#
# @param ps_config_home
#   Location of ps_cfg_home where class files will be copied
#
# @example
#   include highpoint
class highpoint (
  Enum['present','absent']    $ensure         = 'absent',
  Optional[Array[String[1]]]  $packages       = undef,
  String[1]                   $ps_config_home = lookup('ps_config_home'),
) {
  if ($facts['operatingsystem'] == 'windows') {

    if (!empty($packages) and ($ensure == 'present')) {

      $packages.each | Integer $index, String $package | {

        $pkgtemp = regsubst("${::env_temp}/${index}", '(/|\\\\)', '\\', 'G')

        exec { "Check ${package}" :
          command   => Sensitive(@("EOT")),
              Test-Path -Path ${regsubst("\'${package}\'", '(/|\\\\)', '\\', 'G')} -ErrorAction Stop
            |-EOT
          provider  => powershell,
          logoutput => true,
        }

        exec { "Expand ${package} to ${pkgtemp}" :
          command   => Sensitive(@("EOT")),
              Try {
                Expand-Archive `
                  -Path ${regsubst("\'${package}\'", '(/|\\\\)', '\\', 'G')} `
                  -DestinationPath ${regsubst("\'${pkgtemp}\'", '(/|\\\\)', '\\', 'G')} `
                  -Force `
                  -ErrorAction Stop
              } Catch {
                Exit 1
              }
            |-EOT
          provider  => powershell,
          logoutput => true,
          require   => [ Exec["Check ${package}"] ],
        }

        exec { "Deploy ${pkgtemp}/*/java/app/*" :
          command   => Sensitive(@("EOT")),
              Try {
                If (
                  $(
                    Try {
                      Test-Path `
                        -Path ${regsubst("\'${ps_config_home}/class\'", '(/|\\\\)', '\\', 'G')} `
                        -Type Leaf `
                        -ErrorAction Stop
                    } Catch { 0 }
                  ) 
                ) {
                  Remove-Item -Path ${regsubst("\'${ps_config_home}/class\'", '(/|\\\\)', '\\', 'G')} | Out-Null
                }

                If ( -not
                  $(
                    Try {
                      Test-Path `
                        -Path ${regsubst("\'${ps_config_home}/class\'", '(/|\\\\)', '\\', 'G')} `
                        -Type Container `
                        -ErrorAction Stop
                    } Catch { 0 }
                  ) 
                ) {
                  New-Item -Path ${regsubst("\'${ps_config_home}/class\'", '(/|\\\\)', '\\', 'G')} -Type Directory | Out-Null
                }
                Copy-Item `
                  -Path ${regsubst("\'${pkgtemp}/*/java/app/*\'", '(/|\\\\)', '\\', 'G')} `
                  -Destination ${regsubst("\'${ps_config_home}/class/\'", '(/|\\\\)', '\\', 'G')} `
                  -Force `
                  -ErrorAction Stop
              } Catch {
                Exit 1
              }
            |-EOT
          provider  => powershell,
          logoutput => true,
          require   => [ Exec["Expand ${package} to ${pkgtemp}"] ],
        }

        exec { "Delete Duplicate '${package}' classes" :
          command   => "
              ${file('highpoint/highpoint.psm1')}
              Remove-OlderDuplicates -Path ${regsubst("\'${ps_config_home}/class/\'", '(/|\\\\)', '\\', 'G')}
            ",
          provider  => powershell,
          logoutput => true,
          require   => [ Exec["Deploy ${pkgtemp}/*/java/app/*"] ],
        }

        exec { "Delete ${pkgtemp} Directory" :
          command   =>  Sensitive(@("EOT")),
              New-Item -Path ${regsubst("\'${::env_temp}/empty\'", '(/|\\\\)', '\\', 'G')} -Type Directory -Force

              Start-Process `
                -FilePath "C:\\windows\\system32\\Robocopy.exe" `
                -ArgumentList @( `
                  ${regsubst("\'${::env_temp}/empty\'", '(/|\\\\)', '\\', 'G')}, `
                  ${regsubst("\'${pkgtemp}\'" ,'/', '\\\\', 'G')}, `
                  "/E /PURGE /NOCOPY /MOVE /NFL /NDL /NJH /NJS > nul" `
                ) `
                -Wait `
                -NoNewWindow | Out-Null

              Get-Item -Path ${regsubst("\'${pkgtemp}\'" ,'/', '\\\\', 'G')} -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
            |-EOT
          provider  => powershell,
          logoutput => true,
          require   => [ Exec["Deploy ${pkgtemp}/*/java/app/*"] ],
        }

      }
    }
  }

}
