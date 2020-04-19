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

# === Runtime configuration ===
LIBRARY_FILE=`dirname $0`"/sesstop_lib.sh"
if [ -f "$LIBRARY_FILE" ]
then
 . "$LIBRARY_FILE"
else
 echo "Library ${LIBRARY_FILE} was not found;"
 exit 1
fi

CONF_FILE="event_hist.conf"; [ -f "$CONF_FILE" ] && { source "$CONF_FILE"
echo "Configuration sourced from ${CONF_FILE}"
cat "$CONF_FILE"
}

TABLE_NAME="event_hist"
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

# === Main sstion =====================================================================
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
sqlite_create_eventhist_table

trap 'data_purge' SIGINT SIGTERM SIGHUP SIGQUIT EXIT SIGKILL

# === Gather initial data ===
v_timestamp=`date +%s`
begin_timestamp=${end_timestamp:-0}
end_timestamp=${v_timestamp}
# echo "$begin_timestamp $end_timestamp"
oracle_export_event_data "$end_timestamp"
sqlite_import_data "$TABLE_NAME"
progress_bar
# === ===

v_event_name=$(oracle_event_name)
v_hostname=$(hostname -f)
v_count="1"
v_event_cases=""
while true
do
	v_timestamp=`date +%s`
	begin_timestamp=${end_timestamp:-0}
	end_timestamp=${v_timestamp}
	oracle_export_event_data "$end_timestamp"
	sqlite_import_data "$TABLE_NAME"
	sqlite_get_event_cases "$begin_timestamp" "$end_timestamp" v_event_cases
	
	if [ "$NODELETEDB" -eq "0" ]
	then
		#So, as NODELETEDB=0 - it means sqlitedb will'be deleted as script exit;
		#So it's not necssary to accumulate data in there 
		#and and, in sake resource saving, unnecessary samples of data: will be deleted right now;
		sqlite_delete_old_samples "$begin_timestamp" "$end_timestamp" "$TABLE_NAME"
	fi

	tput clear
	tput sc; tput cup 0 0 ;
	echo "Event name: ${BLACK}${WHITE_B}${v_event_name}${WHITE}${BLACK_B}"
        v_datetime=`date`
        echo "Datetime: ${v_datetime}; ${BLACK}${WHITE_B}${v_hostname}${WHITE}${BLACK_B}"
        echo "sample#: ${BLACK}${WHITE_B}${v_count}${WHITE}${BLACK_B}; delay: ${BLACK}${WHITE_B}${DELAY}${WHITE}${BLACK_B}; event cases: ${BLACK}${WHITE_B}${v_event_cases}${WHITE}${BLACK_B}"
	if [ "$NODELETEDB" -ne "0" ]
	then
		echo -n "sqlite file: "; tput smul; echo -n "$SQLITE_DB"; tput rmul;
	fi
	tput rc

	tput sc; tput cup 4 0;
	sqlite_get_event_delta "$begin_timestamp" "$end_timestamp"

        read -s -t $DELAY -n 1 input_char
        case "${input_char}" in
                "q") data_purge ;;
                "?") show_help ;;
        esac
	((v_count++))
done
tput rc; tput clear

