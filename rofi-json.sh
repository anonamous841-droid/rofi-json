#!/bin/bash

set -e

ROFI_JSON_LOCATION="${ROFI_JSON_LOCATION:-"$HOME/.config/rofi/resources"}"
ROFI_ICON_LOCATION="${ROFI_ICON_LOCATION:-"$HOME/.config/rofi/icons"}"

ICON_TOKEN="\x00icon\x1f"

BASE_ROFI_OPTIONS=(-dmenu)

load_json() {
  JSON_NAME="$1.json"
  JSON_FILE="$ROFI_JSON_LOCATION/$JSON_NAME"

  # If file doesn't exist, throw error
  if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: Resource file '$JSON_NAME' not found" >&2
    exit 1
  fi

  jq -r '.' "$JSON_FILE"
}

JSON="$(load_json "$1")"

PARAM_COUNTER=0
declare -A PARAM_LIST
THEME=""

add_param() {
  NEW_PARAM=$1

  PARAM_COUNTER=$( ${PARAM_COUNTER} + 1 ) # Move param counter ("seq" in do_parse requires number 1 or higher)
  PARAM_LIST[$PARAM_COUNTER]=${NEW_PARAM} # Add param to list
}


do_parse() {
  STRING=$1

  # Replace "$1" with "PARAM_LIST[1]" and so on
  for i in $(seq $PARAM_COUNTER); do
    OLD_VALUE="\$$i"
    NEW_VALUE=${PARAM_LIST[$i]}

    STRING=$(echo "$STRING" | sed "s/$OLD_VALUE/$NEW_VALUE/g")
  done

  echo "$STRING"
}

do_menu() {
  # Menu is the JSON passed to the function
  MENU=$1

  # Get menu prompt and the options for it
  BASE_PROMPT=$(echo "${MENU}" | jq -r '.prompt')
  PROMPT=$(do_parse "$BASE_PROMPT")

  BASE_THEME=$(echo "${MENU}"| jq -r '.theme')
  if [ "${BASE_THEME}" != "null" ]; then
    THEME="${BASE_THEME}"
  fi
  
  ROFI_OPTIONS=("${BASE_ROFI_OPTIONS[@]}")

  if [ -n "${PROMPT:-}" ] ; then
    ROFI_OPTIONS+=(-p "${PROMPT}")
  fi
  
  if [ -n "${THEME}" ]; then
    ROFI_OPTIONS+=(-theme-str "@import \"${THEME}\"")
  fi

  OPTIONS=""
  OPTION_LIST=$(echo "${MENU}"| jq -cr '.choices[] | "\(.name)|\(.icon)"')

  while IFS="|" read -r OPTNAME OPTICON
  do
      if [ "${OPTNAME}" == "null" ]; then
          continue
      fi
      OPTIONS+=${OPTNAME}
      if [ "${OPTICON}" != "null" ]; then
          OPTIONS+="${ICON_TOKEN}${ROFI_ICON_LOCATION}/$OPTICON"
      fi
      OPTIONS+="\n"
  done <<< "${OPTION_LIST}"

  # Get the selected option  
  RESULT=$(printf "$OPTIONS\nCancel" | rofi "${ROFI_OPTIONS[@]}" )
  RESULT=${RESULT%%"$ICON_TOKEN"}

  # Gets the data of said option (Returns the first coincidence if name is repeated) or null (If not found)
  DATA=$(echo "${MENU}" | jq -r "[ .choices[] | select(.name | startswith(\"$RESULT\")) ] | .[0]")

  # If we didn't get any data (Be it wrong choice or exited rofi), just exit
  if [ "${DATA}" == "null" ]; then
    exit 1
  fi

  # Since we have data, get the type of the selected option
  DATA_TYPE=$(echo "${DATA}" | jq -r '.type')

  if [ "${DATA_TYPE}" == "item" ]; then # Since its an item, execute the command in it
    DATA_BASE_EXEC=$(echo "${DATA}" | jq -r '.exec')
    DATA_EXEC=$(do_parse "${DATA_BASE_EXEC}")

    eval "${DATA_EXEC}"

    return 1 #Nowhere else to go, time to exit
    
  elif [ "${DATA_TYPE}" == "nop" ]; then # NOP, redisplay menu
    return "$(do_menu "${JSON}")"
      
  elif [ "${DATA_TYPE}" == "subitem" ]; then # Since its a subitem, it just returns the result
    echo "${RESULT}"

    return 0
    
  else # Since its a submenu, get the choices for it
    DATA_HAS_GENERATE=$(echo "${DATA}" | jq 'has("generate")')

    # It has an intermediary menu, gotta do that first
    if [ "${DATA_HAS_GENERATE}" == "true" ]; then
      DATA_GENERATE=$(echo "${DATA}" | jq -r '.generate')
      DATA_PROMPT=$(echo "${DATA_GENERATE}" | jq -r '.prompt') # Get the prompt
      DATA_COMMAND=$(echo "${DATA_GENERATE}" | jq -r '.command') # Get the command from where we get the options

      DATA_BASE_GEN_EXEC=$(echo "${DATA_GENERATE}" | jq -r '.exec')  # Optional: exec for generated menu vs. submenu
      DATA_BASE_GEN_THEME=$(echo "${DATA_GENERATE}" | jq -r '.theme')  # Optional: exec for generated menu vs. submenu
      DATA_GEN_THEME=${THEME}
      if [ "${DATA_BASE_GEN_THEME}" != "null" ]; then
        DATA_GEN_THEME=${DATA_BASE_GEN_THEME}
      fi

      DATA_MENU=$(eval "${DATA_COMMAND}" | jq -r "{ prompt: \"${DATA_PROMPT}\", theme: \"${DATA_GEN_THEME}\", choices: [ { name: .[], type: \"subitem\" } ] }")
      # Parse the options as a menu (With proper format)
      
      DATA_RESULT=$(do_menu "${DATA_MENU}") # Run the menu and get the chosen option
      
      if [ -z "${DATA_RESULT}" ]; then # If its empty, it means no proper option was selected (It exited with "1", see above for that check)
          exit 1
      fi

      add_param "${DATA_RESULT}" # Now we add the result for future parsing

      if [ "${DATA_BASE_GEN_EXEC}" != "null" ]; then
          DATA_GEN_EXEC=$(do_parse "$DATA_BASE_GEN_EXEC")
          eval "${DATA_GEN_EXEC}"
          return 1 #Nowhere else to go, time to exit
      fi
    fi

    # Load the external json menu if it points to one, otherwise replace with obtained data
    DATA_HAS_REDIRECT=$(echo "${DATA}" | jq 'has("redirect")')

    if [ "${DATA_HAS_REDIRECT}" = "true" ]; then
      DATA_REDIRECT=$(echo "${DATA}" | jq -r '.redirect')
      JSON=$(load_json "${DATA_REDIRECT}")
    else
      JSON=$DATA
    fi
  fi

  return 0
}

while :; do
  do_menu "$JSON"

  if ! [ $? -eq 0 ]; then
    break
  fi
done
