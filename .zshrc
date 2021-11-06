source ~/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle heroku
antigen bundle pip
antigen bundle lein
antigen bundle command-not-found

antigen bundle nvm
NVM_AUTOLOAD=1
# Syntax highlighting bundle.
antigen bundle zsh-users/zsh-syntax-highlighting

# Auto Suggestions
antigen bundle zsh-users/zsh-autosuggestions

# Load the theme.
antigen theme spaceship-prompt/spaceship-prompt

SPACESHIP_DIR_TRUNC=0
SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_BATTERY_SHOW=false
# Tell Antigen that you're done.
antigen apply

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

#sudo service docker status || sudo service docker start

export DENO_INSTALL="/home/satont/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
