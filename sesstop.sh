#!/bin/bash
#
#  This script report top N sqlsession in db with statname.
#
#  Savin
#

#--  variables -----------------------------------------
CONF_FILE="/home/oracle/DBA-9417/sesstop.conf"
TMP_DIR="/tmp/sesstat"
TMP_FILE=${TMP_DIR}"/temp.dat"
SQLITE="/usr/bin/sqlite3"
SQLITE_DB=${TMP_DIR}"/sesstop_$$.dbf"
DELAY=${DELAY:-20}
TOP_SIZE=${TOP_SIZE:-10}
v_timestamp=`date +%s`
#-------------------------------------------------------

echo_usage() {
	printf "%s\n" "Usage:
`basename $0` [options]
Options:
 -l	--list	[class]		show list of statistics in class
 -f	--find  [name]		find statistic with name
 -i	--id	<stat id>	run top on stat id number with default parameters (10 elements and 20 seconds delay)
 -d --delay [number]    delay information update delay [default 20 sec]
 -t --top-size			display number of top elements [default 10]
 -h     --help                  display this help and exit
Statistics classes:
	1. User
	2. Redo
	3. Enqueue
	4. Cache
	5. OS
	6. Real Application Clusters
	7. SQL
	8. Debug
"
}

print_stats() {
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

find_stat() {
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

stats_name() {
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

output() {
 local v_msg=$1
 local v_datetime=`date +%Y.%m.%d:%H.%M.%S | tr -d [:cntrl:]`
 echo "${v_datetime} ${v_msg}" | tee -a $LOG_FILE
}

# Check the script is already working. Uncomment this if lock_file need.
#if [ -f "$LOCK_FILE" ]
#then
#	v_lock=`cat $LOCK_FILE`
#	output "Another process(${v_lock}) with the script is already working"
#	output "If script did not launch please delete lock file: $LOCK_FILE"
#exit -1;
#fi

# Check the directory $TMP_DIR and temp data file $TMP_FILE exists.
check_dirs () {
if [ ! -d "$TMP_DIR" ]
then
	echo "Create directory $TMP_DIR"
	mkdir -p $TMP_DIR
elif [ ! -f "$TMP_FILE" ]
then
	echo "Create temp datafile $TMP_FILE"
	touch $TMP_FILE
fi
}

# Check the sqlite soft
check_sqlite(){
if [ ! -x "$SQLITE" ]
then
	echo "$SQLITE not found or did not execute";
	exit 1;
fi
}

##################################################### после этого переписать проверить #############################

# Create table in sqlite (Добавить проверку существования БД и таблицы)
create_sqlite_db_table() {
"$SQLITE" "$SQLITE_DB" << __EOF__
create table if not exists sesstop (timestamp integer, sid integer, serial integer, username text, program text, sql_id text, statvalue integer);
.exit
__EOF__
}

# Drop table in sqlite
drop_sqlite_db_table() {
"$SQLITE" "$SQLITE_DB" << __EOF__
drop table if exists sesstop;
.exit
__EOF__
}

# Import data from ${TMP_FILE} to sqlite db ($SQLITE_DB).
import_data() {
"$SQLITE" "$SQLITE_DB" << __EOF__
.separator ;
.mode list
.import ${TMP_FILE} sesstop
.exit
__EOF__
}



# Validate import from ${TMP_FILE} to sqlite db ($SQLITE_DB).
validate_import() {
v_x=`"$SQLITE" "$SQLITE_DB" "select count(*) from sesstop where timestamp=${v_timestamp};"`
v_y=`cat ${TMP_FILE} | wc -l`
[ "$v_x" -eq "$v_y" ] && ( return 0 ) || ( echo "Validate ERROR"; return 1 );
}


# Create name metrics in this $ORACLE_SID db.
create_dbf_with_data(){
v_timestamp=`date +%s`
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
}

#clear datafile, tempfile and exit
data_purge(){
rm -f ${TMP_FILE}
rm -f ${SQLITE_DB}
echo "Data purge"
exit 0
}

##################################################### до этого переписать проверить #############################


if [ -z $1 ] #Запуск без параметров выводит echo_usage
then
	echo_usage
	exit 1
fi

# Source parameters
if [ -f /etc/profile.d/ora_env.sh ]
then
	source /etc/profile.d/ora_env.sh
elif [ -f /etc/profile.d/oracle.sh ]
then
	source /etc/profile.d/oracle.sh
elif [ -f "$CONF_FILE" ]
then
	source $CONF_FILE
else
	output "Can not source env file"
	exit 1
fi

while [ "$1" != "" ]
do
	case "$1" in
		"-h"|"--help")
			echo_usage
			exit 0
		;;
		"-l"|"--list")
			if [[ ! "$2" =~ ^- ]] && [[ -n "$2" ]]
			then
				# https://docs.oracle.com/cd/B19306_01/server.102/b14237/dynviews_2136.htm#REFRN30265
				# https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-STATNAME.html#GUID-B4022F4A-ADA9-411D-BB4B-E3D74B5BB2D6
				case "$2" in
					"User")
						CLASS=1
					;;
					"Redo")
						CLASS=2
					;;
					"Enqueue")
						CLASS=4
					;;

					"Cache")
						CLASS=8
					;;
					"OS")
						CLASS=16
					;;
					"Real Application Clusters")
						CLASS=32
					;;
					"SQL")
						CLASS=64
					;;
					"Debug")
						CLASS=128
					;;
					*)
						echo_usage
						exit 1
					;;
				esac
			fi
			print_stats
			exit 0
		;;
		"-f"|"--find")
			if [[ ! "$2" =~ ^- ]]
			then
				STAT_NAME=$2
			fi
			find_stat
			exit 0
		;;
		"-i"|"--id")
			if [ -z $2 ]
			then
				printf "%s\n" "You did not choose on statistic ID."
				exit 1
			fi
			ID=$2
			printf "%s\n" " You want to see top on statistic #${ID}."
			shift 2
		;;
		"-d"|"--delay")
			if  [[ ! "$2" =~ ^- ]] && [[ ! -z "$2" ]]
			then
				DELAY=$2
				printf "%s\n" "DELAY is set to ${DELAY} second[s]."
			else
				printf "%s\n" "You did not choose on DELAY."
				exit 1
			fi
			shift 2
		;;
		"-t"|"--top_size")
			if [ -z $2 ]
			then
				printf "%s\n" "You did not choose on TOP_SIZE."
				exit 1
			fi
			TOP_SIZE=$2
			printf "%s\n" "TOP_SIZE is set to ${TOP_SIZE}."
			shift 2
		;;
		*) echo "$1 is not an option"
			echo_usage
			exit 1
		;;
	esac
done

check_dirs;
check_sqlite;
create_sqlite_db_table;

trap 'data_purge' SIGINT SIGTERM SIGHUP SIGQUIT EXIT SIGKILL

while true
	do
	v_timestamp=`date +%s`
	begin_timestamp=${end_timestamp:-0}
	end_timestamp=${v_timestamp}
	create_dbf_with_data
	import_data
	validate_import
	sleep $DELAY
	"$SQLITE" "$SQLITE_DB" << __EOF__ > "$TMP_FILE"
select sum(end_value-begin_value) as total
from (select ifnull(b.statvalue,0) as begin_value, e.statvalue as end_value
      from (select * from sesstop where timestamp=${end_timestamp}) e
           left join
           (select * from sesstop where timestamp=${begin_timestamp}) b
           on ( b.sid=e.sid and b.serial=e.serial ) )
      where (end_value-begin_value)>0;
__EOF__
	v_x=""
	v_x=$(cat "$TMP_FILE")
	[ "$v_x" -eq "0" ] && v_x="1"
	[ -z "$v_x" ] && v_x="1"

	tput clear

 		tput sc; tput cup 1 5 ;
		tput smul; stats_name;tput rmul; date; hostname -f
		tput rmul; tput rc

		tput sc; tput cup 5 5 ;
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
done
	tput rc; tput clear

