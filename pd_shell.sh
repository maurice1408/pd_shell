#!/bin/bash

# #######################
# External Functions
# #######################
source ./pd_func_lib.sh

# #######################
# Variables
# #######################
# Create arrays, queue of entities to be loaded or workflow ids to be run
# and an array of running jobid's
declare -a run_que
declare -a running
declare -a object_ref
declare -i is_source=0
declare -i is_entity=0
declare -i is_workflow=0
declare -i is_export=0
declare -i is_import=0
declare -i is_job=0
declare -i is_report=0
declare -i is_klean=0
declare -i get_fields=0
declare -i has_param=0


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

	if [[ $# -ne 4 ]]
	then
	  log "pd_login: expected 4 arguments, username, password, podium_url and return variable name" >&2
	  exit 1
	fi

    local user="$1"
    local pwd="$2"
    local podium_url="$3"
	local __resultvar=$4

    local api_function="j_spring_security_check"

    cookiename="cookie-jar-${RANDOM}.txt"

    cmd="curl -s -c ${cookiename} --data 'j_username=$user&j_password=$pwd' '${podium_url}/${api_function}'"
	if [[ $verbose ]]
	then
      log "pd_login: cmd = ${cmd}"
	fi

	eval ${cmd}

	if [[ $verbose ]]
	then
      log "pd_login: cookiename = ${cookiename}"
	fi

	eval $__resultvar="'$cookiename'"

}

function pd_about() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - return variable

	if [[ $# -ne 3 ]]
	then
	  log "pd_about: expected 3 arguments, cookiename, podium_url, return_variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"

	local __resultvar=$3

	local api_function="about/getAboutInformation"

	cmd="curl -b ${cookiename} -X GET '${podium_url}/${api_function}'"

	if [[ $verbose ]]
	then
	  log "pd_about: cmd = ${cmd}"
	fi

    json=$(eval ${cmd})

	if [[ $verbose ]]
	then
	  log "pd_about: ${json}"
	fi

	eval $(echo "$json" | gawk '{print gensub(".*\"prodVersion\":\"(.*)\",\"buildVersion\":\"([[:digit:]]+)\",.*","__version=\\1;__build=\\2","g")}')
	eval $(echo "$json" | gawk '{print gensub(".*\"schemaVersion\":\"([[:digit:]]+)\",.*","__schema=\\1;","g")}')
	eval $(echo "$json" | gawk '{print gensub(".*\"expiryDateString\":\"([[:digit:]]+-[[:digit:]]+-[[:digit:]]+)\",.*","__expiry=\\1;","g")}')

	printf "Version:   %s\n" $__version
	printf "Build:     %d\n" $__build
	printf "Schema:    %d\n" $__schema
	printf "Expiry:    %s\n" $__expiry

	eval $__resultvar="'$__version'"
}

function pd_exportentity() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - entity name
    # 5 - return variable name - will contain the output file name

	if [[ $# -ne 5 ]]
	then
	  log "pd_exportentity: expected 5 arguments, cookiename, podium_url, source_name, entity_name and return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local entityname="$4"
	local __resultvar=$5
	local pdfunc="pd_exportentity"

	local __output_file_name=""
	local __output_file_timestamp=""

	if [[ $verbose ]]
	then
	  log "${pdfunc}: cookiename: ${cookiename}, source: ${sourcename}, entity: ${entityname}"
	fi

	local api_function="metadataExport/v1/entities"

	pd_getentityid ${cookiename} ${podium_url} ${sourcename} ${entityname} entity_id 

	if [[ $entity_id -ne 0 ]]
	then
	  __output_file_timestamp=$(gawk 'BEGIN {print strftime("%FT%T", systime(),1)}')
	  __output_file_name="${sourcename}_${entityname}_${entity_id}_${__output_file_timestamp}.zip"

	  if [[ -e ${__output_file_name} ]]
	  then
	    log "${pd_func}: Output file name ${__output_file_name} exists"
		exit 1
	  fi

      cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entity_id}' --output ${__output_file_name}"
	else
      log "${pdfunc}: source: ${sourcename}, entity: ${entityname} - not found"
	  exit 1
	fi

	if [[ $verbose ]]
	then
	  log "${pdfunc}: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})

    # Check output file created
    assert "-e ${__output_file_name}" $LINENO
	
    # return output file name
	eval $__resultvar="'$__output_file_name'"
}


function pd_import() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - object type (Sources, Entities, Workflows)
    # 4 - filename
    # 5 - return variable name - will contain the import status

	local pdfunc="pd_import"

	if [[ $# -ne 5 ]]
	then
	  log "${pdfunc}: expected 5 arguments, cookiename, podium_url, object_type, input_file_name and return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local object_type="$3"
	local import_file_name="$4"
	local __resultvar=$5

	if [[ $verbose ]]
	then
	  log "${pdfunc}: cookiename: ${cookiename}, object_type: ${object_type}, import_file: ${import_file_name}"
	fi

	if [[ $object_type == "Sources" || $object_type == "Entities" || $object_type == "Workflows" ]]
	then
      true
	else
      log "${pdfunc}: object_type must be one of Sources, Entities or Workflows"
	  exit 1
	fi

	if [[ -e ${import_file_name} ]]
	then
	  true
	else
	  log "${pdfunc}: import_file: ${import_file_name} does not exist"
	  exit 1
	fi

	local api_function="metadataImport/v2/upload"

    cmd="curl -s -b ${cookiename} '${podium_url}/${api_function}' -F 'file=@${import_file_name}'" 

	if [[ $verbose ]]
	then
	  log "pd_import: cmd = ${cmd}"
	fi

#	json=$(eval ${cmd})

#    assert "-e ${__output_file_name}" $LINENO
	
#	eval $__resultvar="'$__output_file_name'"
}

function pd_exportsource() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - return variable name - will contain the output file name

	if [[ $# -ne 4 ]]
	then
	  log "pd_exportsource: expected 4 arguments, cookiename, podium_url, source_name and return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local __resultvar=$4

	local __output_file_name=""
	local __output_file_timestamp=""

	if [[ $verbose ]]
	then
	  log "pd_exportsource: cookiename: ${cookiename}, source: ${sourcename}"
	fi

	local api_function="metadataExport/v1/sources"

	pd_getsourceid ${cookiename} ${podium_url} ${sourcename} source_id 

	if [[ $source_id -ne 0 ]]
	then
	  __output_file_timestamp=$(gawk 'BEGIN {print strftime("%FT%T", systime(),1)}')
	  __output_file_name="${sourcename}_${source_id}_${__output_file_timestamp}.zip"
      cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${source_id}' --output ${__output_file_name}"
	else
      log "pd_exportsource: source: ${sourcename} - not found"
	  exit 1
	fi

	if [[ $verbose ]]
	then
	  log "pd_exportsource: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})

    assert "-e ${__output_file_name}" $LINENO
	
	eval $__resultvar="'$__output_file_name'"
}

function pd_exportworkflow() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow name
    # 4 - return variable name - will contain the output file name

	if [[ $# -ne 4 ]]
	then
	  log "pd_exportworkflow: expected 4 arguments, cookiename, podium_url, workflow name and return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowname="$3"
	local __resultvar=$4

	local __output_file_name=""
	local __output_file_timestamp=""

	if [[ $verbose ]]
	then
	  log "pd_exportworkflow: cookiename: ${cookiename}, workflow: ${workflowname}"
	fi

	local api_function="metadataExport/v1/workflows"

	pd_getworkflowid ${cookiename} ${podium_url} ${workflowname} workflow_id 

	if [[ $workflow_id -ne 0 ]]
	then
	  __output_file_timestamp=$(gawk 'BEGIN {print strftime("%FT%T", systime(),1)}')
	  __output_file_name="${workflowname}_${workflow_id}_${__output_file_timestamp}.zip"
      cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${workflow_id}' --output ${__output_file_name}"
	else
      log "pd_exportworkflow: workflow: ${workflowname} - not found"
	  exit 1
	fi

	if [[ $verbose ]]
	then
	  log "pd_exportworkflow: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})

    assert "-e ${__output_file_name}" $LINENO
	
	eval $__resultvar="'$__output_file_name'"
}

function pd_getworkflowid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow name
    # 4 - workflow id return variable name

	if [[ $# -ne 4 ]]
	then
	  log "pd_getworkflowid: expected 4 arguments, cookiename, podium_url, workflow_name and return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowName="$3"
	local __resultvar=$4

    local __workflow_id=""

	if [[ $verbose ]]
	then
	  log "pd_getworkflowid: cookiename: ${cookiename}, workflowName: ${workflowName}"
	fi

    # To-Do The getWorkflowId call is to be deprecated in
    # Podium 3.2, check documentation
	local api_function="transformation/v1/getWorkflowId"

    cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}?workflowName=${workflowName}'"

	if [[ $verbose ]]
	then
	  log "pd_getworkflowid: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getworkflowid: ${json}"
	fi

	eval $(echo "$json" | gawk '{print gensub(".*\"objectId\":\"([[:digit:]]+)\".*", "__workflow_id=\\1;","g")}')

	log "workflow_id: ${__workflow_id}"

	eval $__resultvar="'$__workflow_id'"
	
}

function pd_getworkflowstatus() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow id
    # 4 - result status variable 
    # 5 - result record count  variable 

    # returns Podium workflow status and recordCount in global variables status and recordcount


	if [[ $# -ne 5 ]]
	then
	  log "pd_getworkflowstatus: expected 5 arguments, cookiename, podium_url, workflow_id, status return variable and record count return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowId="$3"
	local __resultstatusvar=$4
	local __resultcountvar=$5

    local __status=""
	local __recordcount=0

    # To-Do The loadAllWorkOrders call is to be deprecated in
    # Podium 3.2, check documentation
	local api_function="transformation/v1/loadAllWorkOrders/"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${workflowId}?count=1&sortAttr=loadTime&sortDir=DESC'"

    
	if [[ $verbose ]]
	then
	  log "pd_getworkflowstatus: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getworkflowstatus: ${json}"
	fi
	
	eval $(echo "$json" | gawk '{print gensub(".*\"status\":\"([[:alpha:]]+)\".*\"recordCount\":([[:digit:]]+).*", "__status=\\1;__recordcount=\\2","g")}')

    if [[ $verbose ]]
	then
	  log "WorkflowId: ${workflowId}, status: ${__status}, records: ${__recordcount}"
	fi

	eval $__resultstatusvar="'$__status'"
	eval $__resultcountvar="'$__recordcount'"

}

function pd_rptworkflowstatus() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow id
    # 4 - rpt_count

    # Reports Podium workflow status and recordCount

	if [[ $# -ne 4 ]]
	then
	  log "pd_rptworkflowstatus: expected 4 arguments, cookiename, podium_url, workflow_id, rpt_count"
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowId="$3"
	local rptcount=$4

    # To-Do The loadAllWorkOrders call is to be deprecated in
    # Podium 3.2, check documentation
	local api_function="transformation/v1/loadAllWorkOrders/"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${workflowId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC'"
    
	if [[ $verbose ]]
	then
	  log "pd_rptworkflowstatus: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getworkflowstatus: ${json}"
	fi
	
	# echo "$json" | grep -oP '{"id":.*?}' |  gawk '{print gensub(".*\"loadTime\":([[:digit:]]+).*\"status\":\"([[:alpha:]]+)\".*\"recordCount\":([[:digit:]]+).*\"name\":\"([a-zA-Z0-9_]+)\".*", "\\4,\\1,\\2,\\3","g")}' | gawk -F , 'BEGIN {print "name,loadtime,status,records"} {OFS = ",";print $1,strftime("%Y-%m-%d %H:%M:%S",substr($2,1,10)),$3,$4}' 

	echo "$json" | grep -oP '{"id":.*?}'  |  gawk -v hdr="y" -f pd_sh_wf.gawk

}

function pd_rptentitystatus() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - rpt_count

    # Reports Podium entity status and recordCount

	if [[ $# -ne 4 ]]
	then
	  log "pd_rptentitystatus: expected 4 arguments, cookiename, podium_url, entity_id, rpt_count"
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local entityId="$3"
	local rptcount=$4

	local api_function="entity/v1/loadLogs/"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC'"
    
	if [[ $verbose ]]
	then
	  log "pd_rptentitystatus: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getentitystatus: ${json}"
	fi
	
	echo "$json" | grep -oP '{"id":.*?"workorderProp":\[.*?]}' | grep -oP '{"id":.*?"workorderProp":' | gawk -v hdr="y" -f pd_sh_entity.gawk
	# echo "$json" | grep -oP '{"id":.*?}' |  gawk -v hdr="y" -f pd_sh_entity.gawk

}

function pd_dataloadcleanup() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - keep_count

    # Deletes data loads for an entity keeping the last keepcount loads

	if [[ $# -ne 4 ]]
	then
	  log "pd_dataloadcleanup: expected 4 arguments, cookiename, podium_url, entity_id, keep_count"
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local entityId="$3"
	local keepcount="$4"
	local rptcount=500

	local api_function="entity/v1/loadLogs/"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC'"
    
	if [[ $verbose ]]
	then
	  log "pd_rptentitystatus: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getentitystatus: ${json}"
	fi
	
	workorderids=$(echo "$json" | grep -oP '{"id":.*?"workorderProp":\[.*?]}' | grep -oP '{"id":.*?"workorderProp":' | gawk -f pd_sh_entity.gawk | cut -d, -f 1,6 | gawk -F , '/FINISHED/ {print $1}' | gawk -v L=${keepcount} 'NR > L {print $1}')

	#local api_function="entity/deleteDataForLoadLogs/15"
	local api_function="entity/v1/dataLoadCleanUp/15"

	for i in $workorderids
	do
	    cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${i}'"
		log $cmd
	    json=$(eval ${cmd})
	    log "pd_dataloadcleanup: ${json}"
	done

}

function pd_deleteexelogdata() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow id
    # 4 - keep_count

    # Deletes data for workflow execution

	if [[ $# -ne 4 ]]
	then
	  log "pd_deleteexelogdata: expected 4 arguments, cookiename, podium_url, workflow_id, keep_count"
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowId="$3"
	local keepcount="$4"
	local rptcount=500

	local api_function="transformation/v1/loadAllWorkOrders/"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${workflowId}?count=${rptcount}&sortAttr=loadTime&sortDir=DESC'"
    
	if [[ $verbose ]]
	then
	  log "pd_deleteexelogdata: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_deleteexelogdata: ${json}"
	fi
	
	workorderids=$(echo "$json" | grep -oP '{"id":.*?}'  |  gawk -v hdr="n" -f pd_sh_wf.gawk  | cut -d, -f1 | gawk -v L=${keepcount} 'NR > L {print}')

	local api_function="transformation/deleteExeLogData/13"

	for i in $workorderids
	do
	    cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${i}'"
		log $cmd
	    json=$(eval ${cmd})
	    log "pd_dataloadcleanup: ${json}"
	done

}

function pd_loadlogdetail() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - log_id
    # 4 - result status variable 
    # 5 - result record count variable 
    # 6 - result good record count variable 

    # returns Podium load status and recordCount in global variables status and recordcount

	if [[ $# -ne 6 ]]
	then
	  log "pd_loadlogdetail: expected 6 arguments, cookiename, podium_url, log_id, status return variable, record count return variable and good record count variable" >&2
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

	local api_function="entity/v1/loadLogDetail"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${logId}'"
	if [[ $verbose ]]
	then
	  log "pd_loadlogdetail: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_loadlogdetail: ${json}"
	fi
	
	eval $(echo "$json" | gawk '{print gensub(".*\"status\":\"([[:alpha:]]+)\".*\"recordCount\":([[:digit:]]+).*\"goodRecordCount\":([[:digit:]]+).*", "__status=\\1;__recordcount=\\2;__goodrecordcount=\\3","g")}')
	eval $(echo "$json" | gawk '{print gensub(".*\"deliveryId\":\"(.+)\",.*\"infoMessage\".*", "__deliveryid=\\1;","g")}')

    log "pd_loadlogdetail: logId: ${logId}, ${__deliveryid} status: ${__status}, records: ${__recordcount}, goodrecords: ${__goodrecordcount}"

	eval $__resultstatusvar="'$__status'"
	eval $__resultcountvar="'$__recordcount'"
	eval $__resultgoodcountvar="'$__goodrecordcount'"
}

function pd_executeworkflow() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - workflow id
    # 4 - has_param 
    # 5 - engine
    # 6 - return work order id variable name

    # returns Podium work order id

	if [[ $# -ne 6 ]]
	then
	  log "pd_executeworkflow: expected 6 arguments recieved $#, cookiename, podium_url, workflow_id, has_param, engine, variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local workflowId="$3"
	local has_param="$4"
	local engine="$5"
	local __resultvar=$6

	local __workorder_id=0

    if [[ ${has_param} -eq 0 ]]
	then

      # To-Do The execute call is to be deprecated in
      # Podium 3.2, check documentation
	  local api_function="transformation/v1/execute"

	  cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${workflowId}/${engine}'"
      log "pd_executeworkflow: cmd = ${cmd}"

	else

	  local api_function="transformation/v1/executeWithParmas"
      cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${workflowId}/${engine}' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '${params}' -compressed"

	fi
	
    if [[ $verbose ]]
    then
      log "$pdfunc: cmd = ${cmd}" 
    fi

	__workorder_id=$(eval ${cmd})

	if [[ $verbose ]]
	then
	  log "pd_executeworkflow: Returning workorder_id ${__workorder_id}"
	fi

	eval $__resultvar="'$__workorder_id'"
}

function pd_loaddata() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - return workorder id variable name

    # returns Podium workorder_id

    local pdfunc="pd_loaddata"

	if [[ $# -ne 4 ]]
	then
	  log "$pdfunc: expected 4 arguments, cookiename, podium_url, entity_id and return variable name" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local entity_id="$3"
	local __resultvar=$4

    local __workorder_id=0
	local doAsynch="true"

	local api_function="entity/v1/loadDataForEntities"

	loadtime=$(gawk 'BEGIN {print strftime("%FT%T.000Z", systime(),1)}')

    cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${doAsynch}' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '[{\"loadTime\":\"${loadtime}\",\"entityId\":${entity_id}}]' -compressed"

    if [[ $verbose ]]
    then
      log "$pdfunc: cmd = ${cmd}" 
    fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "$pdfunc: json = ${json}"
	fi

    # Returned JSON is a n array of workorder info, but we only start one entity at a 
    # time.
	eval $(echo "$json" | gawk '{print gensub("^..\"id\":([[:digit:]]+).*", "__workorder_id=\\1","g")}') 

	eval $__resultvar="'$__workorder_id'"

}

function pd_checkentity() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source id
	# 4 - entity anme# 
    # 5 - result variable name

    # returns true if entity available or false if not.
    # Note: false is a check that the entity does exist
    # Note: true is a check that the entity does not exist

	local pdfunc="pd_checkentity"

	if [[ $# -ne 5 ]]
	then
	  log "$pdfunc: expected 5 arguments, cookiename, podium_url, sourceid, entity_name, return variable name" 
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourceid="$3"
	local entityname="$4"
	local __resultvar=$5

	local api_function="entity/v1/isAvailable"
	local is_available=""

    cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${sourceid}/${entityname}'"

	if [[ $verbose ]]
	then
	  log "$pdfunc: cmd = ${cmd}"
	fi

	__is_available=$(eval $cmd)

	if [[ $verbose ]]
	then
	  log "$pdfunc: __is_available = ${__is_available}"
	fi

	eval $__resultvar="'$__is_available'"

}

function pd_checksource() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - result variable name

    # returns true if source available or false if not.
    # Note: false is a check that the source does exist
    # Note: true is a check that the source does not exist

	if [[ $# -ne 4 ]]
	then
	  log "pd_checksource: expected 4 arguments, cookiename, podium_url, sourcename, return variable name" 
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local __resultvar=$4

	local api_function="source/v1/isAvailable"

	local is_available=""

    cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${sourcename}'"

# Test code
# 	local api_function="source/v1/getSourcesByCrit"
# 	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/2/${sourcename}'"
#     log ${cmd}
# 	json=$(eval ${cmd})
# 	log $json
# 	eval $(echo "$json" | gawk '{print gensub(".*\"fullListSize\":([[:digit:]]+),.*","__listsize=\\1","g")}')
# 
#     if [[ $verbose ]]
# 	then
# 	  log "${__listsize} Sources found that match ${sourcename}"
# 	fi
# 
# 	if [[ ${__listsize} -eq 0 ]]
# 	then
# 	   log "No Source found that matches the name ${sourcename}"
# 	   exit 1
# 	fi
# 
#     # Build a sourcename array from the returned source list
#     eval $(echo $json | grep --only-matching --perl-regexp '{"id":.*?}' | grep --only-matching --perl-regexp '"name":".*?"' | gawk -F : {'printf "sourcenames[%d]=%s;", NR, $2}')
# 
# 	for s in ${sourcenames[@]}
# 	do
# 	  echo $s
#       if [[ $s == $sourcename ]]
# 	  then
# 	    log "${sourcename} found"
# 		break
# 	  fi
# 	done
# 
# 	exit 1
# End test code

	if [[ $verbose ]]
	then
	  log "pd_checksource: cmd = ${cmd}"
	fi

	__is_available=$(eval $cmd)

	eval $__resultvar="'$__is_available'"
}

function pd_getsources() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - result variable name

    # returns array, index is source id, value is source name

	local pdfunc="pd_getsources"

	if [[ $# -ne 3 ]]
	then
	  log "${pdfunc}: expected 3 arguments, cookiename, podium_url, return variable name" 
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local __resultvar=$3

	local api_function="source/v1/getSources"

    cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}'"

	if [[ $verbose ]]
	then
	  log "${pdfunc}: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
    then
	  log $json
	fi

	unset __pdsrc
	declare -a __pdsrc
	
    # Remove the subList wrapping, turn each source {} into a record and parse out in gawk
    # result is the array pdsrc, the indexes are the src id and the value the src name

	eval $(echo ${json} | sed -r -e 's/\{"subList":\[//' -e 's/\].*//' -e 's/\},\{/\}\n\{/g' | gawk 'BEGIN {ORS=";"} {print gensub(".*\"id\":([[:digit:]]+),.*\"name\":\"([a-zA-Z0-9_]+)\".*", "__pdsrc[\\1]=\"\\2\"", "g")}')

    if [[ $verbose ]]
	then
	  log "$pdfunc: returning ${#__pdsrc[@]} sources - ${!__pdsrc[*]}, ${__pdsrc[@]}"
	fi
  
    # returning an array where the index is the src id and the
    # value is the src name
    for s in ${!__pdsrc[@]}
	do
	  eval $__resultvar[$s]="'${__pdsrc[$s]}'"
	done
}

function pd_getsourceid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - return variable name

    # returns source_id


	if [[ $# -ne 4 ]]
	then
	  log "pd_loadlogdetail: expected 4 arguments, cookiename, podium_url, source_name, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local __returnvar=$4

    local __source_id=0
	local api_function="source/v1/getSourcesByCrit"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}?name=${sourcename}'"

    if [[ $verbose ]]
	then
	  log "pd_getsourceid: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
    then
	  log $json
	fi

	eval $(echo "$json" | gawk '{print gensub("^..\"id\":([[:digit:]]+).*", "__source_id=\\1","g")}') 

	eval $__returnvar="'$__source_id'"

}

function pd_getentityid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - source name
    # 4 - entity name
    # 5 - return variable name


	if [[ $# -ne 5 ]]
	then
	  log "pd_getentityid: expected 5 arguments, cookiename, podium_url, source_name, entity_name, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local sourcename="$3"
	local entityname="$4"
	local __returnvar=$5

    local __entity_id=0
	local api_function="entity/v1/getEntitiesByCrit"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}?srcName=${sourcename}&entityName=${entityname}'"
  
    if [[ $verbose ]]
	then
	  log "pd_getentityid: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getentityid: ${json}"
	fi
	
	eval $(echo "$json" | gawk '{print gensub("^..\"id\":([[:digit:]]+).*", "__entity_id=\\1","g")}') 

    if [[ $verbose ]]
	then
	  log "pd_getentityid: return - Source: ${sourcename}, Entity: ${entityname}, nid: ${__entity_id}"
	fi

	eval $__returnvar="'$__entity_id'"

}

function pd_getentityproperty() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - entity id
    # 4 - property name
    # 5 - return variable name


	if [[ $# -ne 5 ]]
	then
	  log "pd_getentityproperty: expected 5 arguments, cookiename, podium_url, entity_id, property name, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local entityid="$3"
	local propertyname="$4"
	local __returnvar=$5

    local __property_value=""

	local api_function="entity/v1/getProperty"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}/${entityid}/${propertyname}'"
  
    if [[ $verbose ]]
	then
	  log "pd_getentityproperty: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "pd_getentityproperty: ${json}"
	fi

	eval "__property_value=${json}"

    if [[ $verbose ]]
	then
	  log "pd_getentityproperty: return - nid: ${entityid}, property: ${propertyname} value: ${__property_value}"
	fi

	eval $__returnvar="'$__property_value'"

}

function pd_getjobs() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - return variable name an array of jobs, index is job_id, value is job_name

    pdfunc="pd_getjobs"

	if [[ $# -ne 3 ]]
	then
	  log "$pdfunc: expected 3 arguments, cookiename, podium_url, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local __returnvar=$3

	local api_function="publish/v1/getJobs"

	cmd="curl -s -b ${cookiename} -X GET '${podium_url}/${api_function}'"
  
    if [[ $verbose ]]
	then
	  log "$pdfunc: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "$pdfunc: ${json}"
	fi

	unset __pdjob
	declare -a __pdjob 
	
    # Remove the subList wrapping, turn each job {} into a record and parse out in gawk
    # result is the array pdjob, the indexes are the job id and the value the job name

	eval $(echo ${json} | sed -r -e 's/\{"subList":\[//' -e 's/\].*//' -e 's/\},\{/\}\n\{/g' | gawk 'BEGIN {ORS=";"} {print gensub(".*\"id\":([[:digit:]]+),.*\"name\":\"([a-zA-Z0-9_]+)\".*", "__pdjob[\\1]=\"\\2\"", "g")}')

    if [[ $verbose ]]
	then
	  log "$pdfunc: returning ${#__pdjob[@]} jobs - ${!__pdjob[*]}, ${__pdjob[@]}"
	fi
  
    # returning an array where the index is the job id and the
    # value is the job name
    for j in ${!__pdjob[@]}
	do
	  eval $__returnvar[$j]="'${__pdjob[$j]}'"
	done
}

function pd_getjobid() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - job name
    # 4 - return variable name

    pdfunc="pd_getjobid"

	if [[ $# -ne 4 ]]
	then
	  log "$pdfunc: expected 4 arguments, cookiename, podium_url, jobname, return variable" >&2
	  log "$pdfunc: recieved |$@|" >&2
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

    if [[ $verbose ]]
	then
	  log "$pdfunc: returning - ${__job_id}, ${output_job_list[${__job_id}]}"
	fi

    unset output_job_list

	eval $__returnvar="'$__job_id'"

}

function pd_schedule() {

    # Expected args
    # 1 - cookiename
    # 2 - podium url
    # 3 - job id
    # 4 - return variable name

    pdfunc="pd_schedule"

	if [[ $# -ne 4 ]]
	then
	  log "$pdfunc: expected 4 arguments, cookiename, podium_url, jobid, return variable" >&2
	  exit 1
	fi

    local cookiename="$1"
	local podium_url="$2"
	local jobid="$3"
	local __returnvar=$4

	local api_function="publish/v1/schedule"

	cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/${api_function}/${jobid}'"
  
    if [[ $verbose ]]
	then
	  log "$pdfunc: cmd = ${cmd}"
	fi

	json=$(eval ${cmd})
	
	if [[ $verbose ]]
	then
	  log "$pdfunc: ${json}"
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
	curl -j -b ${cookiename} "${podium_url}"
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

while getopts ":ixhavrkfc:e:w:j:s:m:y:p:t:" opt
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
	x  ) is_export=1
	     ;;
	i  ) is_import=1
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

if [[ $verbose ]]
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
    if [[ $verbose ]]
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
log_file=${default_log_file:-"pd_load.log"}
engine=${engine:-$default_engine}
rpt_count=${rpt_count:-5}

# #######################
# Establish Podium Sesssion
# #######################
pd_login $podium_user $podium_pw $podium_url cookiename

if [[ $about ]]
then
  pd_about ${cookiename} ${podium_url} podium_release
  log "Podium release is ${podium_release}"
fi

# #######################
# Validate options     
# #######################

# Must specify operation
if ! [[ ${is_source} -eq 1 || ${is_entity} -eq 1 || ${is_workflow} -eq 1 || ${is_export} -eq 1 || ${is_import} -eq 1 || ${is_job} -eq 1 ]]
then
  log "Need one of -s, -e, -w, -i, -x or -j options" >&2
  exit 1
fi

if [[ ${is_entity} -eq 1 && ${is_workflow} -eq 1 ]]
then
  log "Specify -e OR -w option, not both" >&2
  exit 1
fi

# If load then must have a source
if [[ ${is_entity} -eq 1 && -z "$podium_source" ]]
then
	log "No source set for entities" >&2
	exit 1
fi

# If entity operation then check that the source is a valid source
if [[ $podium_source ]]
then
   if [[ $podium_source == "?" ]]
   then
      pd_getsources ${cookiename} ${podium_url} output_source_list
	 
	  for s in ${!output_source_list[@]}
	  do
	    printf "Id: %5d, Name: %s\n" $s ${output_source_list[$s]}
      done
      exit
   fi

   pd_checksource ${cookiename} ${podium_url} ${podium_source} source_is_available
   if [[ $source_is_available == "true" ]]
   then
     log "${podium_source} is not a valid source"
     exit 1
   fi
fi

if [[ $is_entity -eq 1 ]]
then
  pd_getsourceid ${cookiename} ${podium_url} ${podium_source} source_id
  if [[ $verbose ]]
  then
    log "${podium_source} is id ${source_id}"
  fi
fi

if [[ $is_export -eq 1 && $is_import -eq 1 ]]
then
   log "Cannot specify both export -x and import -i options"
   exit 1
fi

if [[ $verbose ]]
then
  log "Queue = ${run_que[@]}"
fi

if [[ $is_entity -eq 1 ]]
then
   # check list of supplied entity names is valid
   for e in ${run_que[*]}
   do
	   pd_checkentity ${cookiename} ${podium_url} ${source_id} $e entity_is_available
	   if [[ $entity_is_available == "true" ]]
	   then
	     log "${podium_source} entity $e, is not valid"
		 exit 1
	   fi
   done
fi

# ################################
# Export
# ################################

if [[ $is_export -eq 1 ]]
then

  # Validate that an object type given
  if [[ $((is_entity + is_source + is_workflow)) -eq 0 ]]
  then
     log "One of source, entity or workflow must be specified with export"
	 exit 1
  fi
 
  # If entity check source given
  if [[ $is_source -eq 0 && $is_entity -eq 1 ]]
  then
    log "A source must be given if exporting an entity"
	exit 1
  fi

  if [[ $(($is_source + $is_entity)) -gt 0 && $is_workflow -eq 1 ]]
  then
    log "Cannot mix source/entity and workflows in an export"
	exit 1
  fi

  if [[ $is_source -eq 1 && $is_entity -eq 0 ]]
  then
     pd_exportsource ${cookiename} ${podium_url} ${podium_source} output_file_name
     log "Source ${podium_source} exported to file ${output_file_name}"   
     exit
  fi

  if [[ $is_entity -eq 1 ]]
  then
     for e in ${run_que[*]}
     do
       pd_exportentity ${cookiename} ${podium_url} ${podium_source} ${e} output_file_name
       log "Entity ${podium_source}.${e} exported to file ${output_file_name}"   
     done
     exit
  fi

  if [[ $is_workflow -eq 1 ]]
  then
     for w in ${run_que[*]}
     do
       pd_exportworkflow ${cookiename} ${podium_url} ${w} output_file_name
       log "Workflow ${w} exported to file ${output_file_name}"   
     done
     exit
  fi
fi

# ################################
# Import
# ################################

if [[ $is_import -eq 1 ]]
then
  
  # Validate that an object type given
  if [[ $((is_entity + is_source + is_workflow)) -eq 0 ]]
  then
     log "One of source, entity or workflow must be specified with import"
	 exit 1
  fi

  # Validate that only one object type given
  if [[ $((is_entity + is_source + is_workflow)) -gt 1 ]]
  then
     log "Only one of source, entity or workflow to be specified with import"
	 exit 1
  fi

  # Set object type
  if [[ $is_source -eq 1 ]]
  then
     $podium_object_type="Sources"
  elif [[ $is_entity -eq 1 ]]
  then
     $podium_object_type="Entities"
  elif [[ $is_workflow -eq 1 ]]
  then
     $podium_object_type="Workflows"
  else
     log "Import object error"
	 exit 1
  fi

  pd_import ${cookiename} ${podium_url} ${podium_object_type} ${import_file_name} output_status

  log "Import status ${output_status}"   
  exit

fi

# ################################
#  Run publish job or job list
# ################################
if [[ $is_job -eq 1 ]]
then
   if [[ $verbose ]]
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

if [[ $is_entity -eq 1 ]]
then
  if [[ $is_report -eq 1 ]]
  then	  
    log "Reporting on entities"
	max_jobs=1
	refresh_interval=1
  elif [[ $is_klean -eq 1 ]]
  then
    log "Performing data load clean up"
	max_jobs=1
	refresh_interval=1
  else
    log "Processing entities for podium_source: ${podium_source}, maximum concurrent jobs ${max_jobs}, ${job_count} entities, refesh interval ${refresh_interval}"
  fi
fi

if [[ $is_workflow -eq 1 ]]
then
  if [[ $is_report -eq 1 ]]
  then	  
    log "Reporting on workflows"
	max_jobs=1
	refresh_interval=1
  elif [[ $is_klean -eq 1 ]]
  then
    log "Performing dataflow clean up"
	max_jobs=1
	refresh_interval=1
  else
    log "Executing workflows, maximum concurrent jobs ${max_jobs}, ${job_count} jobs, refesh interval ${refresh_interval}"
  fi
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

	if [[ ${is_entity} -eq 1 ]]
	then

	  pd_getentityid ${cookiename} ${podium_url} ${podium_source} ${object_name} entity_id

	  if [[ $entity_id -eq 0 ]]
	  then
	  
	    log "Entity ${podium_source}.${object_name} not found"
		exit 1

	  else

		if [[ $is_report -eq 1 ]]
		then
		  pd_rptentitystatus ${cookiename} ${podium_url} ${entity_id} $rpt_count
		  job_id=0
		elif [[ $is_klean -eq 1 ]]
		then
		  pd_getentityproperty ${cookiename} ${podium_url} ${entity_id} "entity.base.type" base_type

		  log "Entity: ${object_name} is a ${base_type}"

		  if [[ ${base_type} == "Snapshot" ]]
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

	elif [[ ${is_workflow} -eq 1 ]]  
	then

	  workflow_name=$object_name

      pd_getworkflowid ${cookiename} ${podium_url} ${workflow_name} workflow_id

	  if [[ $workflow_id -eq 0 ]]
	  then 
	    log "Workflow: ${workflow_name}, not found"
        let "index = $index + 1"
		continue
	  else
		if [[ $is_report -eq 1 ]]
		then
		  pd_rptworkflowstatus ${cookiename} ${podium_url} ${workflow_id} $rpt_count
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

		  if [[ $verbose ]]
		  then
		    log "Inspecting job ${job_id}"
		  fi

          if [[ $is_entity -eq 1 ]]
		  then
			pd_loadlogdetail ${cookiename} ${podium_url} ${job_id} status recordcount goodrecordcount
		  fi

		  if [[ $is_workflow -eq 1 ]]
		  then
		    pd_getworkflowstatus ${cookiename} ${podium_url} ${job_id} status recordcount
		  fi

		  if [ "$status" = "FINISHED" ]
		  then
		    let "finished_count = $finished_count + 1"
			if [[ $is_entity -eq 1 ]]
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
		  elif [ "$status" = "FAILED" ]
		  then
		    if [[ $is_entity -eq 1 ]]
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
			if [[ $is_entity -eq 1 ]]
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

  if [[ $is_entity -eq 1 ]]
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

    if [[ $is_entity -eq 1 ]]
    then
      pd_loadlogdetail ${cookiename} ${podium_url} ${job_id} status recordcount goodrecordcount
	 fi
		  
    if [[ $is_workflow -eq 1 ]]
    then
      pd_getworkflowstatus ${cookiename} ${podium_url} ${job_id} status recordcount
    fi

    log "${job_id} - ${object_ref[${job_id}]} ${status}"

    case ${status} in
       FINISHED | FAILED* | TERMINATED*) 
         log "${job_id} ${object_ref[$job_id]} is ${status}, ${recordcount} records"
         unset running[$running_index]
         ;;
       *)
	      sleep ${refresh_interval}
         ;;
    esac


    #if [ "${status}" == "FINISHED" ]
    #then
    #  log "${job_id} ${object_ref[$job_id]} is finished, ${recordcount} records"
    #  unset running[$running_index]
	 #else
	 # sleep ${refresh_interval}
    # fi

    let "running_index = $running_index + 1"

  done
  running=("${running[@]}")
  running_count=${#running[@]}
done

pd_logout "${cookiename}" "${podium_url}"
rm ${cookiename}
log "Done"
