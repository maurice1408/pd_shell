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
  echo "$(log_date) $@" | tee -a ./${log_file}
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

    local list_regexp="$1"
    local json="$2"

	# echo "${list_regexp}"
	# echo "${json}"

	declare -a json_list

	# eval $(echo $json | grep --only-matching --perl-regexp $list_regexp | gawk -v q="'" 'BEGIN {printf "json_list=("}; {printf "%s%s%s ", q, $0, q}; END {print ")"}')

	# declare -p json_list

	echo $json | grep --only-matching --perl-regexp $list_regexp | gawk -v q="'" 'BEGIN {printf "json_list=("}; {gsub(/\047/,""); printf "%s%s%s ", q, $0, q}; END {print ") "}'

}
#######################################################################
function json_extract_string() {

    # 1 - field name to extract, the value is expected to be a string
    # 2 - json string to be parsed

	local field_name=$1
	local json=$2

	local __value=""

	#local regexp="(?<=\"${field_name}\":)\"(.*?)\"(?=[,}])"
	#local regexp="(?<=\"${field_name}\":\")(.*?)(?=[\",}])"
	local regexp="(?<=\"${field_name}\":\")(.*?)(?=\")"

	local cmd
	cmd="echo $json | grep --only-matching --perl-regex '$regexp'"

	__value=$(eval $cmd)

	echo -n "$__value"

}

#######################################################################
function json_extract_integer() {

    # 1 - field name to extract, the value is expected to be a string
    # 2 - json integer to be parsed
    # 3 - number of occurences to return

	local field_name=$1
	local json=$2
	local __occ

	if (( $# == 3 ))
    then 
	  __occ=$3
	else
	  __occ=1
	fi

    local __value=0

	local regexp="(?<=\"${field_name}\":)([0-9]+)(?=[,}])"

	local cmd
	cmd="echo $json | grep --only-matching --perl-regex --regexp '$regexp' | head -${__occ}"

	__value=$(eval $cmd)

	echo -n "$__value"

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
