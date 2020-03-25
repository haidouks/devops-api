FROM mcr.microsoft.com/powershell:7.0.0-alpine-3.10
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./devops-api.ps1 /usr/local/share/powershell/Modules/Pode 
ENTRYPOINT ["pwsh", "/usr/local/share/powershell/Modules/Pode/devops-api.ps1"]