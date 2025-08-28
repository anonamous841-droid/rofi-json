# !/usr/bin/env sh

set -e

ROFI_JSON_LOCATION="${ROFI_JSON_LOCATION:-"$HOME/.config/rofi/resources"}"
ROFI_ICON_LOCATION="${ROFI_ICON_LOCATION:-"$HOME/.config/rofi/icons"}"

ICON_TOKEN="\x00icon\x1f"

BASE_ROFI_OPTIONS="-dmenu"

load_json() {
  JSON_NAME="$1.json"
  JSON_FILE="$ROFI_JSON_LOCATION/$JSON_NAME"

  # If file doesn't exist, throw error
  if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: Resource file '$JSON_NAME' not found" >&2
    exit 1
  fi

  echo $(jq -r '.' "$JSON_FILE")
}

JSON="$(load_json "$1")"

PARAM_COUNTER=0
declare -A PARAM_LIST


add_param() {
  NEW_PARAM=$1

  PARAM_COUNTER=$(( $PARAM_COUNTER + 1 )) # Move param counter ("seq" in do_parse requires number 1 or higher)
  PARAM_LIST[$PARAM_COUNTER]=$NEW_PARAM # Add param to list
}


do_parse() {
  STRING=$1

  # Replace "$1" with "PARAM_LIST[1]" and so on
  for i in $(seq $PARAM_COUNTER); do
    OLD_VALUE="\$$i"
    NEW_VALUE=${PARAM_LIST[$i]}

    STRING=$(echo "$STRING" | sed "s/$OLD_VALUE/$NEW_VALUE/")
  done

  echo "$STRING"
}


do_menu() {
  # Menu is the JSON passed to the function
  MENU=$1

  # Get menu prompt and the options for it
  base_prompt=$(echo ${MENU} | jq -r '.prompt')
  prompt=$(do_parse "$base_prompt")

  theme=$(echo ${MENU} | jq -r '.theme')
  ROFI_OPTIONS=${BASE_ROFI_OPTIONS}
  if [ "$theme" != "null" ]; then
      ROFI_OPTIONS+=" -theme ${theme}"
  fi

  options=""
  option_list=$(echo ${MENU} | jq -cr '.choices[] | "\(.name)|\(.icon)"')

  while IFS="|" read -r optName optIcon
  do
      if [ "$optName" == "null" ]; then
          continue
      fi
      options+=$optName
      if [ "$optIcon" != "null" ]; then
          options+="${ICON_TOKEN}${ROFI_ICON_LOCATION}/$optIcon"
      fi
      options+="\n"
  done <<< $option_list

  # Get the selected option
  result=$(printf "$options\nCancel" | rofi -p "$prompt" $ROFI_OPTIONS )
  result=${result%%$ICON_TOKEN}

  # Gets the data of said option (Returns the first coincidence if name is repeated) or null (If not found)
  data=$(echo ${MENU} | jq -r "[ .choices[] | select(.name | startswith(\"$result\")) ] | .[0]")

  # If we didn't get any data (Be it wrong choice or exited rofi), just exit
  if [ "$data" == "null" ]; then
    exit 1
  fi

  # Since we have data, get the type of the selected option
  data_type=$(echo ${data} | jq -r '.type')
  data_icon=$(echo ${data} | jq -r '.exec')

  if [ "$data_type" == "item" ]; then # Since its an item, execute the command in it
    data_base_exec=$(echo ${data} | jq -r '.exec')
    data_exec=$(do_parse "$data_base_exec")

    eval $data_exec

    return 1 #Nowhere else to go, time to exit
  elif [ "$data_type" == "nop" ]; then # NOP, redisplay menu
    return $(do_menu "$JSON")
  elif [ "$data_type" == "subitem" ]; then # Since its a subitem, it just returns the result
    echo "$result"

    return 0
  else # Since its a submenu, get the choices for it
    data_has_generate=$(echo ${data} | jq 'has("generate")')

    # It has an intermediary menu, gotta do that first
    if [ "$data_has_generate" == "true" ]; then
      data_generate=$(echo ${data} | jq -r '.generate')
      data_prompt=$(echo ${data_generate} | jq -r '.prompt') # Get the prompt
      data_command=$(echo ${data_generate} | jq -r '.command') # Get the command from where we get the options

      data_base_gen_exec=$(echo ${data_generate} | jq -r '.exec')  # Optional: exec for generated menu vs. submenu
      data_base_gen_theme=$(echo ${data_generate} | jq -r '.theme')  # Optional: exec for generated menu vs. submenu
      data_gen_theme=$theme
      if [ "$data_base_gen_theme" != "null" ]; then
        data_gen_theme=$data_base_gen_theme
      fi

      data_menu=$(eval $data_command | jq -r "{ prompt: \"$data_prompt\", theme: \"$data_gen_theme\", choices: [ { name: .[], type: \"subitem\" } ] }")
      # Parse the options as a menu (With proper format)
      
      data_result=$(do_menu "$data_menu") # Run the menu and get the chosen option
      
      if [ -z "$data_result" ]; then # If its empty, it means no proper option was selected (It exited with "1", see above for that check)
          exit 1
      fi

      add_param "$data_result" # Now we add the result for future parsing

      if [ "$data_base_gen_exec" != "null" ]; then
          data_gen_exec=$(do_parse "$data_base_gen_exec")
          eval $data_gen_exec
          return 1 #Nowhere else to go, time to exit
      fi
    fi

    # Load the external json menu if it points to one, otherwise replace with obtained data
    data_has_redirect=$(echo ${data} | jq 'has("redirect")')

    if [ "$data_has_redirect" = "true" ]; then
      data_redirect=$(echo ${data} | jq -r '.redirect')
      JSON=$(load_json "$data_redirect")
    else
      JSON=$data
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
