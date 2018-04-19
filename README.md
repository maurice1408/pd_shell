# pd_shell - a Podium Command Line Shell

## Description

`pd_shell.sh` is a (bash) command line shell that supports the following actions:

* View info about your Podium system
* Execute a Load Data request for a Source / Entity
* Execute a Workflow
* Report on executed ingests / workflows
* Export / Import Podium objects

NOTE: `pd_shell` does not yet support Podium Release 3.2+ (support due 05/2018).

`pd_shell` uses the Podium REST API to communicate with your Podium system.

All API calls are via cURL the Podium Java based command line utility (CLU)
is not used.

The complete documentation for `pd_shell` is "work in progress" so the most
common `pd_shell` operations are documented in this README in the form of 
examples.

## Installation

Clone this github repository and copy the *sh and *gawk files to
a suitable directory on your edge node or any suitable Linux platform.

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

hive:
  connect: "jdbc:hive2://yourhive:10000/default;principal=hive/yourhiveprincipal"
```

Multiple config files can  be created to reflect your multiple, dev / QA / prod
Podium systems.

The `podium` and `default` sections are mandatory. 

Table: Podium Config

| Parameter | Description                               |
| --------- | ----------------------------------------- |
| user      | Podium login user id                      |
| pwd       | password for Podium user (unencrypted)    |
| url       | Podium URL                                |

Table: `pd_shell` defaults

| Parameter | Description                               |
| --------- | ----------------------------------------- |
| max_jobs  | The maximum number of ingest / workflows  |
|           | executed concurrently by `pd_shell`       |
| refresh_interval | time in sec between `pd_shell` msgs |
| log_file  | logfile name written by `pd_shell`        |
| engine    | Defalut engine used to execute workflows  |

## Examples

### About (-a)

The about option may be used to retrieve information about your
Podium environment and also check that `pd_shell` can connect to your
Podium system.

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

`sourcename` must be a single Podiun Source name.

`entityname` can be a single un-quoted Podiun Entity name or a
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
2018-04-19 08:58:10 - Processing entities for podium_source: XXX_SRC, maximum concurrent jobs 4, 1 entities, refesh interval 10
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

Will report on the staus of the last 5 data loads for the named Source / Entity.

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

### Execute Workflow(s) (-w)

```bash
./pd_shell.sh -y pd_dev.yml -w workflowname
```

Will execute the named workflow using the `default:engine` engine.

`default:engine` may be overridden using the `-m` option (TEZ/MAPREDUCE).

`workflowname` can be a single un-quoted Podiun Workflow name or a
quoted list of workflowname names e.g. "wf1 wf2 wf33" etc.

If a quoted list of Workflow names is given `pd_shell` will execute up to
`max_jobs` workflows concurrently, picking the next workflow from the list as
each workflow completes until the list is exhausted.

`pd_shell` will report on the workflow status every `refresh_interval` seconds
until complete.

### Report on a Workflow (-r -c -w)

```bash
./pd_shell.sh -y pd_dev.yml -r -c 5 -w workflowname
```

Will report on the staus of the last 5 workflow executions for the named workflow.

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

### Export / Import Podium Objects (-x -i)

Export a complete Source

```
:~ ./pd_shell.sh -y pd_dev.yml -x -s XXX_SRC

2018-04-19 09:22:07 - Source XXX_SRC exported to file XXX_SRC_163_2018-04-19T13:21:42.zip
```

Export a Source / Entity

```
:~ ./pd_shell.sh -y pd_dev.yml -x -s XXX_SRC -e activity_type_t

2018-04-19 09:24:39 - Entity XXX_SRC.activity_type_t exported to file XXX_SRC_activity_type_t_10826_2018-04-19T13:24:20.zip
```

NOTE: Import is still in test.

### Clean (delete) Historical Data Loads and Workflow Executions (-k)

Podium keeps every version of data for a data load or workflow execution.

This can lead to a rapi consumption of space in the Hadoop file system.

`pd_shell` through the use of the -k option will trim the number of versions being retained.

#### Clean Data Load History

```bash
./pd_shell.sh -y pd_dev.yml -k -c 5 -s sourcename -e entityname
```

Will delete load logs, profile data, HDFS contents and Hive patitions for the named
Source / Entity, retaining the last 5 most recent FINISHED data loads.

Note: This will only work against snapshots not incremental data loads.

`entityname` may be a single unquoted name or a quoted list of entity names.

#### Clean Workflow Execution History

```bash
./pd_shell.sh -y pd_dev.yml -k -c 5 -w workflowname
```

Will delete load logs,  HDFS contents and Hive patitions for the named
workflow, retaining the last 5 most recent FINISHED executions.

## Verbose Output (-v)

Specifying the -v option on any `pd_shell` operation will display extended information
including the cURL command send to Podium and the returned JSON.

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
