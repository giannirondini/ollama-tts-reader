# common.zsh — settings and helpers shared by speak-selection and summarize.
# Sourced, not executed: `source ${0:A:h}/lib/common.zsh`. The caller sets PATH
# (Alfred/Automator run with a bare environment).
#
# Sets URL, STATE, CONFIG. NOTIFY_TITLE (default "Speak with Phonon") is the
# notification title; set it before sourcing to change it.

URL=${PHONON_URL:-http://localhost:11434}
STATE=$HOME/Library/Caches/phonon-reader
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/phonon-reader
: ${NOTIFY_TITLE:=Speak with Phonon}

notify() {
  osascript -e "display notification \"${1//\"/\\\"}\" with title \"$NOTIFY_TITLE\"" 2>/dev/null
}

read_setting() { [[ -r $CONFIG/$1 ]] && print -r -- "$(<$CONFIG/$1)" }

ollama_up() { curl -sf --max-time 1 $URL/api/version >/dev/null 2>&1 }

# If Ollama is down, launch it and wait up to $PHONON_START_TIMEOUT seconds (default 10).
# Only for a local URL: a remote server can't be started from here.
ensure_ollama() {
  ollama_up && return 0
  [[ $URL == http://(localhost|127.0.0.1)(:*|) ]] || return 1
  notify "Ollama isn't running. Starting it…"
  if ! open -gj -a Ollama 2>/dev/null; then   # -g: no focus steal, -j: hidden (no chat window)
    # No Ollama.app: start the CLI server in a subshell so it isn't our child
    # (speak-stop kills the worker's children with pkill -P).
    (( $+commands[ollama] )) || return 1
    ( ollama serve >/dev/null 2>&1 &! )
  fi
  zmodload zsh/zselect
  local deadline=$(( SECONDS + ${PHONON_START_TIMEOUT:-10} ))
  while (( SECONDS < deadline )); do
    ollama_up && return 0
    zselect -t 25   # 0.25 s
  done
  return 1
}
