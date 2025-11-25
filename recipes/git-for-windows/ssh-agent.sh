# setting up a hacker profile

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

echo "[/etc/profile.d/ssh-agent.sh] Starting ssh-agent.."

SSH_ENV=$HOME/.ssh/environment

echo "..SSL keys a.s.o. can be found in '${SSH_ENV}'!"

# start the ssh-agent
function start_agent {
    #echo "Initializing new SSH agent..."
    # spawn ssh-agent
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > ${SSH_ENV}
    echo succeeded
    chmod 600 ${SSH_ENV}
    . ${SSH_ENV} > /dev/null
    /usr/bin/ssh-add
}

if [ -f "${SSH_ENV}" ]; then
     . ${SSH_ENV} > /dev/null
     ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi
