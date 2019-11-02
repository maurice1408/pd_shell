#######################################################################
function parse_yaml {
    local prefix=$2
    # regex patterns to be used in sed
    # \034 0x1c is the INFORMATION SEPARATOR FOUR unicode character
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

    # split the yaml file input records int $fs delimited words 
    # removing the : character and pipe into the awk
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
       indent = length($1)/2;
       vname[indent] = $2;
       for (i in vname) {if (i > indent) {delete vname[i]}}
       if (length($3) > 0) {
           vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
           printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
       }
    }'
}

#######################################################################
function log_date() {
    printf "%s %s -" $(date "+%Y-%m-%d %H:%M:%S")
}

#######################################################################
function log() {
  printf "%s %s\n" "$(log_date)" "$@" | tee -a ${log_file}
}

#######################################################################
function logq() {
  echo "$(log_date) $@" >> ${log_file}
}

#######################################################################
assert ()                 #  If condition false,
{                         #+ exit from script
                          #+ with appropriate error message.
  E_PARAM_ERR=98
  E_ASSERT_FAILED=99


  if [ -z "$2" ]          #  Not enough parameters passed
  then                    #+ to assert() function.
    return $E_PARAM_ERR   #  No damage done.
  fi

  lineno=$2

  if [ ! $1 ] 
  then
    echo "Assertion failed:  \"$1\""
    echo "File \"$0\", line $lineno"    # Give name of file and line number.
    exit $E_ASSERT_FAILED
  # else
  #   return
  #   and continue executing the script.
  fi  
}
#######################################################################
function json_parse_list() {

   # Expected args
   # 1 - regexp to use to parse list entries out
   # 2 - json to parse

   # Returns the source via declare -p of an array containing the list of items matching regexp
   # To create an array from the returned value wrap the call to this function in an eval $()

   # Podiun REST API responses have the form
   # {"subList":[{},{},...],"fullListSize":\d+,...}
   #
   # Typically the {} entires will be {id:\d+,....}
   #
   # A nongreedy perl regex like  {"id":\d+.*?} is used by grep to extract the subList 
   # entries which are then single-quoted by a gawk script that creates the array
   # json_list.
   # The output from the gawk is json_list=('...','...','...', ...) which is evaluated to
   # create the array.
   #
   # Since it is not possible to pass back an array, a declare -p of the array is passed
   # back so the call to the function must be wrapped in an eval
   #

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 2 ]]
   then
     echo "${_funcname}: expected 2 arguments, rexexp and json" >&2
     exit 1
   fi

   declare -a json_list
   local list_regexp="$1"
   local json="$2"

   if [[ "jq" == "native" ]]
   then   

      # echo "${list_regexp}"
      # echo "${json}"

      # eval $(echo $json | grep --only-matching --perl-regexp $list_regexp | gawk -v q="'" 'BEGIN {printf "json_list=("}; {printf "%s%s%s ", q, $0, q}; END {print ")"}')

      # declare -p json_list

      echo $json | grep --only-matching --perl-regexp $list_regexp | gawk -v q="'" 'BEGIN {printf "json_list=("}; {gsub(/\047/,""); printf "%s%s%s ", q, $0, q}; END {print ") "}'

   else
      ## echo $json | ${jq_exec} -c '.subList[]' | gawk -v q="'" 'BEGIN {printf "json_list=("}; {gsub(/\047/,""); printf "%s%s%s ", q, $0, q}; END {print ") "}'
      ${jq_exec} -c '.subList[]' $json | gawk -v q="'" 'BEGIN {printf "json_list=("}; {gsub(/\047/,""); printf "%s%s%s ", q, $0, q}; END {print ") "}'
   fi

}

#######################################################################
function json_extract_string() {

   # 1 - field name to extract, the value is expected to be a string
   # 2 - json file name

   local __funcname=${FUNCNAME[0]}

   local field_name=$1
   local __json=$2

   local __value=""
   local cmd=""

   # Remove surrounding quotation marks with -r
   cmd="${jq_exec} -r '.${field_name}' $__json"

   if (( verbose ))
   then
      logq "${__funcname}: Executing cmd: $cmd"
   fi

   __value="$(eval $cmd)"

   echo -n "$__value"
}

#######################################################################
function json_extract_integer() {

   # 1 - field name to extract, the value is expected to be a string
   # 2 - json integer to be parsed
   # 3 - number of occurences to return

   local __funcname=${FUNCNAME[0]}
   local field_name=$1
   local json=$2
   local __occ
   local __lineno=${BASH_LINENO[0]}
   local cmd=""
   local __value=0

   if (( verbose ))
   then
      logq "json_extract_integer called from ${__lineno}"
   fi

   if (( $# == 3 ))
   then
     __occ=$3
   else
     __occ=1
   fi

   if [[ "${json_parse}" == "native" ]]
   then
     local regexp="(?<=\"${field_name}\":)([0-9]+)(?=[,}])"
     cmd="echo $json | grep --only-matching --perl-regex --regexp '$regexp' | head -${__occ}"
   fi

   if [[ "${json_parse}" == "jq" ]]
   then
     # Remove surrounding quotation marks with sed
     cmd="echo $json | ${jq_exec} '.${field_name}' | sed -e 's/\x22//g'"
   fi

   if (( verbose ))
   then
      logq "${__funcname}: Executing cmd: $cmd"
   fi

   __value="$(eval $cmd)"

   if (( verbose ))
   then
      logq "${__funcname}: returning __value: ${__value}"
   fi

   echo -n "${__value}"

}
#######################################################################
function conv_epoch() {

   # 1 - epoch timestamp to be converted
   #     this is a Podium timestamp

   echo "$(echo $1 | gawk '{printf "%s", strftime("%Y-%m-%d %H:%M:%S", substr($0,1,10))}')"

}
#######################################################################
function format_info_message() {

    # 1 - log message

    echo "$(echo $1 |  gawk '{gsub(/\\n/, "\012");gsub(/\\t/, "\011");print}')"


}
#######################################################################
function json_dump() {

    # 1 - calling function name
    # 3 - json

    local __funcname=$1
    local __json="$2"
    local __lineno=${BASH_LINENO[0]}
    local __cmd

    ## tmpfile=$(mktemp --suffix=.json file-XXXX)

    ## if [[ "${json_parse}" == "native" ]]
    ## then
    ##   log "${__funcname}: JSON = ${__json}"
    ## fi

    if [[ "${json_parse}" == "jq" ]]
    then
      log "json_dump called from: ${__funcname}: lineno: ${__lineno} __tmpfile: ${__json}"
      ## echo -n ${__json} > $tmpfile
      ## cmd="echo ${__json} | ${jq_exec} ${jq_style} '.'"
      ## cmd="cat $tmpfile | ${jq_exec} ${jq_style} '.'"
      ${jq_exec} ${jq_style} '.' $__json
      ## echo "$(eval $cmd)"

      ## cmd="cat $tmpfile | ${jq_exec} --compact-output '.'"
      ## echo "$(eval $cmd)" >> ${log_file} 
    fi

    # rm $tmpfile

}
#######################################################################
function cmpi_str() {

   # Performs a case insensitve compare of 2 strings

   # 1 - string 1
   # 2 - string 2

   # To be used in if, so returns 0 for match, 1 for no match

   __str1=$(echo "$1" | tr [:upper:] [:lower:])
   __str2=$(echo "$2" | tr [:upper:] [:lower:])

   if [[ "${__str1}" == "${__str2}" ]]
   then
      return 0
   else
      return 1
   fi
}

#######################################################################
function urlencode() {
    # urlencode <string>

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}
