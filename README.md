# pd_shell - a QDC Command Line Shell

## Description

`pd_shell.sh` is a (bash) command line shell that supports the following actions:

* View info about your QDC system
* Execute a Load Data request for a Source / Entity
* Execute a dataflow
* Report on executed ingests / dataflows
* Export / Import QDC objects
* Clean (delete) ingest and dataflow execution logs.

`pd_shell` uses the QDC REST API to communicate with your QDC system.

All API calls are via cURL the QDC Java based command line utility (CLU)
is not used.

The complete documentation for `pd_shell` is "work in
progress" so the most common `pd_shell` operations are
documented in this README in the form of examples. Some
features of `pd_shell` e.g. execute a publish job, will be
documented in the next commit.

## Installation

Clone this github repository and copy the files to a suitable directory
on your edge node or any suitable Linux platform.

Files:

```
pd_shell.sh
pd_func_lib.sh
pd_dev.yml
```

### QDC Support

This version of `pd_shell` supports QDC Release 4.0.x and above.

### Changes in this release

Parsing of the JSON returned by the QDC REST API is now via the
excellent `jq` command line JSON processor.

No external awk files are now used for JSON parsing.

`jq` must be installed from the github site
[jq](https://stedolan.github.io/jq/). 

After installation of the version of `jq` appropriate for your system
then specify the location of the `jq` executable in the yaml confuration
file used when executing `pd_shell`.

When `pd_shell` is run with the `-v` (verbose) option then output from
API calls is saved to a file and then dumped using `jq`. This can be
useful for exploring the responses given by the REST API, but will
potentially produce a lot of output files!

## Configuration

Configuration parameters to `pd_shell` are supplied via a `yaml` file.

The location of the config `yaml` file is given using the `-y` option
of `pd_shell`.

A typical `pd_shell` config file may be something like:

```yaml
podium:
  user:    "youruser"
  pw:      "yourpwd" 
  url:     "http://yoururl:9080/podium"

default:
  max_jobs: 4
  refresh_interval: 10
  log_file: "pd.log"
  engine: "TEZ"

json:
  parse: "jq"

jq:
  exec: "./jq-win64.exe"
  style: "--color-output --compact-output"

hive:
  connect: "jdbc:hive2://yourhive:10000/default;principal=hive/yourhiveprincipal"
```

Note: The password supplied in the
yaml file may be the encrypted form as generated by the
QDC Encryption Utility. See the QDC CLU document for
details on running the Encryption Utility.

Multiple config files can  be created to reflect your multiple, dev / QA / prod
QDC systems.

The `podium`, `default`, `json` and `jq` sections are mandatory. 

Table: Podium Config

| Parameter | Description                               |
| --------- | ----------------------------------------- |
| user      | QDC login user id                      |
| pwd       | password for QDC user (unencrypted)    |
| url       | QDC URL                                |

Table: `pd_shell` defaults

| Parameter | Description                               |
| --------- | ----------------------------------------- |
| `max_jobs`  | The maximum number of ingest / dataflows executed concurrently by `pd_shell`       |
| `refresh_interval` | time in sec between `pd_shell` progress msgs |
| `log_file`  | logfile name written by `pd_shell`        |
| `engine`    | Default engine used to execute dataflows  |

Table: jq Config

| Parameter | Description                               |
| --------- | ----------------------------------------- |
| exec      | Location of the `jq` executable        |
| style     | `jq` style used when `jq` dumps JSON,  |
|           | see the `jq` documentation for details |

## Examples

### About (-a)

The `about` option may be used to retrieve information about your
QDC environment and also check that `pd_shell` can connect to your
QDC system.

```bash
./pd_shell.sh -y pd_dev.yml -a
Version:   3.1.0
Build:     5433
Schema:    143
Expiry:    2020-06-30
```

### Execute a Data Load (-s -e)

```bash
./pd_shell.sh -y pd_dev.yml -s sourcename -e entityname
```

Will initiate a data load for the named source / entity.

`sourcename` must be a single QDC Source name.

`entityname` can be a single unquoted QDC Entity name or a
quoted list of Entity names e.g. "ent1 ent2 ent3" etc.

Note: `sourcename` and `entityname` are not case sensitive.

If a quoted list of Entity names is given `pd_shell` will execute up to
`max_jobs` loads concurrently, picking the next Entity from the list as
each load completes until the list is exhausted.

`pd_shell` will report on the data load status every `refresh_interval` seconds
until complete.

```
:~ ./pd_shell.sh -y pd_dev.yml -s XXX_SRC -e activity_type_t

2018-04-19 08:58:10 - 1 tasks on queue
2018-04-19 08:58:10 - Processing entities for QDC_source: XXX_SRC, maximum concurrent jobs 4, 1 entities, refesh interval 10
2018-04-19 08:58:10 - Index : 0
2018-04-19 08:58:10 - 0 jobs running
2018-04-19 08:58:11 - 133659 activity_type_t started
2018-04-19 08:58:21 - Entity Loads: 133659
2018-04-19 08:58:21 - 1 jobs still running
2018-04-19 08:58:21 - pd_loadlogdetail: logId: 133659, XXX_SRC.activity_type_t.20180419085810 status: RUNNING, records: 0, goodrecords: 0
2018-04-19 08:58:21 - 133659 - activity_type_t RUNNING
2018-04-19 08:58:31 - 1 jobs still running
...
2018-04-19 08:59:11 - pd_loadlogdetail: logId: 133659, XXX_SRC.activity_type_t.20180419085810 status: RUNNING, records: 92, goodrecords: 92
2018-04-19 08:59:11 - 133659 - activity_type_t RUNNING
2018-04-19 08:59:21 - 1 jobs still running
2018-04-19 08:59:21 - pd_loadlogdetail: logId: 133659, XXX_SRC.activity_type_t.20180419085810 status: FINISHED, records: 92, goodrecords: 92
2018-04-19 08:59:21 - 133659 - activity_type_t FINISHED
2018-04-19 08:59:21 - 133659 activity_type_t is finished, 92 records
2018-04-19 08:59:21 - Done
```

### Report on a Data Load (-r -c -s -e)

```bash
./pd_shell.sh -y pd_dev.yml -r -c 5 -s sourcename -e entityname
```

Will report on the status of the last 5 data loads for the named Source / Entity.

```
je70@SUNLIFEHDPTEST-:~ ./pd_shell.sh -y pd_dev.yml -r -c 5 -s XXX_SRC -e activity_type_t
2018-04-19 09:08:54 - 1 tasks on queue
2018-04-19 09:08:54 - Reporting on entities
2018-04-19 09:08:54 - Index : 0
2018-04-19 09:08:54 - 0 jobs running
id,srcid,srcname,entityid,entityname,status,starttime,endtime,loadtime,recordcount,good,bad,ugly,chaff
133659,163,"XXX_SRC",10826,"activity_type_t","FINISHED",2018-04-19 08:58:11,2018-04-19 08:59:12,2018-04-19 08:58:10,92,92,0,0,0
93709,163,"XXX_SRC",10826,"activity_type_t","FINISHED",2017-05-23 15:22:39,2017-05-23 15:24:11,2017-05-23 15:22:39,84,84,0,0,0
2018-04-19 09:08:56 - Entity Loads:
2018-04-19 09:08:56 - Done
```

### Execute dataflow(s) (-w)

```bash
./pd_shell.sh -y pd_dev.yml -w dataflowname
```

Will execute the named dataflow using the `default:engine` engine.

`default:engine` may be overridden using the `-t` option (TEZ/MAPREDUCE).

`dataflowname` can be a single unquoted QDC dataflow name or a
quoted list of dataflowname names e.g. "wf1 wf2 wf33" etc.

If a quoted list of dataflow names is given `pd_shell` will execute up to
`max_jobs` dataflows concurrently, picking the next dataflow from the list as
each dataflow completes until the list is exhausted.

`max_jobs` may be overridden using the `-m` option.

`pd_shell` will report on the dataflow status every `refresh_interval` seconds
until complete.

### Report on a dataflow (-r -c -w)

```bash
./pd_shell.sh -y pd_dev.yml -r -c 5 -w dataflowname
```

Will report on the status of the last 5 dataflow executions for the named dataflow.

```
:~ ./pd_shell.sh -y pd_dev.yml -r -c 5 -w workflowname
2018-04-19 09:16:11 - 1 tasks on queue
2018-04-19 09:16:11 - Reporting on workflows
2018-04-19 09:16:11 - Index : 0
2018-04-19 09:16:11 - 0 jobs running
2018-04-19 09:16:12 - workflow_id: 33640
id,name,status,starttime,endtime,loadtime,recordcount
20524,"workflowname","FINISHED",2018-04-18 10:44:08,2018-04-18 10:50:12,2018-04-18 10:44:08,67402
20449,"workflowname","FINISHED",2018-04-17 13:21:36,2018-04-17 13:27:43,2018-04-17 13:21:35,67342
20370,"workflowname","FINISHED",2018-04-14 13:03:13,2018-04-14 13:08:10,2018-04-14 13:03:12,67278
20225,"workflowname","FINISHED",2018-04-12 06:29:58,2018-04-12 06:35:49,2018-04-12 06:29:57,67219
20176,"workflowname","FINISHED",2018-04-11 07:03:55,2018-04-11 07:09:24,2018-04-11 07:03:54,67194
2018-04-19 09:16:13 - Workflows Running:
2018-04-19 09:16:13 - Done
```

### Export (-x)

The `pd_shell` export / import can be used for producing backups or
promoting objects between QDC environments. Even driving promotion
through venerable old makefiles!

Export will create an export zip file with the name:

For a source:

```
source_<source_name>_<source_nid>_YYYYMMDDTHHMMSS<TZ>.zip
```

e.g. 

```
2019-11-02 13:06:24 - Source xxx_pr exported to file source_xxx_pr_2_20191102T130616GMTST.zip
```

For a source/entity:

```
entity_<source_name>_<entity_name>_<entity_nid>_YYYYMMDDTHHMMSS<TZ>.zip
```

e.g. 

```
2019-11-02 13:07:03 - Entity xxx_pr.address_type_t exported to file entity_xxx_pr_address_type_t_1_20191102T130659GMTST.zip
```

For a dataflow:

```
dataflow_<dataflow_name>_<dataflow_nid>_YYYYMMDDTHHMMSS<TZ>.zip
```

e.g. 

```
2019-11-02 13:07:36 - Dataflow prod_stg_gcs_member_staging_t exported to file dataflow_prod_stg_gcs_member_staging_t_8849_20191102T130731GMTST.zip
```

#### Example - Export a complete Source

```
:~ ./pd_shell.sh -y pd_dev.yml -x -s XXX_SRC

```

#### Example - Export a Source / Entity

```
:~ ./pd_shell.sh -y pd_dev.yml -x -s XXX_SRC -e activity_type_t

```

#### Example - Export a Dataflow

```
./pd_shell.sh -y pd_dev.yml -x -w dataflowname
```


### Import (-x)

Import a source, source/entity, dataflow using the `-i` option,

Source:

```
./pd_shell.sh -y pd_dev.yml -i -s source_export.zip
```

Source/Entity:

```
./pd_shell.sh -y pd_dev.yml -i -s <source_name> -e source_entity_export.zip
```

Dataflow:

```
./pd_shell.sh -y pd_dev.yml -i -w dataflow_export.zip
```

The output from an import is always displayed back to the terminal
allowing easy inspection of the outcome.

e.g.

```
[13:21:21 pd_shell] ./pd_shell.sh -y pd_aws_qar.yml -i -w dataflow_prod_stg_gcs_member_staging_t_8849_20191102T130731GMTST.zip
```

```json
{
  "GWR_PR.stg_gcs_employee_address_t": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  },
  "GWR_PR.stg_gcs_employee_t": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  },
  "US_Derived": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  },
  "US_Derived.stg_GCS_Member_Address_Grouping_Results_t": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  },
  "prod_stg_GCS_Member_Staging_T": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  },
  "US_Derived.stg_GCS_Member_Staging_T": {
    "objectType": "",
    "objectId": "",
    "name": "",
    "message": "Saved.",
    "status": "SUCCEEDED"
  }
}
```

```bash
2019-11-02 13:22:15 - Import status: dataflow_prod_stg_gcs_member_staging_t_8849_20191102T130731GMTST.zip - "FINISHED"
```

#### View a dataflow Pig Script (-g -w)

To view the dataflow Pig script that would be submitted by QDC use the
-g -w options. This can be useful for taking QDC generated snippets and
testing them in Pig grunt.

```
./pd_shell.sh -y pd_dev.yml -g -w dataflowname
```

e.g.

```
[13:29:37 pd_shell] ./pd_shell.sh -y pd_dev.yml -g -w je70_test_df
2019-11-02 13:30:03 - Dataflow: je70_test_df, objectId: 9207, __df_id_num: 9207
```

```pig

-- podium data script generator prologue
-- begin script for com.nvs.core.model.prepare.pkg.Loader (id:9209)

pdpg_11635 = LOAD 's3a://slf-us-nv-qar-edl-hive/datacatalyst/receiving/GWR_PR/address_type_t/20191021140440/empty'  AS (addr_typ_cd:chararray,addr_typ_dsc:chararray,last_updt_dtm:chararray,last_updt_user_id:chararray);

-- end script for com.nvs.core.model.prepare.pkg.Loader (id:9209)

-- begin script for com.nvs.core.model.prepare.pkg.Transformer (id:9208)

pdpg_11634 = FOREACH pdpg_11635 GENERATE (chararray) addr_typ_cd AS addr_typ_cd,(chararray) addr_typ_dsc AS addr_typ_dsc,(chararray) last_updt_dtm AS last_updt_dtm,(chararray) last_updt_user_id AS last_updt_user_id;

-- end script for com.nvs.core.model.prepare.pkg.Transformer (id:9208)

-- begin script for com.nvs.core.model.prepare.pkg.Filter (id:9269)

pdpg_11733 = FILTER pdpg_11634 BY ((1 == 0 ? true : false));

-- end script for com.nvs.core.model.prepare.pkg.Filter (id:9269)

-- begin script for com.nvs.core.model.prepare.pkg.Store (id:9210)

STORE pdpg_11733 INTO 's3a://slf-us-nv-qar-edl-hive/datacatalyst/receiving/US_Derived/je70_test_address_type_t/20191102133003/good' ;

-- end script for com.nvs.core.model.prepare.pkg.Store (id:9210)

-- podium data script generator epilogue
```

### Clean (delete) Historical Data Loads and dataflow Executions (-k)

QDC keeps every version of data for a data load or dataflow execution.

This can lead to a rapid consumption of space in the Hadoop file system.

`pd_shell` through the use of the -k option will trim the number of
versions being retained. 

#### Clean Data Load History

```bash
./pd_shell.sh -y pd_dev.yml -k -c 5 -s sourcename -e entityname
```

Will delete load logs, profile data, HDFS contents and Hive partitions
for the named Source / Entity, retaining the last 5 most recent FINISHED
data loads.

Note: FAILED loads are _not_ deleted.

Note: This will only work against snapshots not incremental data loads.

`entityname` may be a single unquoted name or a quoted list of entity names.

#### Clean dataflow Execution History

```bash
./pd_shell.sh -y pd_dev.yml -k -c 5 -w dataflowname
```

Will delete load logs,  HDFS contents and Hive partitions for the named
dataflow, retaining the last 5 most recent FINISHED executions.

## Verbose Output (-v)

Specifying the -v option on any `pd_shell` operation will display
extended information including the cURL command sent to QDC and the
returned JSON.

## License

Please note the MIT license on `pd_shell`

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
