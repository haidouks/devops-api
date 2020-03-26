# DevOps API
DevOps API is a web server which hosts exported functions in powershell modules as Rest APIs using [Pode framework](https://badgerati.github.io/Pode/). 
This project is a demonstration for automatically converting Powershell Modules to rest services and making DevOps scripts simply available for everyone.

### How to start ?

 - Easiest way to start DevOps API is docker run. This will pull an alpine image run DevOps API on top of Powershell 7.

```sh
docker run -it --rm -p 8080:8080 -e GitlabApi="http://gitlab/api/v4/" -e GitlabToken="tmZemx_kdmcyBaeWMxXa" -d cnsn/devops-api:latest
```
- If you don't want to work with containers, you can just use powershell to start it. Before running server, you should set 2 environment variables. These variables are not required by DevOps API but gitlab module needs them to work properly.
```sh
$env:GitlabApi = "http://gitlab/api/v4/"
$env:GitlabToken = "tmZemx_kdmcyBaeWMxXa"
./devops-api.ps1
```

### Configurations
- Preference variables are related to powershell itself. They sets the behaviour of code for given situations.
- PodePort sets the listening port of DevOps API. If there is no PodePort environment variable defined, default port is 8080.
- ThreadCount is the number of max runspaces which will be reserved for DevOps API requests. Default is 10 if environment variable is not set. 
```sh
#region Set Parameters
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$VerbosePreference = "Continue"
$env:PodePort ??= 8080
$env:ThreadCount ??= 10
#endregion
```
### Modules
There are two steps for converting modules to rest services. First one is installing desired modules to server. Region below will install Pode:1.6.1 and gitlab:0.0.12 modules to server. If you want to work with the latest versions, changing '-RequiredVersion' to '-MinimumVersion' will be enough. 

```sh
#region Uninstall/Install Required Modules
$requiredModules = @(
    @{Name = "pode"; Version = "1.6.1"},
    @{Name = "gitlab"; Version = "0.0.12"}
) 
$requiredModules | ForEach-Object {
    Write-Verbose -Message "Installing $($_.Name)"
    Uninstall-Module -Name $_.Name -Force -AllVersions -ErrorAction SilentlyContinue
    Install-Module -Name $_.Name -RequiredVersion $_.Version -Force
}
#endregion
```
### Authentication
In the example below, there are 3 types of authentications:
- Bearer authentications are used by different endpoints which need admin or developer level access. 
- Basic authentication is for OpenAPI which will allow users to try out functions via swagger.

```sh
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
    return @{ Message = 'Invalid details supplied' }
}
```
### Routes
Last step is defining routes. Like Python Flask, routes assign URLs in our app to functions easily.Pode is a very capable framework and one of them is automatically creating routes for functions. 
Depending the verb part of function, Pode sets the method type. And if the method type is GET (Get-\*, ...), created route accepts function parameters as query string or if it is a POST or PUT method (New-\* , Set-\*, Update-\*, ...) routes gets parameters from the body automatically. 

You can find detailed information about routes in the [pode documentation](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/FunctionsAndModules/).

```sh
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
```

In the example above, I defined different authentication types for each function but actually if you don't care authentication or different authentication types, you can just publish all of your module functions in one line as below:
```sh
ConvertTo-PodeRoute -Module Gitlab -Path "/api"
```

### Swagger
Exported module functions can be executed or explored via Swagger. To enable it, you can use the code below:
```sh
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'DevOps API' -Version 1.0.0 
Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger' -DarkMode -Middleware (Get-PodeAuthMiddleware -Name "OpenAPI" -Sessionless)
```
If you don't care an extra authentication for your Swagger, you don't need to put middleware switch.
![image](https://user-images.githubusercontent.com/23384662/77652232-fc704500-6f7e-11ea-8ec1-1489d02679b0.png)

