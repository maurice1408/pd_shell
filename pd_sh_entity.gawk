BEGIN {
	if (hdr=="y")
	{	
	  print "id,srcid,srcname,entityid,entityname,status,starttime,endtime,loadtime,recordcount,good,bad,ugly,chaff"
	}
	otf = "%Y-%m-%d %H:%M:%S"
	OFS = ","
}

function extract_num(json, field_name) {
	pat = ".*\"" field_name "\":([[:digit:]]+),.*"
	# print pat
	result = gensub(pat,"\\1","n")
	return result
}

function extract_str(json, field_name) {
	pat = ".*\"" field_name "\":\"([a-zA-Z0-9_]+)\",.*"
	# print pat
	result = gensub(pat,"\\1","n")
	return "\"" result "\""
}

/loadTimeInMillis/ {
	id = extract_num($0, "id")
	srcid = extract_num($0, "sourceId")
	sourcename = extract_str($0, "sourceName")
	entityid = extract_num($0, "entityId")
	entityname = extract_str($0, "entityName")
	status = extract_str($0, "status")
	loadTime = extract_num($0, "loadTime")
	startTime = extract_num($0, "startTime")
	endTime = extract_num($0, "endTime")
	recordCount = extract_num($0, "recordCount")
	good = extract_num($0, "goodRecordCount")
	bad = extract_num($0, "badRecordCount")
	ugly = extract_num($0, "uglyRecordCount")
	chaff = extract_num($0, "chaffRecordCount")

	strendTime = strftime(otf, substr(endTime,1,10))

	if (substr(strendTime,1,4) == "1969") strendTime = ""

	print id, srcid, sourcename, entityid, entityname, status , strftime(otf, substr(startTime,1,10)), strendTime ,strftime(otf, substr(loadTime,1,10)), recordCount, good, bad, ugly, chaff
}
