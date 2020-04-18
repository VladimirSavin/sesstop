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
else
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
fi
# === ===

# === Runtime configuration ===
CONF_FILE="event_hist.conf"; [ -f "$CONF_FILE" ] && { source "$CONF_FILE"
echo "Configuration sourced from ${CONF_FILE}"
cat "$CONF_FILE"
}

TMP_DIR=${TMP_DIR:-"/tmp/sesstat_$$"}
TMP_FILE=${TMP_DIR}"/temp.dat"
SQLITE=${SQLITE:-"/usr/bin/sqlite3"}
SQLITE_DB=${TMP_DIR}"/sesstop_$$.dbf"; [ -f "$SQLITE_DB" ] && rm -f "$SQLITE_DB"
DELAY=${DELAY:-20}
v_timestamp=`date +%s`
SCREEN_SIZE_LINES=$((`tput lines` - 1))
original_tty_state=$(stty -g)
# To delete (0) or not to delete (1) sqlitedb at exit; 
# it may be necessary to retain datbase, for example - for some analysis later in time;
NODELETEDB="0"
# === ===

###############################################################
#
 #		Variables definition block END
#
###############################################################

###############################################################
#
 #		Output functions BEGIN
#
###############################################################
# echo_usage	- output script help
# echo_error	- output error messages
# echo_warn	- output warning messages
# echo_info	- output info messages
# echo_debug	- output debug messages
# echo_okay	- output normal messages
echo_usage() {
	printf "%s\n" "Usage:
`basename $0` [options]
Options:
 -f	--find  [name]			find id of interesting event; 
					Optionally you're able to set name, or part of name of event to find;
 -i	--id	<event id>		run top on given event-id with default parameters (10 elements and 20 seconds delay)
 -d	--delay [number]	delay information update delay [default 20 sec]
 -t	--top-size		display number of top elements [default 10]
 -h     --help                  display this help and exit
 -n	--nodeletedb		Do not delete sqlitedb after script ending; By default: it'll be erased;
"
}

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
# oracle_find_event		- find event name in database which name like inputed parameter


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

#oracle_find_stat() {
#	$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
#set echo off
#set head off
#set feedback off
#set linesize 180
#set pagesize 0
#column name format a70
#select statistic#, name from sys.v_\$statname where lower(name) like lower('%${STAT_NAME}%');
#exit;
#EoOS
#}

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

#oracle_stats_name# {
#	$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EoOS
#set echo off
#set head off
#set feedback off
#set linesize 180
#set pagesize 0
#column name format a70
#select statistic#, name from sys.v_\$statname where statistic#=${ID} ;
#exit;
#EoOS
#}

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
# sqlite_validate_import	- Validate import from ${TMP_FILE} to sqlite db ${SQLITE_DB}.

sqlite_create_table() {
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

sqlite_import_data() {
	"$SQLITE" "$SQLITE_DB" << __EOF__
.separator ;
.mode list
.import ${TMP_FILE} event_hist
.exit
__EOF__
}

sqlite_delete_old_samples() {
	local begin_timestamp="$1"
	local end_timestamp="$2"
	"$SQLITE" "$SQLITE_DB" << __EOF__
delete from event_hist where timestamp not in (${begin_timestamp}, ${end_timestamp});
.exit
__EOF__
}


sqlite_get_delta() {
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
__EOF__
}

###############################################################
#
 #		SQLITE functions END
#
###############################################################


#if [ -z $1 ] #Запуск без параметров выводит echo_usage
#then
#	echo_usage
#	exit 1
#fi

# no need to source because you run script as oracle user
# Source parameters
#if [ -f /etc/profile.d/ora_env.sh ]
#then
#	source /etc/profile.d/ora_env.sh
#elif [ -f /etc/profile.d/oracle.sh ]
#then
#	source /etc/profile.d/oracle.sh
#elif [ -f "$CONF_FILE" ]
#then
##	source $CONF_FILE
##else
##	echo_error "Can not source env file"
##	exit 1
#fi

while [ "$1" != "" ]
do
	case "$1" in
		"-h"|"--help")
			echo_usage
			exit 0
		;;
		"-f"|"--find")
			if [[ ! "$2" =~ ^- ]]
			then
				EVENT_NAME=$2
			fi
			oracle_find_event
			exit 0
		;;
		"-i"|"--id")
			if [ -z $2 ]
			then
				echo_error "You did not set an event ID."
				echo_usage
				exit 1
			fi
			ID=$2
			#printf "%s\n" " You want to see top on statistic #${ID}."
			shift 2
		;;
		"-d"|"--delay")
			if  [[ ! "$2" =~ ^- ]] && [[ ! -z "$2" ]]
			then
				DELAY=$2
			#	printf "%s\n" "DELAY is set to ${DELAY} second[s]."
			else
				echo_error "You did not set DELAY."
				exit 1
			fi
			shift 2
		;;
		"-n"|"--nodeletedb")
			NODELETEDB="1"
			#printf "%s\n" "SqliteDB will be retained after exit, as ${SQLITE_DB}"
			shift 1
		;;
		*) echo "$1 is not an option"
			echo_usage
			exit 1
		;;
	esac
done

if [ -z "$ID" -a -z "$EID" ]
then
	echo_error "You have to set ID of some statistics or event"
	echo_usage
	exit 1
fi

check_dirs;
check_sqlite;
sqlite_create_table;

trap 'data_purge' SIGINT SIGTERM SIGHUP SIGQUIT EXIT SIGKILL

# === Gather initial data ===
v_timestamp=`date +%s`
begin_timestamp=${end_timestamp:-0}
end_timestamp=${v_timestamp}
# echo "$begin_timestamp $end_timestamp"
oracle_export_event_data "$end_timestamp"
sqlite_import_data
progress_bar
# === ===


while true
do
	v_timestamp=`date +%s`
	begin_timestamp=${end_timestamp:-0}
	end_timestamp=${v_timestamp}
	oracle_export_event_data "$end_timestamp"
	sqlite_import_data
	
	if [ "$NODELETEDB" -eq "0" ]
	then
		#So, as NODELETEDB=0 - it means sqlitedb will'be deleted as script exit;
		#So it's not necssary to accumulate data in there 
		#and and, in sake resource saving, unnecessary samples of data: will be deleted right now;
		sqlite_delete_old_samples "$begin_timestamp" "$end_timestamp"
	fi

	tput clear
	tput sc; tput cup 1 5 ;
	tput smul; oracle_event_name; tput rmul; date; hostname -f
	tput rmul; tput rc

	tput sc; tput cup 5 5 ;
	sqlite_get_delta "$begin_timestamp" "$end_timestamp"

        read -s -t $DELAY -n 1 input_char
        case "${input_char}" in
                "q") data_purge ;;
                "?") show_help ;;
        esac
done
tput rc; tput clear

