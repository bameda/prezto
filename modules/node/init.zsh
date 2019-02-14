#
# Configures Node local installation, loads version managers, and defines
# variables and aliases.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#   Zeh Rizzatti <zehrizzatti@gmail.com>
#   Indrajit Raychaudhuri <irc@indrajit.com>
#

# Possible lookup locations for manually installed nodenv and nvm.
local_nodenv_paths=({$NODENV_ROOT,{$XDG_CONFIG_HOME/,$HOME/.}nodenv}/bin/nodenv(N))
local_nvm_paths=({$NVM_DIR,{$XDG_CONFIG_HOME/,$HOME/.}nvm}/nvm.sh(N))

# Load manually installed or package manager installed nodenv into the shell
# session.
if (( $#local_nodenv_paths || $+commands[nodenv] )); then

  # Ensure manually installed nodenv is added to path when present.
  [[ -s $local_nodenv_paths[1] ]] && path=($local_nodenv_paths[1]:h $path)

  eval "$(nodenv init - zsh)"

# Load manually installed nvm into the shell session.
elif (( $#local_nvm_paths )); then
  source "$local_nvm_paths[1]" --no-use

# Load package manager installed nvm into the shell session.
elif (( $+commands[brew] )) \
      && [[ -d "${nvm_path::="$(brew --prefix 2> /dev/null)"/opt/nvm}" ]]; then
  source "$nvm_path/nvm.sh" --no-use
fi

unset local_n{odenv,vm}_paths nvm_path

# Return if requirements are not found.
if (( ! $+commands[node] && ! $#functions[(i)n(odenv|vm)] )); then
  return 1
fi

# Load NPM and known helper completions.
typeset -A compl_commands=(
  npm   'npm completion'
  grunt 'grunt --completion=zsh'
  gulp  'gulp --completion=zsh'
)

for compl_command in "${(k)compl_commands[@]}"; do
  if (( $+commands[$compl_command] )); then
    cache_file="${TMPDIR:-/tmp}/prezto-$compl_command-cache.$UID.zsh"

    # Completion commands are slow; cache their output if old or missing.
    if [[ "$commands[$compl_command]" -nt "$cache_file" \
          || "${ZDOTDIR:-$HOME}/.zpreztorc" -nt "$cache_file" \
          || ! -s "$cache_file" ]]; then
      command ${=compl_commands[$compl_command]} >! "$cache_file" 2> /dev/null
    fi

    source "$cache_file"

    unset cache_file
  fi
done

unset compl_command{s,}

# START: FROM https://github.com/sorin-ionescu/prezto/pull/1339
# Auto node version switch cwd hook
function _node-nvm-switch-cwd {
  # Check if this is a Git repo
  local GIT_REPO_ROOT=""
  local GIT_TOPLEVEL="$(git rev-parse --show-toplevel 2> /dev/null)"
  if [[ $? == 0 ]]; then
    GIT_REPO_ROOT="$GIT_TOPLEVEL"
  fi
  # Get absolute path, resolving symlinks
  local PROJECT_ROOT="${PWD:A}"
  while [[ "$PROJECT_ROOT" != "/" && ! -e "$PROJECT_ROOT/.nvmrc" \
            && ! -d "$PROJECT_ROOT/.git"  && "$PROJECT_ROOT" != "$GIT_REPO_ROOT" ]]; do
    PROJECT_ROOT="${PROJECT_ROOT:h}"
  done
  if [[ "$PROJECT_ROOT" == "/" ]]; then
    PROJECT_ROOT="."
  fi
  # Check for nvmrc
  # We cache the location of the nvmrc file instead of the version itself because nvm's version lookup is slow
  local ENV_VER=""
  if [[ -f "$PROJECT_ROOT/.nvmrc" ]]; then
    ENV_VER="$PROJECT_ROOT/.nvmrc"
  fi
  if [[ -n $CD_NODE_USE && "$ENV_VER" != "$CD_NODE_USE" ]]; then
    # We've just left the repo, return to the default node version
    # Note: this only happens if the node version was selected automatically
    nvm use default && unset CD_NODE_USE
  fi
  if [[ "$ENV_VER" != "" ]]; then
    # Activate the node version only if it is not already active
    if [[ "$CD_NODE_USE" != "$ENV_VER" ]]; then
      nvm use $(cat $ENV_VER) && export CD_NODE_USE="$ENV_VER"
    fi
  fi
}
# END: FROM https://github.com/sorin-ionescu/prezto/pull/1339


# Load auto workon cwd hook
if zstyle -t ':prezto:module:node:nvm' auto-switch 'yes'; then
  # Auto workon when changing directory
  add-zsh-hook chpwd _node-nvm-switch-cwd
fi
