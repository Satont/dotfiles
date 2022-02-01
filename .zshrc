source ~/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle heroku
antigen bundle pip
antigen bundle lein
antigen bundle command-not-found
antigen bundle deno
antigen bundle docker
#antigen bundle nvm
antigen bundle nvs
antigen bundle docker-compose
antigen bundle fzf
antigen bundle zsh-history-substring-search

# Syntax highlighting bundle.
antigen bundle zsh-users/zsh-syntax-highlighting

# Auto Suggestions
antigen bundle zsh-users/zsh-autosuggestions

# Load the theme.
#antigen theme spaceship-prompt/spaceship-prompt

SPACESHIP_DIR_TRUNC=0
SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_BATTERY_SHOW=false
# Tell Antigen that you're done.
antigen apply

#sudo service docker status || sudo service docker start

export DENO_INSTALL="/home/satont/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export FZF_BASE=/usr/bin/fzf

alias lwjerri="ssh -i ~/.ssh/lwjerri ubuntu@lwjerri.ml"
alias satont="ssh root@satont.ru"
alias shovely="ssh ubuntu@shovely.tk"
alias rusty="ssh ubuntu@rusty777.ml"
alias calitry="ssh ubuntu@calitry.tk"
alias marmok="ssh root@46.175.146.222"

alias s="du -h --max-depth=1"
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
eval "$(starship init zsh)"

export NVS_HOME="$HOME/.nvs"
[ -s "$NVS_HOME/nvs.sh" ] && . "$NVS_HOME/nvs.sh"
