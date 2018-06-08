#!/bin/bash

# Utility script to be sourced by the other scripts or for interactive work

# prevent this file from being executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This file is intended to be sourced. Executing it is pointless." >> /dev/stderr
    exit 1
fi

###############################################################################
# Constants
###############################################################################

# name of the datacube conda environment
declare -r CUBEENV="cubeenv"

# Sets the location of the datacube home where everything resides. Change here,
# if another location is desired.
declare -r DCUBE_HOME="$HOME/datacube"

declare -r DATA_HOME="$DCUBE_HOME/data"
if [[ -n "$SCRIPTDIR" ]]; then
    declare -r PATCHDIR="$(readlink -f "${SCRIPTDIR}/../patches")"
    declare -r CONFDIR="$(readlink -f "${SCRIPTDIR}/../conf")"
fi

###############################################################################
# Helper Functions
###############################################################################

##
# Returns 0 if a conda environment is active, else returns 1.
function _isInVenv {
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        return 0
    else
        return 1
    fi
}

##
# Activates the datacube environment if it is not active yet.
function _activate {
    _isInVenv || {
        echo "Activating environment $CUBEENV";
        source activate "$CUBEENV";
    }
}

##
# Deactivates the datacube environment if it is still activated.
function _deactivate {
    _isInVenv && {
        echo "Deactivating environment $CUBEENV";
        source deactivate "$CUBEENV";
    }
}

##
# Wrapper for sed to use extended regular expressions.
function _exsed {
    sed --regexp-extended "$@"
}

##
# Escape a string for sed substitions. This function is expecting input from
# stdin.
function _sedescape {
    _exsed "s/(\\\\|&)/\\\\\1/g"
}

##
# Helper function for backups. Backs up only when we do not already have
# backup ending in ".datacube.bak".
# usage:
# _backup FILE
function _backup {
    if [[ ! -e "${1}.datacube.bak" ]]; then
        cp -v "$1" "${1}.datacube.bak"
    fi
}
