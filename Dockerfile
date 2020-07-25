
# sdk:3.1 label has an issue with:
# Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Where the selection does not appear for Menu
# FROM mcr.microsoft.com/dotnet/core/sdk:3.1

ARG VARIANT="3.1-bionic"
FROM mcr.microsoft.com/dotnet/core/sdk:${VARIANT}

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# [Optional] Version of Node.js to install.
ARG INSTALL_NODE="true"
ARG NODE_VERSION="lts/*"
ENV NVM_DIR=/usr/local/share/nvm

# [Optional] Install the Azure CLI
ARG INSTALL_AZURE_CLI="false"

# Configure apt and install packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && apt-get -y install git openssh-client less iproute2 procps apt-transport-https gnupg2 curl lsb-release ca-certificates \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
    # [Optional] Install Node.js for ASP.NET Core Web Applicationss
    && if [ "$INSTALL_NODE" = "true" ]; then \
    #
    # Install nvm and Node
    mkdir -p ${NVM_DIR} \
    && curl -so- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash 2>&1 \
    && chown -R ${USER_UID}:${USER_GID} ${NVM_DIR} \
    && /bin/bash -c "source $NVM_DIR/nvm.sh \
    && nvm alias default ${NODE_VERSION}" 2>&1 \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"  && [ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"' \ 
    | tee -a /home/${USERNAME}/.bashrc /home/${USERNAME}/.zshrc >> /root/.zshrc \
    && echo "if [ \"\$(stat -c '%U' ${NVM_DIR})\" != \"${USERNAME}\" ]; then sudo chown -R ${USER_UID}:root ${NVM_DIR}; fi" \
    | tee -a /root/.bashrc /root/.zshrc /home/${USERNAME}/.bashrc >> /home/${USERNAME}/.zshrc \
    && chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.bashrc /home/${USERNAME}/.zshrc \
    && chown -R ${USER_UID}:root ${NVM_DIR} \
    #
    # Install yarn
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - 2>/dev/null \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends yarn; \
    fi \
    #
    # [Optional] Install the Azure CLI
    && if [ "$INSTALL_AZURE_CLI" = "true" ]; then \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - 2>/dev/null \
    && apt-get update \
    && apt-get install -y azure-cli; \
    fi 

RUN apt-get install -y tree \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN NPM_DIR="$( echo '/usr/local/share/nvm/versions/node/v1'*'/bin' )" \
    && PATH="$PATH:$NPM_DIR" \
    && echo PATH=$PATH \
    && npm install -g @angular/cli

SHELL ["pwsh", "-c"]
# Install Posh-Git
RUN Install-Module posh-git -Scope CurrentUser -AllowPrerelease -Force; \
    Import-Module posh-git; \
    Add-PoshGitToProfile -AllUsers -AllHosts; \
    $script = { \
    # Install DotNet Completion
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock { \
    param($commandName, $wordToComplete, $cursorPosition) \
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object { \
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) \
    } }; \
    #
    # Configure PSReadline
    Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete; \
    Set-PSReadlineOption -ShowToolTips; \
    Set-PSReadlineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord; \
    Set-PSReadlineKeyHandler -Key Ctrl+RightArrow -Function NextWord; \
    Set-PSReadlineKeyHandler -Key Shift+LeftArrow -Function SelectBackwardChar; \
    Set-PSReadlineKeyHandler -Key Shift+RightArrow -Function SelectForwardChar; \
    Set-PSReadlineKeyHandler -Key Ctrl+Shift+LeftArrow -Function SelectBackwardWord; \
    Set-PSReadlineKeyHandler -Key Ctrl+Shift+RightArrow -Function SelectNextWord ; \
    Set-PSReadlineKeyHandler -Key Ctrl+a -Function SelectAll; \
    Set-PSReadlineKeyHandler -Key Ctrl+Shift+Home -Function SelectBackwardsLine ; \
    Set-PSReadlineKeyHandler -Key Ctrl+Shift+End -Function SelectLine ; \
    }; \
    $script.ToString() >> $PROFILE.AllUsersAllHosts
SHELL ["/bin/sh", "-c"]

CMD ["pwsh"]
