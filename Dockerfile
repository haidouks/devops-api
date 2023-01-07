FROM mcr.microsoft.com/powershell:lts-alpine-3.14
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./devops-api.ps1 /usr/local/share/powershell/Modules/Pode 
ENTRYPOINT ["pwsh", "/usr/local/share/powershell/Modules/Pode/devops-api.ps1"]
