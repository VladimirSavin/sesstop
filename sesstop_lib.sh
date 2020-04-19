#!/usr/bin/env bash
#
#  This script provides dynamic report about top-N sql-sessions, in sense of one, setted for the script, database-statistic.
#  This script is intended to be used with oracle-database;
#
#  Savin,Vodopyanov,Ivanov (c) 2020
#

###############################################################
#
 #		Variables definition block BEGIN
#
###############################################################

# === Output messages highlight ===
if [ "$TERM" = "dumb" -o "$TERM" = "unknown" ] ; then
        RED=""
        GREEN=""
        BROWN=""
        BLUE=""
        PURPLE=""
        CYAN=""
        WHITE=""
        GRAY=""
        YELLOW=""
        OFF=""

        BLACK_B=""
        RED_B=""
        GREEN_B=""
        BROWN_B=""
        BLUE_B=""
        PURPLE_B=""
        CYAN_B=""
        WHITE_B=""
        GRAY_B=""
        YELLOW_B=""
        OFF_B=""

else
	BLACK="$(tput setaf 0 2>/dev/null)"
        RED="$(tput setaf 1 2>/dev/null)"
        GREEN="$(tput setaf 2 2>/dev/null)"
        BROWN="$(tput setaf 3 2>/dev/null)"
        BLUE="$(tput setaf 4 2>/dev/null)"
        PURPLE="$(tput setaf 5 2>/dev/null)"
        CYAN="$(tput setaf 6 2>/dev/null)"
        WHITE="$(tput setaf 7 2>/dev/null)"
        GRAY="$(tput setaf 8 2>/dev/null)"
        YELLOW="$(tput setaf 11 2>/dev/null)"
        OFF="$(tput sgr0 2>/dev/null)"

        BLACK_B="$(tput setab 0 2>/dev/null)"
        RED_B="$(tput setab 1 2>/dev/null)"
        GREEN_B="$(tput setab 2 2>/dev/null)"
        BROWN_B="$(tput setab 3 2>/dev/null)"
        BLUE_B="$(tput setab 4 2>/dev/null)"
        PURPLE_B="$(tput setab 5 2>/dev/null)"
        CYAN_B="$(tput setab 6 2>/dev/null)"
        WHITE_B="$(tput setab 7 2>/dev/null)"
        GRAY_B="$(tput setab 8 2>/dev/null)"
        YELLOW_B="$(tput setab 11 2>/dev/null)"
        OFF_B="$(tput sgr0 2>/dev/null)"
fi
# === ===

###############################################################
#
 #		Output functions BEGIN
#
###############################################################
# echo_error	- output error messages
# echo_warn	- output warning messages
# echo_info	- output info messages
# echo_debug	- output debug messages
# echo_okay	- output normal messages

echo_error() {
        local exe_name=${EXE_NAME:-$0}
        local str="  ERROR ${exe_name} `date '+%y.%m.%d %H:%M:%S'`: $@"

#        if [ $LOG_LEVEL -le 4 ]
#        then
                printf "%b" "${RED}${str}${OFF}\n" >&2
#                printf "%s\n" "${str}" >> $LOG
#        fi
#        if [ $LOG_LEVEL -eq 5 ]
#        then
#                printf "%s\n" "${str}" >> $LOG
#        fi
}
echo_warn()  {
        local exe_name=${EXE_NAME:-$0}
        local str="WARNING ${exe_name} `date '+%y.%m.%d %H:%M:%S'`: $@"

	printf "%b" "${YELLOW}${str}${OFF}\n" >&2
}
echo_info()  {
        local exe_name=${EXE_NAME:-$0}
        local str="   INFO ${exe_name} `date '+%y.%m.%d %H:%M:%S'`: $@"

	printf "%b" "${BLUE}${str}${OFF}\n" >&2
}
echo_debug() {
        local exe_name=${EXE_NAME:-$0}
        local str="  DEBUG ${exe_name} `date '+%y.%m.%d %H:%M:%S'`: $@"

	printf "%b" "${CYAN}${str}${OFF}\n" >&2
}
echo_okay() {
        local exe_name=${EXE_NAME:-$0}
        local str="        ${exe_name} `date '+%y.%m.%d %H:%M:%S'`: $@"

	printf "%b" "${GREEN}${str}${OFF}\n"; >&2
}

################################################################
#
 #		Output functions END
#
################################################################
################################################################
#
 #		Supplementary functions BEGIN
#
################################################################
# check_dirs	- check existance of TMP_DIR and create it if needed
# check_sqlite	- check existance and executable of SQLITE binary
# check_command - check result of command and exit on error
# data_purge	- remove sqlite datafile, tempfile and exit
check_dirs () {
	if [ ! -w "${TMP_DIR}" ]
	then
		mkdir -p "${TMP_DIR}"
		check_command $? "Couldn't create temp dir [${TMP_DIR}]"
	fi
}

check_sqlite(){
	if [ ! -x "$SQLITE" ]
	then
		echo_error "$SQLITE not found or did not execute";
		exit 1;
	fi
}

check_command() {
        local exe_name=${EXE_NAME:-$0}
        local cmd_result
        local message
        cmd_result=$?
        shift
        message=$@
        if [ ${cmd_result} -ne 0 ]
        then
                echo_error "$message"
                exit ${cmd_result}
        fi
}

data_purge() {
	[ -f "$TMP_FILE" ] && rm -f ${TMP_FILE}
	if [ -f "$SQLITE_DB" ] 
	then
		if [ "$NODELETEDB" -eq "0"  ] 
		then
			rm -f ${SQLITE_DB}
			[ -d "$TMP_DIR" ] && rm -Rf ${TMP_DIR}
		fi
	fi
#	echo "Data purge"
	stty ${original_tty_state}
	tput reset
        if [ "$NODELETEDB" -ne "0"  ]
	then
		printf "%s\n" "You preferred to save sqlitedb, it's leaved intact as ${SQLITE_DB}"
		printf "%s\n" "Thank you for using this script, good luck in research;"
	fi
	exit 0
}

progress_bar() {
        wait_time=0
        count_down=$DELAY
        while [ $wait_time -lt $DELAY ]
        do
                for s in / - \\ \|
                do
                        printf "\r\e[K"
                        printf "\r%s %d" "$s" "$count_down"
                        sleep 1
                        ((wait_time++))
                        ((count_down--))
                        if [ $wait_time -eq $DELAY ]
                        then
                                break
                        fi
                done
        done
}
###############################################################
#
 #		Supplementary functions END
#
###############################################################
###############################################################
#
 #		Oracle functions BEGIN
#
###############################################################
# oracle_print_stats		- output all stats in database or all stats in database within stat class inputed by parameter
# oracle_find_stat		- find stat name in database which name like inputed parameter
# oracle_stats_name		- find stat name by ID
# oracle_export_stats_data	- export stats data from oracle database to temp file
#oracle_export_event_data	- export given event's data from oracle-db
#oracle_event_name		- get out event-name by it's id
#oracle_find_event		- get out list of event-id and event-name

oracle_print_stats() {
	if [ -z $CLASS ]
	then
		query="select statistic#, name from sys.v_\$statname;"
	else
		query="select statistic#, name from sys.v_\$statname where class=$CLASS;"
	fi
	$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
set echo off
set head off
set feedback off
set linesize 180
set pagesize 0
column name format a70
$query
exit;
EoOS
}

oracle_find_stat() {
	$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
set echo off
set head off
set feedback off
set linesize 180
set pagesize 0
column name format a70
select statistic#, name from sys.v_\$statname where lower(name) like lower('%${STAT_NAME}%');
exit;
EoOS
}

oracle_stats_name() {
	$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
set echo off
set head off
set feedback off
set linesize 180
set pagesize 0
column name format a70
select statistic#, name from sys.v_\$statname where statistic#=${ID} ;
exit;
EoOS
}

oracle_export_stats_data(){
	local v_timestamp="$1"
	if [ -n "${ID}" ]
	then
		$ORACLE_HOME/bin/sqlplus -S / as sysdba << __EOF__ > "$TMP_FILE"
whenever sqlerror exit failure
set head off
set feedback off
set newp none
set pagesize 0
set linesize 1024
select ${v_timestamp}||';'||st.sid||';'||s.serial#||';'||s.username||';'||s.program||';'||s.sql_id||';'||st.value
from v\$sesstat st, v\$statname sn, v\$session s
where st.STATISTIC#=sn.STATISTIC#
  and sn.STATISTIC#='${ID}'
  and st.value is not null
  and st.value>0
  and s.sid=st.sid;
exit
__EOF__
	else
	        $ORACLE_HOME/bin/sqlplus -S / as sysdba << __EOF__ > "$TMP_FILE"
whenever sqlerror exit failure
set head off
set feedback off
set newp none
set pagesize 0
set linesize 1024
select ${v_timestamp}||';'||st.sid||';'||s.serial#||';'||s.username||';'||s.program||';'||s.sql_id||';'||st.value
from v\$sesstat st, v\$statname sn, v\$session s
where st.STATISTIC#=sn.STATISTIC#
  and st.value is not null
  and st.value>0
  and s.sid=st.sid;
exit
__EOF__
	fi
}

oracle_find_event() {
$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
set echo off
set head off
set feedback off
set linesize 180
set pagesize 0
column id format 99999
column name format a70
select distinct event# as id, event as name
from sys.v_\$EVENT_HISTOGRAM where lower(event) like lower('%${EVENT_NAME}%') order by event#;
exit;
EoOS
}

oracle_event_name() {
        $ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
set echo off
set head off
set feedback off
set linesize 180
set pagesize 0
column name format a70
select distinct event from sys.v_\$EVENT_HISTOGRAM where event#=${ID};
exit
EoOS
}

oracle_export_event_data() {
        local v_timestamp="$1"
        $ORACLE_HOME/bin/sqlplus -S / as sysdba << __EOF__ > "$TMP_FILE"
whenever sqlerror exit failure
set head off
set feedback off
set newp none
set pagesize 0
set linesize 1024
SELECT ${v_timestamp}||';'||t.wait_time_milli||';'||t.wait_count
FROM sys.v_\$EVENT_HISTOGRAM t
WHERE t.event#='${ID}';
exit
__EOF__
}

###############################################################
#
 #		Oracle functions END
#
###############################################################
###############################################################
#
 #		SQLITE functions BEGIN
#
###############################################################
# sqlite_create_table		- just create empty table for statistics data
# sqlite_sqlite_table		- just drop table in sqlite database
# sqlite_import_data		- Import data from ${TMP_FILE} to sqlite db ${SQLITE_DB}
#				- Used for loading data to various sqlite-tables, so first arg of this routine: should be table name;
# sqlite_validate_import	- Validate import from ${TMP_FILE} to sqlite db ${SQLITE_DB}.
# sqlite_create_eventhist_table	- Create sqlite-table for event data

sqlite_create_eventhist_table() {
        "$SQLITE" "$SQLITE_DB" << __EOF__
drop table if exists event_hist;
create table if not exists event_hist (timestamp integer, wait_event_time integer, wait_count integer);
.exit
__EOF__

if [ "$NODELETEDB" -ne "0"  ]
then
"$SQLITE" "$SQLITE_DB" << __EOF__
create index if not exists timestamp_idx on event_hist(timestamp);
__EOF__
fi
}

sqlite_create_table() {
	"$SQLITE" "$SQLITE_DB" << __EOF__
drop table if exists sesstop;
create table if not exists sesstop (timestamp integer, sid integer, serial integer, username text, program text, sql_id text, statvalue integer);
.exit
__EOF__

if [ "$NODELETEDB" -ne "0"  ]
then
"$SQLITE" "$SQLITE_DB" << __EOF__
create index if not exists timestamp_idx on sesstop(timestamp);
__EOF__
fi

}

sqlite_import_data() {
local v_module="sqlite_import_data"
local v_table_name="$1"
if [ -z "$v_table_name" ]
then
 echo_error "${v_module} table name is empty;"
 exit 1
fi
	"$SQLITE" "$SQLITE_DB" << __EOF__
.separator ;
.mode list
.import ${TMP_FILE} ${v_table_name}
.exit
__EOF__
}

sqlite_validate_import() {
	v_x=`"$SQLITE" "$SQLITE_DB" "select count(*) from sesstop where timestamp=${v_timestamp};"`
	v_y=`wc -l ${TMP_FILE} | cut -d' ' -f1`
	if [ ${v_x} -ne ${v_y} ]
	then
		echo_error "Import validation error"
		exit 1
	fi
}

sqlite_delete_old_samples() {
	local begin_timestamp="$1"
	local end_timestamp="$2"
	local v_table_name="$3"
	if [ -z "$v_table_name" ]
	then
		echo_error "${v_module} table name is empty;"
		exit 1
	fi
	"$SQLITE" "$SQLITE_DB" << __EOF__
delete from ${v_table_name} where timestamp not in (${begin_timestamp}, ${end_timestamp});
.exit
__EOF__
}

sqlite_get_total() {
        local begin_timestamp="$1"
        local end_timestamp="$2"
	local v_y
        "$SQLITE" "$SQLITE_DB" << __EOF__ > "$TMP_FILE"
select sum(end_value-begin_value) as total
from (select ifnull(b.statvalue,0) as begin_value, e.statvalue as end_value
      from (select * from sesstop where timestamp=${end_timestamp}) e
           left join
           (select * from sesstop where timestamp=${begin_timestamp}) b
           on ( b.sid=e.sid and b.serial=e.serial ) )
      where (end_value-begin_value)>0;
__EOF__
        v_y=""
        v_y=$(cat "$TMP_FILE")
	printf -v "$3" %s "$v_y"
}

sqlite_get_delta() {
        local begin_timestamp="$1"
        local end_timestamp="$2"
        local v_x="$3"
                "$SQLITE" "$SQLITE_DB" << __EOF__
.header on
.mode column
select sid||','||serial as sessid,
       username, program, sql_id,
       cast(end_value-begin_value as integer) as delta,
       case when ((end_value-begin_value)/${v_x})*100 > 10 then round( 100*( (end_value-begin_value)/${v_x} ), 2) else null end as importance
from (select e.sid as sid,
             e.serial as serial,
             e.username as username,
             e.program as program,
             e.sql_id as sql_id,
             cast(e.statvalue as float) as end_value,
             cast( ifnull(b.statvalue,0) as float) as begin_value
      from (select * from sesstop where timestamp=${end_timestamp}) e
           left join
           (select * from sesstop where timestamp=${begin_timestamp}) b
           on ( b.sid=e.sid and b.serial=e.serial ) )
      where (end_value-begin_value)>0
      order by delta desc limit ${TOP_SIZE};
__EOF__
}

sqlite_get_event_delta() {
        local begin_timestamp="$1"
        local end_timestamp="$2"
	#printf "%d %d\n" ${begin_timestamp} ${end_timestamp}
	"$SQLITE" "$SQLITE_DB" << __EOF__
.header on
.mode column
select e.wait_event_time as wait_event_time, e.wait_count-ifnull(b.wait_count,0) as event_counts
from (select * from event_hist where timestamp=${end_timestamp}) e
left join
(select * from event_hist where timestamp=${begin_timestamp}) b
on (e.wait_event_time=b.wait_event_time)
order by e.wait_event_time asc;
.exit
__EOF__
}

sqlite_get_event_cases() {
	local begin_timestamp="$1"
	local end_timestamp="$2"
	local v_x
	"$SQLITE" "$SQLITE_DB" << __EOF__ > "$TMP_FILE"
select sum( e.wait_count-ifnull(b.wait_count,0) ) as event_counts
from (select * from event_hist where timestamp=${end_timestamp}) e
left join
(select * from event_hist where timestamp=${begin_timestamp}) b
on (e.wait_event_time=b.wait_event_time)
order by e.wait_event_time asc;
.exit
__EOF__
v_x=`cat "$TMP_FILE" | tr -d [:cntrl:] | tr -d [:space:]`
printf -v "$3" %s "$v_x"
}

###############################################################
#
 #		SQLITE functions END
#
###############################################################
