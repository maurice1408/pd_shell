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
