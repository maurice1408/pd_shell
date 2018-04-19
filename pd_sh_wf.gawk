BEGIN {
	if (hdr=="y")
	{	
	  print "id,name,status,starttime,endtime,loadtime,recordcount"
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

{
	# id = gensub(".*\"id\":([[:digit:]]+),.*","\\1","n")
	id = extract_num($0, "id")
	# name = gensub(".*\"name\":\"([a-zA-Z0-9_]+)\",.*","\"\\1\"","n")
	name = extract_str($0, "name")
	# status = gensub(".*\"status\":\"([a-zA-Z_]+)\",.*","\"\\1\"","n")
	status = extract_str($0, "status")
	# loadTime = gensub(".*\"loadTime\":([[:digit:]]+),.*","\\1","n")
	loadTime = extract_num($0, "loadTime")
	# startTime = gensub(".*\"startTime\":([[:digit:]]+),.*","\\1","n")
	startTime = extract_num($0, "startTime")
	# endTime = gensub(".*\"endTime\":([[:digit:]]+),.*","\\1","n")
	endTime = extract_num($0, "endTime")
	# recordCount = gensub(".*\"recordCount\":([[:digit:]]+),.*","\\1","n")
	recordCount = extract_num($0, "recordCount")

	strendTime = strftime(otf, substr(endTime,1,10))

	if (substr(strendTime,1,4) == "1969") strendTime = ""

	print id, name, status, strftime(otf, substr(startTime,1,10)), strendTime ,strftime(otf, substr(loadTime,1,10)), recordCount
}
