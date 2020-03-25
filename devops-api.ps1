#region Set Parameters
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$VerbosePreference = "Continue"
$env:PodePort ??= 8080
$env:ThreadCount ??= 10
#endregion

#region Uninstall/Install Required Modules
$requiredModules = @(
    @{Name = "pode"; Version = "1.6.1"},
    @{Name = "gitlab"; Version = "0.0.12"}
) 
$requiredModules | ForEach-Object {
    Write-Verbose -Message "Installing $($_.Name)"
    Uninstall-Module -Name $_.Name -Force -AllVersions -ErrorAction SilentlyContinue
    Install-Module -Name $_.Name -RequiredVersion $_.Version -Force
}
#endregion

Start-PodeServer -Threads $env:ThreadCount {
    #region Define Authentication types for Routes and OpenAPI
    New-PodeAuthType -Bearer -Scope "dev" | Add-PodeAuth -Name 'Dev-Auth' -ScriptBlock {
        param($token)
        # here you'd check a real storage, this is just for example
        if ($token -eq 'dev-token') {
            return @{
                User = @{
                    'Name' = 'Guest'
                    'Type' = 'Developer'
                }
                Scope = 'dev'
            }
        }
        return $null
    }
    New-PodeAuthType -Bearer -Scope "admin" | Add-PodeAuth -Name 'Admin-Auth' -ScriptBlock {
        param($token)
        # here you'd check a real storage, this is just for example
        if ($token -eq 'admin-token') {
            return @{
                User = @{
                    'Name' = 'Cansin'
                    'Type' = 'Admin'
                }
                Scope = 'admin'
            }
        }
        return $null
    }
    New-PodeAuthType -Basic | Add-PodeAuth -Name 'OpenAPI' -ScriptBlock {
        param($username, $password)
    
        # here you'd check a real user storage, this is just for example
        if ($username -eq 'evde' -and $password -eq 'kal') {
            return @{
                User = @{
                    Name = 'admin'
                    Type = 'openAPI'
                }
            }
        }
    
        # aww geez! no user was found
        return @{ Message = 'Invalid details supplied' }
    }
    Set-PodeOAGlobalAuth -Name 'OpenAPI' -Verbose
    #endregion
    #region Set Pode Endpoints
    
    Add-PodeEndpoint -Address * -Port $env:PodePort -Protocol Http
    Enable-PodeOpenApi -Path '/docs/openapi' -Title 'DevOps API' -Version 1.0.0 
    Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger' -DarkMode -Middleware (Get-PodeAuthMiddleware -Name "OpenAPI" -Sessionless)
    #endregion
    #region Enable Error Logging 
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    #endregion
   
    

    #region routes
    #region Gitlab
    ConvertTo-PodeRoute -Module Gitlab -Path "/api" -Verbose -Commands @("Get-GitlabGroups")
    ConvertTo-PodeRoute -Module Gitlab -Path "/api" -Verbose -Commands @("New-GitlabProject") -Middleware @(
        (Get-PodeAuthMiddleware -Name 'Dev-Auth' -Sessionless), 
        (Get-PodeAuthMiddleware -Name 'Admin-Auth' -Sessionless) 
    )
    ConvertTo-PodeRoute -Module Gitlab -Path "/api" -Verbose -Commands @("New-GitlabGroup") -Middleware (
        Get-PodeAuthMiddleware -Name 'Admin-Auth' -Sessionless
    )
    #endregion
    
    #endregion
    
}
