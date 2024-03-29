#!/bin/bash
#title:         platform.sh
#description:   launch PopChef platform
#author:        Mathieu Vie
#created:       june 16 2022
#updated:       N/A
#version:       1.0
#usage:         ./platform.sh

#Variables
ERROR=" "
DEFAULT_REPOSITORY_PATH=~/Documents/popchef
ITERMOCIL_PATH_FILE=~/Tools/launch-platform/itermocil
FRONT_B2B_FRONT_PUBLIC_PORT='3000'
FRONT_B2B_FRONT_ADMIN_PORT=3001
FRONT_B2B_FRONT_MANAGERS_PORT=3002
FRONT_B2B_FRONT_CANTEEN_WEB_APP_PORT=3003

#Menu options
declare -a options=('b2b-api-data' 'b2b-api-auth' 'b2b-api-public' 'b2b-api-internal' 'b2b-api-external' 'b2b-front-public'  'b2b-front-admin' 'b2b-front-managers' 'b2b-front-canteen-web-app')

#Pre-check PROJECTs
declare -a choices=( "${options[@]//*/+}" )

#===  FUNCTION  ========================================================================
# NAME:  CHECK_REQUIRED_DEPENDENCIES
# DESCRIPTION:  Check require dependencies like itermocil & yq
# PARAMETER  0:
#=======================================================================================
function CHECK_REQUIRED_DEPENDENCIES() {
    if ! command -v itermocil &> /dev/null
    then
        echo "itermocil could not be found"
        exit
    fi

    if ! command -v yq &> /dev/null
    then
        echo "yq could not be found"
        exit
    fi
}

#===  FUNCTION  ========================================================================
# NAME:  PROJECTS_NAME
# DESCRIPTION:  List of selected PROJECTs to be launched
#=======================================================================================
function PROJECTS_NAME() {

    for ((i = 0; i < ${#options[*]}; i++)); do
        if [[ "${choices[i]}" == "+" ]]; then
            install+=(${options[i]}) #| tr '[:upper:]' '[:lower:]'
        fi
    done
    echo "${install[@]}"
}

#===  FUNCTION  ========================================================================
# NAME: MENU SELECTION PROJECT LIST
# DESCRIPTION:  Ask for user input to toggle the name of the service to be restored
#=======================================================================================
function PROJECT_LIST() {
    echo "Which projects do you want to start?"

    for NUM in "${!options[@]}"; do
        echo "[""${choices[NUM]:- }""]" $((NUM + 1))") ${options[NUM]}"
    done
    echo "$ERROR"
}

#Clear screen for menu
clear

#===  FUNCTION  ========================================================================
# NAME: ASK_PROJECT_USER_WANT_START
# DESCRIPTION:
#=======================================================================================
function ASK_PROJECT_USER_WANT_START() {
    while PROJECT_LIST && read -e -p "Input project number to check/uncheck (ENTER when done): " -n1 SELECTION && [[ -n "$SELECTION" ]]; do
        clear
        if [[ "$SELECTION" == *[[:digit:]]* && $SELECTION -ge 1 && $SELECTION -le ${#options[@]} ]]; then
            (( SELECTION-- ))
            if [[ "${choices[SELECTION]}" == "+" ]]; then
                choices[SELECTION]=""
            else
                choices[SELECTION]="+"
            fi
                ERROR=" "
        else
            ERROR="Invalid option: $SELECTION"
        fi
    done
}

#===  FUNCTION  ========================================================================
# NAME: UPDATE_PROJECT
# DESCRIPTION:
#=======================================================================================
function UPDATE_PROJECT() {
    for PROJECT in ${PROJECT_LIST}; do
        cd $DEFAULT_REPOSITORY_PATH/$PROJECT
        updated=$(git pull)

        echo "${PROJECT} -> $updated"
        if test "${updated}" != "Already up to date."
            then
            npm install --silent
        fi

    done


}

#===  FUNCTION  ========================================================================
# NAME: LAUNCH_PROJECT
# DESCRIPTION: Launch each PROJECT with associated commands
#=======================================================================================
function LAUNCH_PROJECT() {



    yq 'del(.windows[].panes[])' -i ${ITERMOCIL_PATH_FILE}.yml
    for PROJECT in ${PROJECT_LIST}; do
        case $PROJECT in
            b2b-front-public|b2b-front-admin|b2b-front-managers|b2b-front-canteen-web-app)
                PORT=$(echo "FRONT_${PROJECT}_PORT" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
                echo "${PROJECT} listen on $((${PORT}))"
                commandToExec="cd ${DEFAULT_REPOSITORY_PATH}/${PROJECT}/src/semantic; npx gulp build-css build-assets; cd ../..; PORT=$((${PORT})) npm run start;" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml; ;;
            b2b-api-data|b2b-api-internal|b2b-api-public)
                commandToExec="cd ${DEFAULT_REPOSITORY_PATH}/${PROJECT}; npm run watch:logstderr;" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml; ;;
            b2b-api-external)
                commandToExec="cd ${DEFAULT_REPOSITORY_PATH}/${PROJECT}; npm run watch;" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml; ;;
            b2b-api-auth)
                commandToExec="cd ${DEFAULT_REPOSITORY_PATH}/${PROJECT}; npm run start:ts;" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml; ;;
            *) echo "Nothing for ${PROJECT}"; ;;
        esac;
    done

    if [[ "$(docker images -q html2pdf:latest 2> /dev/null)" == "" ]]; then
      echo "No image for 'html2pdf' found - build in progress"
      commandToExec="cd ${DEFAULT_REPOSITORY_PATH}/${PROJECT}; npm run start:dev;" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml;
    else
      commandToExec="docker run -p 4040:4040 html2pdf" yq e '.windows.[].panes += [env(commandToExec)]' -i ${ITERMOCIL_PATH_FILE}.yml;

    fi

    # Launch itermocil
    itermocil ${ITERMOCIL_PATH_FILE}

}

#cd ~/Tools/launch-platform; docker-compose up -d
CHECK_REQUIRED_DEPENDENCIES
ASK_PROJECT_USER_WANT_START
PROJECT_LIST=$(echo "$(PROJECTS_NAME)" | tr '[:upper:]' '[:lower:]') # To lowercase
#UPDATE_PROJECT
LAUNCH_PROJECT

