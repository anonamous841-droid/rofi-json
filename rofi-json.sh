# !/usr/bin/env sh

RESOURCE_NAME=$1
RESOURCE_FILE="$HOME/.config/sway/resources/$1.json"

JSON=$(jq -r '.' "$RESOURCE_FILE")

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

  options=$(echo ${MENU} | jq -r '.choices[].name')

  # Get the selected option
  result=$(printf "$options\nCancel" | rofi -p "$prompt" -dmenu)

  # Gets the data of said option (Returns the first coincidence if name is repeated) or null (If not found)
  data=$(echo ${MENU} | jq -r "[ .choices[] | select(.name==\"$result\") ] | .[0]")

  # If we didn't get any data (Be it wrong choice or exited rofi), just exit
  if [ "$data" = null ]; then
    exit 1
  fi

  # Since we have data, get the type of the selected option
  data_type=$(echo ${data} | jq -r '.type')

  if [ $data_type = 'item' ]; then # Since its an item, execute the command in it
    data_base_exec=$(echo ${data} | jq -r '.exec')
    data_exec=$(do_parse "$data_base_exec")

    eval $data_exec

    return 1 #Nowhere else to go, time to exit
  elif [ $data_type = 'subitem' ]; then # Since its a subitem, it just returns the result
    echo "$result"

    return 0
  else # Since its a submenu, get the choices for it
    data_has_generate=$(echo ${data} | jq 'has("generate")')

    # It has an intermediary menu, gotta do that first
    if [ $data_has_generate = true ]; then
      data_generate=$(echo ${data} | jq -r '.generate')
      data_prompt=$(echo ${data_generate} | jq -r '.prompt') # Get the prompt
      data_command=$(echo ${data_generate} | jq -r '.command') # Get the command from where we get the options

      data_menu=$(eval $data_command | jq -r "{ prompt: \"$data_prompt\", choices: [ { name: .[], type: \"subitem\" } ] }") # Parse the options as a menu (With proper format)
      data_result=$(do_menu "$data_menu") # Run the menu and get the chosen option

      if [ -z "$data_result" ]; then # If its empty, it means no proper option was selected (It exited with "1", see above for that check)
        exit 1
      fi

      add_param "$data_result" # Now we add the result for future parsing
    fi

    # Now we replace the old menu with the new one
    JSON=$data
  fi

  return 0
}

while :; do
  do_menu "$JSON"

  if ! [ $? -eq 0 ]; then
    break
  fi
done

