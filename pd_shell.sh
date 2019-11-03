#!/bin/bash

#
# SCRIPT: pd_shell
# AUTHOR: Maurice Hickey
# DATE:   May, 2018
# REV:    
#
# PLATFORM: 
#
# PURPOSE: 
#
# REV LIST:
#        DATE: May 2018
#        BY:   Maurice Hickey
#        MODIFICATION: Re-write for Podium 3.2+ support
#
#
# set -n   
# Uncomment to check script syntax, without execution.
#          
# NOTE: Do not forget to put the comment back in or
#          
#       the shell script will not execute!
# set -x   
# Uncomment to debug this shell script
#

# #######################
# External Functions
# #######################
SOURCE="${BASH_SOURCE[0]}"

while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to 
                                               # resolve it relative to the path where the 
                                               # symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# printf 'Invoked from %s\n\n' "${DIR}"

if [[ -e ${DIR}/pd_func_lib.sh ]]
then
  source ${DIR}/pd_func_lib.sh
else
  printf 'Error: %s not found\n\n' "${DIR}/pd_func_lib.sh"
  exit 1
fi

# #######################
# Variables
# #######################
# Create arrays, queue of entities to be loaded or workflow ids to be run
# and an array of running jobid's
declare -a run_que
declare -a running
declare -a gbl_entity_ids

declare -a object_ref
declare -i get_fields=0
declare -i get_script=0
declare -i has_param=0
declare -i index=0
declare -i is_entity=0
declare -i is_export=0
declare -i is_import=0
declare -i is_job=0
declare -i is_klean=0
declare -i is_report=0
declare -i is_long_report=0
declare -i is_source=0
declare -i is_source_conn=0
declare -i is_workflow=0
declare -i running_count=0
declare -i verbose=0



# #######################
# Podium REST API
# #######################
function pd_login() {

   
   # Expected args
   # 1 - username
   # 2 - password
   # 3 - podium_url
   # 4 - resultvar - varaible to return cookie file name

   # Logs user in and saves cookie file

   local __funcname=${FUNCNAME[0]}

   local __tmpfile=$(mktemp --suffix=.txt ${__funcname}-XXXX)

	if [[ $# -ne 4 ]]
	then
	  log "${__funcname}: expected 4 arguments, username, password, podium_url and return variable name" >&2
	  exit 1
	fi

   local user="$1"
   local pwd="$2"
   local podium_url="$3"
   local __resultvar=$4

   local api_function="j_spring_security_check"

   cookiename="cookie-jar-${RANDOM}.txt"

   cmd="curl --verbose --silent --show-error -c ${cookiename} --data 'j_username=$user&j_password=$pwd' '${podium_url}/${api_function}' > ${__tmpfile} 2>&1"

	if (( verbose ))
	then
      log "${__funcname}: cmd = ${cmd}"
	fi

	eval ${cmd}

   curlrc=$?

	if (( verbose ))
	then
     log "${__funcname}: cookiename = ${cookiename}"
     cat ${__tmpfile}
	fi

   login_err=$(grep -i 'error' ${__tmpfile} | wc -l)

   if (( login_err > 0 ))
   then
     log "$__funcname: api call ${api_function}: login to QDC failed"
     cat ${__tmpfile}
     exit 1
   else
     rm ${__tmpfile}
   fi

   if (( curlrc == 0 ))
   then
     if [[ -e ${cookiename} ]]
     then
       eval $__resultvar="'$cookiename'"
     else
       log "$__funcname: api call ${api_function}: failed cookie ${cookiename} not created"
       exit 1
     fi
   else
     log "$__funcname: api call ${api_function}: failed code: $curlrc"
     exit $curlrc
   fi
}

#######################################################################
function pd_about() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - return variable

   local __funcname=${FUNCNAME[0]}

   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   if [[ $# -ne 3 ]]
   then
     log "${__funcname}: expected 3 arguments, cookiename, podium_url, return_variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"

   local __resultvar=$3

   local api_function="about/getAboutInformation"

   cmd="${curlcmd} -b ${cookiename} -X GET '${podium_url}/${api_function}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
     ## json_dump "${__funcname}" "'${json}'"
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __version=$(json_extract_string "prodVersion" "$__tmpfile")
   __build=$(json_extract_string "buildVersion" "$__tmpfile")
   __schema=$(json_extract_string "schemaVersion" "$__tmpfile")

   __expiry=$(json_extract_string "licenseInfo.expiryDateString" "$__tmpfile")
   __pguri=$(json_extract_string "dataBaseProps.pstgrsDbUri" "$__tmpfile")
   __dist=$(json_extract_string "distribProps.distributionUri" "$__tmpfile")

   printf "Version:   %s\n" $__version
   printf "Build:     %s\n" $__build
   printf "Schema:    %s\n" $__schema
   printf "Expiry:    %s\n" $__expiry
   printf "PgUri:     %s\n" $__pguri
   printf "Dist:      %s\n" $__dist

   (( !verbose )) && rm $__tmpfile

   exit 0
}

#######################################################################
function pd_getversion() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - return variable

   # Returns a string giving the Podium major version

   local __funcname=${FUNCNAME[0]}
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   if [[ $# -ne 3 ]]
   then
     log "${__funcname}: expected 3 arguments, cookiename, podium_url, return_variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"

   local __resultvar=$3
   local __version=""


   local api_function="about/getAboutInformation"

   cmd="${curlcmd} -b ${cookiename} -X GET '${podium_url}/${api_function}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
     #log "${__funcname}: json = ${json}"
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __version=$(json_extract_string "prodVersion" "${__tmpfile}")

   if (( verbose ))
   then
     log "${__funcname}: Podium version = ${__version}"
   fi

   rm ${__tmpfile}

   eval $__resultvar="'$__version'"
}

#######################################################################
function pd_exportentity() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - source name
   # 4 - source id
   # 5 - entity name
   # 6 - return variable name - will contain the output file name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 6 ]]
   then
     log "${__funcname}: expected 6 arguments, cookiename, podium_url, sourcename, source_id, entity_name and return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local sourcename="$3"
   local sourceid="$4"
   local entityname="$5"
   local __resultvar=$6

   local __output_file_name=""
   local __output_file_timestamp=""

   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, source name: ${sourcename}, source id: ${sourceid}, entity: ${entityname}"
   fi

   local api_function="metadataExport/v1/entities"

   pd_checkentity ${cookiename} ${podium_url} ${sourceid} ${entityname} entity_id

   if [[ $entity_id -ne 0 ]]
   then
      __output_file_timestamp=$(date +"%Y%m%dT%H%M%S%Z")
     __output_file_name="entity_${sourcename}_${entityname}_${entity_id}_${__output_file_timestamp}.zip"

     if [[ -e ${__output_file_name} ]]
     then
       log "${__funcname}: Output file name ${__output_file_name} exists"
       exit 1
     fi

     cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entity_id}' --output ${__output_file_name}"
   else
      log "${__funcname}: source: ${sourcename}, entity: ${entityname} - not found"
     exit 1
   fi

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   # Check output file created
   assert "-e ${__output_file_name}" $LINENO

   # return output file name
   eval $__resultvar="'$__output_file_name'"
}


#######################################################################
function pd_import() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - object type (Sources, Entities, Dataflows)
   # 4 - filename
   # 5 - return variable name - will contain the import status

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 5 ]]
   then
     log "${__funcname}: expected 5 arguments, cookiename, podium_url, object_type, input_file_name and return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local object_type="$3"
   local import_file_name="$4"
   local __resultvar=$5

   local __tmpfile=$(mktemp --suffix=.json ${import_file_name}-XXXX)

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, object_type: ${object_type}, import_file: ${import_file_name}"
   fi

   if [[ $object_type == "Sources" || $object_type == "Entities" || $object_type == "DataFlows" ]]
   then
     true
   else
     log "${__funcname}: object_type must be one of Sources, Entities or DataFlows"
     exit 1
   fi

   if [[ -e ${import_file_name} ]]
   then
     true
   else
     log "${__funcname}: import_file: ${import_file_name} does not exist"
     exit 1
   fi

   local api_function="metadataImport/v2/upload"

   cmd="${curlcmd} -s -b ${cookiename} '${podium_url}/${api_function}/${object_type}' -F 'file=@${import_file_name}' --output ${__tmpfile}" 

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   if [[ ${object_type} == "Sources" || ${object_type} == "Entities" || ${object_type} == "DataFlows" ]]
   then
      __overall_status="$($jq_exec '.[] | .overallStatus' ${__tmpfile})"
   fi

   $jq_exec '.[] | .result' ${__tmpfile}

   eval $__resultvar="'$__overall_status'"

}

#######################################################################
function pd_exportsource() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - return variable name - will contain the output file name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, source_name and return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local sourcename="$3"
   local __resultvar=$4

   local __output_file_name=""
   local __output_file_timestamp=""

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, source: ${sourcename}"
   fi

   local api_function="metadataExport/v1/sources"

   pd_getsourceid ${cookiename} ${podium_url} ${sourcename} source_id 

   if [[ $source_id -ne 0 ]]
   then
     __output_file_timestamp=$(date +"%Y%m%dT%H%M%S%Z")
     __output_file_name="source_${sourcename}_${source_id}_${__output_file_timestamp}.zip"
      cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${source_id}' --output ${__output_file_name}"
   else
      log "${__funcname}: source: ${sourcename} - not found"
     exit 1
   fi

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   assert "-e ${__output_file_name}" $LINENO

   eval $__resultvar="'$__output_file_name'"

}

#######################################################################
function pd_exportdataflow() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow name
    # 4 - return variable name - will contain the output file name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, workflow name and return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local workflowname="$3"
   local __resultvar=$4

   local __output_file_name=""
   local __output_file_timestamp=""

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, dataflow: ${workflowname}"
   fi

   local api_function="metadataExport/v1/dataflows"

   pd_getdataflowid ${cookiename} ${podium_url} ${workflowname} dataflow_id 

   if [[ $dataflow_id -ne 0 ]]
   then
     __output_file_timestamp=$(date +"%Y%m%dT%H%M%S%Z")
     __output_file_name="dataflow_${workflowname}_${dataflow_id}_${__output_file_timestamp}.zip"
     cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${dataflow_id}' --output ${__output_file_name}"
   else
     log "${__funcname}: dataflow: ${workflowname} - not found"
     exit 1
   fi

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
      log "${__funcname}" "'$json'"
   fi

   assert "-e ${__output_file_name}" $LINENO
   
	eval $__resultvar="'$__output_file_name'"
}

#######################################################################
function pd_getscript() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 3 ]]
   then
     log "${__funcname}: expected 3 arguments, cookiename, podium_url, workflow name" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local workflowname="$3"

   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, dataflow: ${workflowname}"
   fi

   local api_function="transformation/getBundleAndPigScript"

   pd_getdataflowid ${cookiename} ${podium_url} ${workflowname} dataflow_id 

   if [[ $dataflow_id -ne 0 ]]
   then
     cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${dataflow_id}' --output ${__tmpfile}"
   else
     log "${__funcname}: dataflow: ${workflowname} - not found"
     exit 1
   fi

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   s="$(${jq_exec} -r '.pig_script' ${__tmpfile})"

   echo "${s@E}"

   if (( ! verbose ))
   then
     rm ${__tmpfile}
   fi

}

#######################################################################
function pd_getdataflowid() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - workflow name
   # 4 - workflow id return variable name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, workflow_name and return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local dataflowName="$3"
   local __resultvar=$4
   local __df_id

   local __dataflow_id=""
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)

   if (( verbose ))
   then
     log "${__funcname}: cookiename: ${cookiename}, dataflowName: ${dataflowName}"
   fi

   local api_function="transformation/v1/getDataflowId"

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}?dataflowName=${dataflowName}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __dataflow_id=$($jq_exec '.objectId' "${__tmpfile}" | sed -e 's/\x22//g')

   printf -v __df_id_num '%d' ${__dataflow_id} 2>/dev/null

   # eval $(echo "$json" | gawk '{print gensub(".*\"objectId\":\"([[:digit:]]+)\".*", "__workflow_id=\\1;","g")}')

   log "Dataflow: $dataflowName, objectId: ${__dataflow_id}, __df_id_num: ${__df_id_num}"

   rm ${__tmpfile}

   eval $__resultvar="'$__df_id_num'"

}

#######################################################################
function pd_getdataflowstatus() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - dataflow id
   # 4 - result status variable 
   # 5 - result record count  variable 

   # returns Podium dataflow status and recordCount in global variables status and recordcount

	local __funcname=${FUNCNAME[0]}

	if [[ $# -ne 5 ]]
	then
	  log "${__funcname}: expected 5 arguments, cookiename, podium_url, dataflow_id, status return variable and record count return variable" >&2
	  exit 1
	fi

   local cookiename="$1"
	local podium_url="$2"
	local dataflowId="$3"
	local __resultstatusvar=$4
	local __resultcountvar=$5
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)

   local __status=""
	local __recordcount=0

	local api_function="transformation/v1/loadAllWorkOrders/"

	cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${dataflowId}?count=1&sortAttr=loadTime&sortDir=DESC' --output ${__tmpfile}"
    
	if (( verbose ))
	then
	  log "${__funcname}: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if (( verbose ))
	then
     json_dump "${__funcname}" "${__tmpfile}"
	fi
	
   __full_list_size=$(echo $j | $jq_exec  '.fullListSize')

   for j in $($jq_exec -c '.subList[] | {status, recordCount}' ${__tmpfile})
   do
     __status=$(echo $j | $jq_exec -r '.status')
     __recordcount=$(echo $j | $jq_exec -r '.recordCount')
   done

   if (( verbose ))
	then
	  log "DataflowId: ${dataflowId}, status: ${__status}, records: ${__recordcount}"
	fi

   rm ${__tmpfile}

	eval $__resultstatusvar="'$__status'"
	eval $__resultcountvar="'$__recordcount'"

}

#######################################################################
function pd_rptdataflowstatus() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - dataflow id
   # 4 - rpt_count

   # Reports QDC dataflow status and recordCount

	local __funcname=${FUNCNAME[0]}

	if [[ $# -ne 4 ]]
	then
	  log "${__funcname}: expected 4 arguments, cookiename, podium_url, dataflow_id, rpt_count"
	  exit 1
	fi

   local cookiename="$1"
	local podium_url="$2"
	local dataflowId="$3"
	local rptcount=$4
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)

	local api_function="transformation/v1/loadAllWorkOrders/"

	cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${dataflowId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC' --output ${__tmpfile}"
    
	if (( verbose ))
	then
	  log "${__funcname}: cmd = ${cmd}"
	fi

	eval ${cmd}
	
	if (( verbose ))
	then
     json_dump "${__funcname}" "${__tmpfile}"
	fi

   $jq_exec --raw-output '.subList[] | [.name, .status, .recordCount, (.startTime | ( ./1000 | strftime("%Y-%m-%d %H:%M:%S"))), if (.endTime | length) > 0 then (.endTime | ( ./1000 | strftime("%Y-%m-%d %H:%M:%S"))) else "" end ] | @csv' ${__tmpfile}
   # $jq_exec --raw-output '.subList[] | [.name, .status, .recordCount, .startTime, .endTime ] | @csv' ${__tmpfile}

   if (( !verbose ))
   then
     rm ${__tmpfile}
   fi

}

#######################################################################
function pd_rptentitystatus() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - entity id
   # 4 - rpt_count

   # Reports Podium entity status and recordCount

   local __funcname=${FUNCNAME[0]}
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)

   if (( $# != 5 ))
   then
     log "${__funcname}: expected 5 arguments, cookiename, podium_url, entity_id, rpt_count, long_rpt"
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local entityId="$3"
   local rptcount=$4
   local __long_report=$5

   local api_function="entity/v1/loadLogs/"

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   $jq_exec --raw-output '.subList[] | [.sourceName, .entityName, .status, .recordCount, .goodRecordCount, .badRecordCount, .uglyRecordCount, (.startTime | ( ./1000 | strftime("%Y-%m-%d %H:%M:%S"))), if (.endTime | length) > 0 then (.endTime | ( ./1000 | strftime("%Y-%m-%d %H:%M:%S"))) else "" end, .deliveryId ] | @csv' ${__tmpfile}

   if (( !verbose ))
   then
      rm ${__tmpfile}
   fi

}

#######################################################################
function pd_dataloadcleanup() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - keep_count

    # Deletes data loads for an entity keeping the last keepcount loads

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, entity_id, keep_count"
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local entityId="$3"
   local keepcount="$4"
   local rptcount=500

   local api_function="entity/v1/loadLogs/"
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)
   local __tmpfile_cleanup=$(mktemp --suffix=.json ${__funcname}_cleanup-XXX)

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   # Construct a commas separated list of workorder ids, the keepcount most recent are excluded
   workorderids=$(${jq_exec} --argjson keep ${keepcount} '[ .subList[] | select(.status=="FINISHED") | {id: .id} ] | .[$keep:] | .[].id' ${__tmpfile})

   if (( verbose ))
   then
     log "Workorder id list is : $workorderids"
   fi

   #local api_function="entity/deleteDataForLoadLogs/15"
   local api_function="entity/v1/dataLoadCleanUp/15"

   for i in $workorderids
   do
     cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${i}' --output ${__tmpfile_cleanup}"
     log "$cmd"
     eval ${cmd}
     ${jq_exec} --color-output '.' "${__tmpfile_cleanup}"
   done

   if (( !verbose ))
   then
      rm ${__tmpfile}
      rm ${__tmpfile_cleanup}
   fi

}

#######################################################################
function pd_deleteexelogdata() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - dataflow id
    # 4 - keep_count

    # Deletes data for dataflow execution

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "pd_deleteexelogdata: expected 4 arguments, cookiename, podium_url, dataflow_id, keep_count"
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local dataflowId="$3"
   local keepcount="$4"
   local rptcount=500

   local api_function="transformation/v1/loadAllWorkOrders/"
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXX)
   local __tmpfile_cleanup=$(mktemp --suffix=.json ${__funcname}_cleanup-XXX)

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${dataflowId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   workorderids=$(${jq_exec} --argjson keep ${keepcount} '[ .subList[] | select(.status=="FINISHED") | {id: .id} ] | .[$keep:] | .[].id' ${__tmpfile})

   local api_function="transformation/deleteExeLogData/13"

   for i in $workorderids
   do
     log "Deleting workorder $i"
     cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${i}' --output ${__tmpfile_cleanup}"
     log $cmd
     eval ${cmd}
     ${jq_exec} --color-output '.' "${__tmpfile_cleanup}"
   done

   if (( !verbose ))
   then
      rm ${__tmpfile}
      rm ${__tmpfile_cleanup}
   fi

}

#######################################################################
function pd_loadlogdetail() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - log_id
    # 4 - result status variable 
    # 5 - result record count variable 
    # 6 - result good record count variable 

    # returns Podium load status and recordCount in global variables status and recordcount

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 6 ]]
   then
     log "${__funcname}: expected 6 arguments, cookiename, podium_url, log_id, status return variable, record count return variable and good record count variable" >&2
     exit 1
   fi

    # returns Podium load data status and recordCount in global variables status and recordcount

   local cookiename="$1"
   local podium_url="$2"
   local logId="$3"
   local __resultstatusvar=$4
   local __resultcountvar=$5
   local __resultgoodcountvar=$6

   local __status=""
   local __recordcount=0
   local __recordgoodcount=0
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   local api_function="entity/v1/loadLogDetail"

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${logId}' --output ${__tmpfile}"
   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __deliveyid=$(json_extract_string "deliveryId" ${__tmpfile})
   __status=$(json_extract_string "status" ${__tmpfile})
   __recordcount=$(json_extract_string "recordCount" ${__tmpfile})
   __goodrecordcount=$(json_extract_string "goodRecordCount" ${__tmpfile})

   log "${__funcname}: logId: ${logId}, ${__deliveryid} status: ${__status}, records: ${__recordcount}, goodrecords: ${__goodrecordcount}"

   if [[ "${json_parse}" == "jq" ]]
   then
     __infoMessage=$(json_extract_string "infoMessage" "${__tmpfile}")
     if [[ "$__status" == "FAILED" ]]
     then
       logq "${__funcname}: infoMessage = ${__infoMessage}" >&2
       printf "%s\n\n" "${__info_msg}"
     fi
   fi

   rm ${__tmpfile}

   eval $__resultstatusvar="'$__status'"
   eval $__resultcountvar="'$__recordcount'"
   eval $__resultgoodcountvar="'$__goodrecordcount'"
}

#######################################################################
function pd_executeworkflow() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - workflow id
   # 4 - has_param 
   # 5 - engine
   # 6 - return work order id variable name

   # returns Podium work order id

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 6 ]]
   then
     log "${__funcname}: expected 6 arguments recieved $#, cookiename, podium_url, workflow_id, has_param, engine, variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local workflowId="$3"
   local has_param="$4"
   local engine="$5"
   local __resultvar=$6

   local __workorder_id=0

   if (( has_param == 0 ))
   then

     # To-Do The execute call is to be deprecated in
     # Podium 3.2, check documentation
     local api_function="transformation/v1/executeDataFlow"

     cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${workflowId}/${engine}?bValidate=true'  -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{}' --compressed"
     log "${__funcname}: cmd = ${cmd}"

   else

     local api_function="transformation/v1/executeWithParmas"
     cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${workflowId}/${engine}?bValidate=true' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '${params}' --compressed"
     log "${__funcname}: cmd = ${cmd}"

   fi

   if (( verbose ))
   then
      log "${__funcname}: cmd = ${cmd}"
   fi

   __workorder_id=$(eval ${cmd})

   if (( verbose ))
   then
     log "${__funcname}: Returning workorder_id ${__workorder_id}"
   fi

   eval $__resultvar="'$__workorder_id'"
}

#######################################################################
function pd_loaddata() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - entity id
   # 4 - return workorder id variable name

   # returns Podium workorder_id

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, entity_id and return variable name" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local entity_id="$3"
   local __resultvar=$4

   local __workorder_id=0
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   local doAsynch="true"

   local api_function="entity/v1/loadDataForEntities"

   loadtime=$(gawk 'BEGIN {print strftime("%FT%T.000Z", systime(),1)}')

   cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${doAsynch}' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '[{\"loadTime\":\"${loadtime}\",\"entityId\":${entity_id}}]' --compressed --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __workorder_id=$(${jq_exec} '.[0] | .id' ${__tmpfile})

   if (( verbose ))
   then
     log "${__funcname}: workorder id = ${__workorder_id}"
   fi

   rm ${__tmpfile}

   eval $__resultvar="'$__workorder_id'"

}

#######################################################################
function pd_checkentity() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - source id
   # 4 - entity name
   # 5 - result variable name

   # returns entity_id if entity found or entity_id of zero if not

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 5 ]]
   then
     log "${__funcname}: expected 5 arguments, cookiename, podium_url, sourceid, entity_name, return variable name" 
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local sourceid="$3"
   local entityname="$4"
   local __resultvar=$5
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   local api_function="entity/v1/getEntitiesByCrit"

   local -i __ret_entity_id=0
   local -i __full_list_size=0

   local __encoded_entityname=$(urlencode "$entityname")

   entityname=$(echo $entityname | tr [:upper:] [:lower:])

   # cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${sourceid}/30/${entityname}'"
   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/2/${__encoded_entityname}?objType=EXTERNAL&sourceIds=$sourceid' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval $cmd)

   if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
   fi

   __full_list_size=$($jq_exec '.fullListSize' "${__tmpfile}")

   __ret_entity_id=0
   if (( __full_list_size == 0 ))
   then

     if (( verbose ))
     then
        log "${__funcname}: zero length entity list returned"
     fi

   else

     for j in $($jq_exec -c '.subList[] | {id, name}' ${__tmpfile})
     do

       __entity_name=$(echo $j | $jq_exec  '.name')

       if (( verbose ))
       then
         log "${__funcname}: __entity_name = ${__entity_name}, entityname = ${entityname}"
       fi

       if cmpi_str "\"$entityname\"" "$__entity_name"
       then
         __entity_id=$(echo $j | $jq_exec '.id')
         break
       fi

     done

   fi

   if (( verbose ))
   then
     log "Returning ${__entity_id} for entity_id,  source is: ${sourceid}, entity name : ${entityname}"
   else
     rm ${__tmpfile}
   fi


   eval $__resultvar="'${__entity_id}'"

}

#######################################################################
function pd_checksource() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - result variable name

    # returns true if source available or false if not.
    # Note: false is a check that the source does exist
    # Note: true is a check that the source does not exist
   
	local __funcname=${FUNCNAME[0]}
   local __tmpfile=$(mktemp --suffix=.json file-XXX)

	if [[ $# -ne 4 ]]
	then
	  log "${__funcname}: expected 4 arguments, cookiename, podium_url, sourcename, return variable name" 
	  exit 1
	fi

   local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local __resultvar=$4

	local api_function="source/v1/isAvailable"

	local is_available=""

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${sourcename}'"

	if (( verbose ))
	then
	  log "${__funcname}: cmd = ${cmd}"
	fi

	__is_available=$(eval $cmd)

	eval $__resultvar="'$__is_available'"
}

#######################################################################
function pd_getsources() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source pattern

    # Lists source names that match pattern

	local __funcname=${FUNCNAME[0]}

	if [[ $# -ne 3 ]]
	then
	  log "${__funcname}: expected 3 arguments, cookiename, podium_url, pattern" 
	  exit 1
	fi

   local cookiename="$1"
	local podium_url="$2"
	local pattern=$3

	local api_function="source/v1/getSources"
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}' --output ${__tmpfile}"

	if (( verbose ))
	then
	  log "${__funcname}: cmd = ${cmd}"
	fi

	eval ${cmd}
	
	if (( verbose ))
   then
     json_dump "${__funcname}" "${__tmpfile}"
	fi

   if [[ ${#pattern} > 0 ]]
   then
     ${jq_exec} --raw-output ".subList[] | select(.name|test(\"${pattern}\";\"i\")) | [.id, .name, .sourceType, .commProtocol, .externalData.SourceDataBaseTypeName] | @csv" ${__tmpfile}
   else
     ${jq_exec} --raw-output '.subList[] | [.id, .name, .sourceType, .commProtocol, .externalData.SourceDataBaseTypeName] | @csv' ${__tmpfile}
   fi

	if (( !verbose ))
   then
     rm ${__tmpfile}
	fi

}

#######################################################################
function pd_getentities() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - source_id url
   # 4 - result variable name

   # returns array, index is source id, value is source name

   local __funcname=${FUNCNAME[0]}

   if (( $# != 4 ))
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, source_id, return variable name" 
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local __source_id="$3"
   local __resultvar=$4

   local api_function="entity/v1/byParentId"

   local -i start=0
   local -i count=20
   local __entity_name

   while true
   do
     cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${__source_id}?count=${count}&start=${start}'"

     if (( verbose ))
     then
       log "${__funcname}: cmd = ${cmd}"
     fi

		json=$(eval ${cmd})
		
		if (( verbose ))
		then
		  log $json
		fi

		__full_list_size=$(json_extract_integer "fullListSize" "'${json}'")

		# Create json_list array
		# eval $(json_parse_list '{"id":\d+.*?}' "$json")
		eval $(json_parse_list '{"id":\d+.*?.*?"name":.*?}', "$json")

		if (( verbose ))
		then
		  log "${__funcname}: ${#json_list[@]} entries on entity list fullListSize is ${__full_list_size}"
		fi

		#
		# returning an array where the index is the src id and the
		# value is the src name
		for i in ${!json_list[@]}
		do
		  j="${json_list[$i]}"
		  #eval __entity_name=$(json_extract_string "name" "'${j}'")
		  #eval __entity_id=$(json_extract_integer "id" "'${j}'")
		  __entity_name=$(json_extract_string "name" "'${j}'" | tr A-Z a-z)
		  __entity_id=$(json_extract_integer "id" "'${j}'")
		  if (( verbose ))
		  then
			printf "Entity name: %s, id: %d\n" "${__entity_name}" "${__entity_id}"
		  fi
		  eval $__resultvar[${__entity_id}]="'${__entity_name}'"
		done

		start=$((start+count))

        if (( start > __full_list_size ))
		then 
		  break
		fi

	done

}

#######################################################################
function pd_getsourceid() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - source name
   # 4 - return variable name

   # returns source_id

   local __funcname=${FUNCNAME[0]}
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)


   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, source_name, return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local sourcename="$3"
   local __returnvar=$4

   local __source_id=0
   local __source_name=""

   local api_function="source/v1/getSourcesByCrit"

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/2/${sourcename}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
     json_dump "${__funcname}" "$__tmpfile"
   fi

   for j in $($jq_exec -c '.subList[] | {id, name}' ${__tmpfile})
   do
     __source_name=$(echo $j | $jq_exec  '.name')

     if (( verbose ))
     then
       log "${__funcname}: __source_name = ${__source_name}, sourcename = ${sourcename}"
     fi

     if cmpi_str "\"$sourcename\"" "$__source_name"
     then
        __source_id=$(echo $j | $jq_exec '.id')
       break
     fi
   done

   if (( verbose ))
   then
      log "${__funcname}: __source_id = ${__source_id}"
   fi

   rm ${__tmpfile}

   eval $__returnvar="${__source_id}"

}

#######################################################################
function pd_getentityid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source id
    # 4 - entity name
    # 5 - return variable name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 5 ]]
   then
     log "${__funcname}: expected 5 arguments, cookiename, podium_url, source_id, entity_name, return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local sourceid="$3"
   local entityname="$4"
   local __returnvar=$5
   local __tmpfile=$(mktemp --suffix=.json ${__funcname}-XXXX)

   local __entity_id=0
   local api_function="entity/v1/getEntitiesByCrit"

   # Deprecated as of v4 cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}?srcName=${sourcename}&entityName=${entityname}'"
   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/2/${entityname}?objType=EXTERNAL&sourceIds=${sourceid}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   if (( verbose ))
   then
     json_dump "${__funcname}" ${__tmpfile}
   fi

   eval $(echo "$json" | gawk '{print gensub("^..\"id\":([[:digit:]]+).*", "__entity_id=\\1","g")}') 

   __entity_id=$($jq_exec '.id' ${__tmpfile})

   if (( verbose ))
   then
     log "${__funcname}: return - Source: ${sourceid}, Entity: ${entityname}, nid: ${__entity_id}"
   fi

   rm ${__tmpfile}

   eval $__returnvar="'$__entity_id'"

}


#######################################################################
function pd_getentityproperty() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - property name
    # 5 - return variable name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 5 ]]
   then
     log "${__funcname}: expected 5 arguments, cookiename, podium_url, entity_id, property name, return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local entityid="$3"
   local propertyname="$4"
   local __returnvar=$5
   local __tmpfile=$(mktemp --suffix=.txt ${__funcname}-XXXX)

   local __property_value=""

   local api_function="entity/v1/getProperty"

   cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityid}/${propertyname}' --output ${__tmpfile}"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   eval ${cmd}

   __property_value=$(< ${__tmpfile})

   if (( verbose ))
   then
     log "${__funcname}: return - nid: ${entityid}, property: ${propertyname} value: ${__property_value}"
   else
     rm ${__tmpfile}
   fi

   eval $__returnvar="'$__property_value'"

}

#######################################################################
function pd_getjobs() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - return variable name an array of jobs, index is job_id, value is job_name

	local __funcname=${FUNCNAME[0]}

	if [[ $# -ne 3 ]]
	then
	  log "${__funcname}: expected 3 arguments, cookiename, podium_url, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local __returnvar=$3

	local api_function="publish/v1/getJobs"

	cmd="${curlcmd} -s -b ${cookiename} -X GET '${podium_url}/${api_function}'"
  
    if (( verbose ))
	then
	  log "${__funcname}: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if (( verbose ))
	then
	  log "${__funcname}: ${json}"
	fi

	unset __pdjob
	declare -a __pdjob 
	
    # Remove the subList wrapping, turn each job {} into a record and parse out in gawk
    # result is the array pdjob, the indexes are the job id and the value the job name

	eval $(echo ${json} | sed -r -e 's/\{"subList":\[//' -e 's/\].*//' -e 's/\},\{/\}\n\{/g' | gawk 'BEGIN {ORS=";"} {print gensub(".*\"id\":([[:digit:]]+),.*\"name\":\"([a-zA-Z0-9_]+)\".*", "__pdjob[\\1]=\"\\2\"", "g")}')

    if (( verbose ))
	then
	  log "${__funcname}: returning ${#__pdjob[@]} jobs - ${!__pdjob[*]}, ${__pdjob[@]}"
	fi
  
    # returning an array where the index is the job id and the
    # value is the job name
    for j in ${!__pdjob[@]}
	do
	  eval $__returnvar[$j]="'${__pdjob[$j]}'"
	done
}

#######################################################################
function pd_getjobid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - job name
    # 4 - return variable name

	local __funcname=${FUNCNAME[0]}

	if [[ $# -ne 4 ]]
	then
	  log "${__funcname}: expected 4 arguments, cookiename, podium_url, jobname, return variable" >&2
	  log "${__funcname}: recieved |$@|" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local jobname="$3"
	local __returnvar=$4

    local __job_id=0

	pd_getjobs ${cookiename} ${podium_url} output_job_list

    local oldcasematch=$(shopt -p nocasematch)
    shopt -s nocasematch

	for i in ${!output_job_list[@]}
	do
	  jn=${output_job_list[$i]}
	  if [[ ${jn} == ${jobname} ]]
	  then
	    __job_id=$i
	  fi
	done

    eval "$oldcasematch"

    if (( verbose ))
	then
	  log "${__funcname}: returning - ${__job_id}, ${output_job_list[${__job_id}]}"
	fi

    unset output_job_list

	eval $__returnvar="'$__job_id'"

}

#######################################################################
function pd_schedule() {

   # Expected args
   # 1 - cookiename
   # 2 - podium url
   # 3 - job id
   # 4 - return variable name

   local __funcname=${FUNCNAME[0]}

   if [[ $# -ne 4 ]]
   then
     log "${__funcname}: expected 4 arguments, cookiename, podium_url, jobid, return variable" >&2
     exit 1
   fi

   local cookiename="$1"
   local podium_url="$2"
   local jobid="$3"
   local __returnvar=$4

   local api_function="publish/v1/schedule"

   cmd="${curlcmd} -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${jobid}'"

   if (( verbose ))
   then
     log "${__funcname}: cmd = ${cmd}"
   fi

   json=$(eval ${cmd})

   if (( verbose ))
   then
     log "${__funcname}: ${json}"
   fi

   eval $__returnvar="'$json'"

}

pd_logout() {

   # Expected args
   # 1 - cookename
   # 2 - podium url

   local cookiename="$1"
   local podium_url="$2"

   local api_function="j_spring_security_logout"

   curl -s -b ${cookiename} "${podium_url}"'/'"${api_function}"
   curl -s -j -b ${cookiename} "${podium_url}"
}


usage() {

cat <<EOF

Usage:
======

This function uses the Podium REST API via cURL to:

1. Execute a data load or 
2. Run a Prepare Dataflow or
3. Schedule a Dataset publish Job

EOF

}

# ########################
# Process cmd line options
# ########################

if [[ $# -eq 0 ]]; then 
   usage
   exit 1
fi

while getopts ":ixghavrklfc:e:w:j:s:mn:y:p:t:z:" opt
do
   case $opt in
   a  ) about=1
        ;;
   v  ) verbose=1
           ;;
   y  ) yaml=$OPTARG
        ;;
   t  ) engine=$OPTARG
        ;;
   s  ) is_source=1
        podium_source=$OPTARG
        ;;
   w  ) is_workflow=1
        pd_objects=$OPTARG
        ;;
   e  ) is_entity=1
        pd_objects=$OPTARG
        ;;
   m  ) max_jobs=$OPTARG
        ;;
   n  ) is_source_conn=1
        ;;
   x  ) is_export=1
        ;;
   i  ) is_import=1
        ;;
   g  ) get_script=1
        ;;
   z  ) import_file_name=$OPTARG
        ;;
   r  ) is_report=1
        ;;
   f  ) get_fields=1
        ;;
   j  ) is_job=1
        job_name=$OPTARG
        ;;
   p  ) has_param=1
        params=$OPTARG
        ;;
   c  ) rpt_count=$OPTARG
        ;;
   k  ) is_klean=1
        ;;
   l  ) is_long_report=1
        ;;
   h  ) usage
        exit
       ;;
   \? ) usage
        exit 1
       ;;
   :  ) echo "Option -$OPTARG requires an argument" >&2
        exit 1
   esac
done


# Shift the options out of the way
shift $((OPTIND-1))

# Creates an indexed array or entity or workflow object names
run_que=($pd_objects)

if (( verbose ))
then
   echo "Run queue size is ${#run_que[@]}"
fi

# #######################
# Process yaml options
# #######################
if [[ -z ${yaml} ]]
then
  echo "yaml config file must be specified" >&2
  exit 1
fi

if [[ -f ${yaml} ]]
then
   if (( verbose ))
   then
     log "Yaml options: $(parse_yaml ${yaml})"
   fi

   eval $(parse_yaml ${yaml})
else
   echo "Yaml options file ${yaml} does not exist" >&2
   exit 1
fi

# #######################
# Defaults
# #######################
max_jobs=${max_jobs:-$default_max_jobs}
refresh_interval=${default_refresh_interval:-2}
log_file=${default_log_file:-"./pd_shell.log"}
engine=${engine:-$default_engine}
rpt_count=${rpt_count:-5}
json_parse=${json_parse:-"native"}
json_style=${json_style:-""}
curldir=${curl_tmp:-"/tmp"}


if (( verbose ))
then
  curlcmd="curl --verbose"
else
  curlcmd="curl --silent --show-error"
fi

if (( is_klean && rpt_count < 0 ))
then
   log "The count on an ingest or dataflow clean must be >= 0"
   exit 1
fi

# #######################
# Establish Podium Sesssion
# #######################
pd_login $podium_user $podium_pw $podium_url cookiename

if [[ $about ]]
then
  pd_about ${cookiename} ${podium_url} podium_release
  log "Podium release is ${podium_release}"
fi

pd_getversion ${cookiename} ${podium_url} podium_version

# #######################
# Validate options     
# #######################

# Must specify operation
if (( (is_source + is_entity + is_workflow + is_export + is_import + is_job + get_script) == 0))
then
  log "Need one of -s, -e, -w, -i, -xi, -g or -j options" >&2
  exit 1
fi

# Connot perform an entity and a workflow operation
if (( is_entity == 1 && is_workflow == 1 ))
then
  log "Specify -e OR -w option, not both" >&2
  exit 1
fi

# If load then must have a source
if [[ ${is_entity} -eq 1 && -z "${podium_source}" ]]
then
   log "No source set for entities" >&2
   exit 1
fi

# If entity operation then check that the source is a valid source
if [[ $podium_source ]]
then

  if [[ ${podium_source:0:1} == "~" ]]
  then

    pat=${podium_source:1}

    if (( ${#pat} == 0 ))
    then
      pat='.*'
    fi

    if (( $verbose ))
    then
      log "Source name pattern, pat = ${pat}"
    fi

    pd_getsources ${cookiename} ${podium_url} ${pat}

    exit 0

   fi

   pd_getsourceid  ${cookiename} ${podium_url} ${podium_source} source_id

   if (( source_id == 0 && !is_import))
   then
     log "${podium_source} is not a valid source"
     exit 1
   fi

   if (( verbose ))
   then
     log "${podium_source} is id ${source_id}"
   fi

fi

if (( is_export && is_import ))
then
   log "Cannot specify both export -x and import -i options"
   exit 1
fi

if (( verbose ))
then
  log "Queue = ${run_que[@]}"
fi

if (( is_entity && !is_import ))
then

  if (( verbose ))
  then
    log "Validating entity names on queue, ${#run_que[*]} entities"
  fi

  for e in ${run_que[*]}
  do

    pd_checkentity ${cookiename} ${podium_url} ${source_id} $e entity_id

    if (( entity_id == 0 ))
    then
      log "${podium_source} entity $e, is not valid"
      exit 1
    else
      if (( verbose ))
      then
        log "${podium_source}, entity: $e, id: ${entity_id}"
      fi
    fi

  done

fi

# ################################
# Export
# ################################

if (( is_export ))
then

  # Validate that an object type given
  if (( (is_entity + is_source + is_workflow) == 0 ))
  then
    log "One of source, entity or workflow must be specified with export"
    exit 1
  fi

  # If entity check source given
  if (( is_source == 0 && is_entity == 1 ))
  then
    log "A source must be given if exporting an entity"
    exit 1
  fi

  if (( (is_source + is_entity) > 0 && is_workflow == 1 ))
  then
    log "Cannot mix source/entity and workflows in an export"
    exit 1
  fi

  if (( (is_source == 1) && (is_entity == 0 ) ))
  then
    pd_exportsource ${cookiename} ${podium_url} ${podium_source} output_file_name
    log "Source ${podium_source} exported to file ${output_file_name}"   
    exit
  fi

  if (( is_entity ))
  then
    for e in ${run_que[*]}
    do
      pd_exportentity ${cookiename} ${podium_url} ${podium_source} ${source_id} ${e} output_file_name
      log "Entity ${podium_source}.${e} exported to file ${output_file_name}"   
    done
    exit
  fi

  if (( is_workflow ))
  then
    for w in ${run_que[*]}
    do
      pd_exportdataflow ${cookiename} ${podium_url} ${w} output_file_name
      log "Dataflow ${w} exported to file ${output_file_name}"   
    done
    exit
  fi
fi

# ################################
# Import
# ################################

if (( is_import ))
then

  # Validate that an object type given
   if (( ((is_entity + is_source + is_workflow)) == 0 ))
   then
     log "One of source, entity or workflow must be specified with import"
     exit 1
   fi

   # Validate that only one object type given
   if (( (is_entity + is_source) && (is_workflow)  ))
   then
     log "Only one of source, entity or workflow to be specified with import"
     exit 1
   fi

   # Set object type
   if (( is_source && !is_entity ))
   then
     podium_object_type="Sources"
   elif (( is_entity && is_source ))
   then
     podium_object_type="Entities"
   elif (( is_workflow ))
   then
     podium_object_type="DataFlows"
   else
     log "Import object error"
     exit 1
   fi

   for e in ${run_que[*]}
   do
     pd_import ${cookiename} ${podium_url} ${podium_object_type} ${e} output_status
     log "Import status: $e - ${output_status}"
   done

   exit

fi

# ################################
# Get dataflow script
# ################################

if (( get_script ))
then

  # Validate that an object type given
  if (( ! is_workflow ))
  then
    log "Dataflow name must be specified with get script"
    exit 1
  else
    for w in ${run_que[*]}
    do
      pd_getscript ${cookiename} ${podium_url} ${w}
    done
    exit 0
  fi

fi

# ################################
#  Run publish job or job list
# ################################
if (( is_job ))
then
   if (( verbose ))
   then
     log "job name: $job_name"
   fi

   if [[ $job_name == "?" ]]
   then
     pd_getjobs ${cookiename} ${podium_url} output_job_list

     for j in ${!output_job_list[@]}
     do
       printf "Id: %5d, Name: %s\n" $j ${output_job_list[$j]}
     done

   else

     pd_getjobid ${cookiename} ${podium_url} $job_name output_job_id
     log "Job: ${job_name}, id: ${output_job_id}"
     if [[ $output_job_id -ne 0 ]]
     then
       pd_schedule ${cookiename} ${podium_url} ${output_job_id} output_json
       log "Job scheduled: ${output_json}"
     else
      log "Job: ${job_name} not found" >&2
     fi
   fi

   exit
fi

job_count=${#run_que[@]}

log "${job_count} tasks on queue"

if [[ "$job_count" -eq "0" && $is_export -eq 0 ]]
then
   log "No entities or workflows given" >&2
   exit 1
fi

# ################################
# Load or execute
# ################################

if (( is_entity ))
then
  if (( is_report ))
  then
    log "Reporting on entities"
    max_jobs=1
    refresh_interval=1
  elif (( is_klean ))
  then
    log "Performing data load clean up"
    max_jobs=1
    refresh_interval=1
  else
    log "Processing entities for podium_source: ${podium_source}, maximum concurrent jobs ${max_jobs}, ${job_count} entities, refesh interval ${refresh_interval}"
  fi
fi

if (( is_workflow ))
then
  if (( is_report ))
  then
    log "Reporting on workflows"
    max_jobs=1
    refresh_interval=1
  elif (( is_klean ))
  then
    log "Performing dataflow clean up"
     max_jobs=1
     refresh_interval=1
  else
    log "Executing workflows, maximum concurrent jobs ${max_jobs}, ${job_count} jobs, refesh interval ${refresh_interval}"
  fi
fi

# ################################
# Report Source Connections
# ################################
if (( is_source_conn ))
then
   log "processing source connections"
fi

# Initialise counters etc
index=0
running_count=0

# ###############################################################
# Loop over the queue starting up to max_job at any one time
# ###############################################################
while [[ "${index}" -lt "${job_count}" ]]
do
   log "Index : ${index}"

   running_count=${#running[@]}

   log "${running_count} jobs running"

   object_name=${run_que[$index]}

   # Check if space to add new load job, if not wait until one
   # of the running jobs finished and add next entity
   if [[ ${running_count} -lt ${max_jobs} ]]
   then

   # Start a new job and push onto running array
   # Maintain a sparse job_id array where the numeric
   # index is either the entity workorder id or workflow id
   # This is done to ease the task of fetching the log
   # for the task which for entities is by logid and
   # for workflows has to be by name

     if (( is_entity ))
     then

       pd_checkentity ${cookiename} ${podium_url} ${source_id} ${object_name} entity_id

       if (( verbose ))
       then
         log "${podium_source}.${object_name}, found as entity_id: ${entity_id}"
       fi

       if (( entity_id ==  0 ))
       then
         log "Entity ${podium_source}.${object_name} not found"
         exit 1

       else

         if (( is_report ))
         then
           pd_rptentitystatus ${cookiename} ${podium_url} ${entity_id} $rpt_count ${is_long_report}
           job_id=0
         elif (( is_klean ))
         then
           pd_getentityproperty ${cookiename} ${podium_url} ${entity_id} "entity.base.type" base_type

           log "Entity: ${object_name} is a entity.base.type of: ${base_type}"

           if [[ ${base_type} == "\"Snapshot\"" ]]
           then
             pd_dataloadcleanup ${cookiename} ${podium_url} ${entity_id} $rpt_count
             job_id=0
           else
             log "${object_name} is not a Snapshot base type but is, ${base_type}, cannot clean"
           fi
         else
           pd_loaddata ${cookiename} ${podium_url} ${entity_id} workorder_id
           job_id=$workorder_id
         fi

       fi

     elif (( is_workflow ))
     then

       workflow_name=$object_name

       pd_getdataflowid ${cookiename} ${podium_url} ${workflow_name} workflow_id

       if [[ $workflow_id -eq 0 ]]
       then 
         log "Workflow: ${workflow_name}, not found"
         let "index = $index + 1"
         continue
       else
         if [[ $is_report -eq 1 ]]
         then
           pd_rptdataflowstatus ${cookiename} ${podium_url} ${workflow_id} $rpt_count
           job_id=0
         elif [[ $is_klean -eq 1 ]]
         then
           pd_deleteexelogdata ${cookiename} ${podium_url} ${workflow_id} $rpt_count
           job_id=0
         else
           log "Starting workflow: ${workflow_name}"
           log "Workflow: ${workflow_name}, found id=${workflow_id}"

           if [[ $has_param -eq 1 ]]
           then
             log "Parameters: ${params}"
           fi

           pd_executeworkflow ${cookiename} ${podium_url} ${workflow_id} ${has_param} ${engine} workorder_id
           job_id=${workflow_id}
         fi

       fi
     fi

     if [[ $job_id -ne 0 ]]
     then
       log "${job_id} ${object_name} started"
       # Return from LoadData is a numeric workorder
       # Return from ExecuteWorkflow is the string wfname.engine.timestamp

       object_ref[$job_id]=$object_name

       # Push onto running array, the running array is an array of workorder numbers
       # for entities and workflow nid for workflows

       running=("${running[@]}" ${job_id})
     fi

     sleep ${refresh_interval}

     # And process next entity / workflow
     let "index = $index + 1"

   else
     # Run over running jobs until a job finishes then add new job
     finished_count=0
     while [ "${finished_count}" -eq "0" ]
     do
       running_index=0

       while [ "${running_index}" -lt "${running_count}" ]
       do
         sleep ${refresh_interval}

         job_id=${running[$running_index]}

         if (( verbose ))
         then
           log "Inspecting job ${job_id}"
         fi

         if (( is_entity ))
         then
           pd_loadlogdetail ${cookiename} ${podium_url} ${job_id} status recordcount goodrecordcount
         fi

         if [[ $is_workflow -eq 1 ]]
         then
           pd_getdataflowstatus ${cookiename} ${podium_url} ${job_id} status recordcount
         fi

         if [[ "$status" == "FINISHED" ]]
         then
           let "finished_count = $finished_count + 1"
           if (( is_entity ))
           then
             log "Entity: ${job_id} ${object_ref[$job_id]} is finished, ${recordcount} records, unsetting ${running_index}"
           elif [[ $is_workflow -eq 1 ]]
           then
             log "Workflow: ${job_id} ${object_ref[$job_id]} is finished, ${recordcount} records, unsetting ${running_index}"
           fi
           unset running[$running_index]
           #if [[ $is_entity ]]
           #then
           #  unset entity_ref[$job_id]
           #fi
           break
         elif [[ "$status" == "FAILED" || "$status" == "TERMINATED" || "$status" == "TERMINATION_REQUSTED" ]]
         then
           if (( is_entity ))
           then
             log "Entity: ${job_id} ${object_ref[$job_id]} is ${status}"
             #unset entity_ref[$job_id]
           elif [[ $is_workflow -eq 1 ]]
             then
             log "Workflow: ${job_id} ${object_ref[$job_id]} is ${status}"
           fi
           unset running[$running_index]
           break
         else
           if (( is_entity ))
           then
             log "Entity:${job_id} ${object_ref[$job_id]} is ${status}"
           elif [[ $is_workflow -eq 1 ]]
           then
             log "Workflow: ${job_id} ${object_ref[$job_id]} is ${status}"
           fi
         fi

         let "running_index = $running_index + 1"

       done

       # Re-factor the running array so index starts at zero again
       running=("${running[@]}")
       log "Still running ${running[@]}"

     done
  fi

  if (( is_entity ))
  then
    log "Entity Loads: ${running[@]}"
  else
    log "Workflows Running: ${running[@]}"
  fi

done

running=("${running[@]}")
running_count=${#running[@]}
running_index=0
if [[ ${verbose} ]]
then
  log "Entering final loop, waiting on ${#running[@]} jobs"
fi

# Enter a while loop on any asynch loads or workflows
# that are still running.

# This loop should never be entered for exports / imports
# which are done synchronously 

while [ ${running_count} -gt 0 ]
do

   assert "$is_export -eq 0" $LINENO 

   running_index=0

   log "${running_count} jobs still running"
   while [ ${running_index} -lt ${running_count} ]
   do

     job_id=${running[$running_index]}

     if (( is_entity ))
     then
       pd_loadlogdetail ${cookiename} ${podium_url} ${job_id} status recordcount goodrecordcount
     fi

     if (( is_workflow ))
     then
       pd_getdataflowstatus ${cookiename} ${podium_url} ${job_id} status recordcount
     fi

     log "${job_id} - ${object_ref[${job_id}]} ${status}"

     if [[ "${status}" == "FINISHED" || "${status}" == "FAILED"  || "${status}" == "TERMINATED" || "$status" == "TERMINATION_REQUESTED" ]]
     then
       log "${job_id} ${object_ref[$job_id]} is ${status}, ${recordcount} records"
       unset running[$running_index]
     else
       sleep ${refresh_interval}
     fi

     let "running_index = $running_index + 1"

   done

   running=("${running[@]}")
   running_count=${#running[@]}

done

pd_logout "${cookiename}" "${podium_url}"
rm ${cookiename}
log "Done"
