# sesstop
This script provides dynamic report about top-N sql-sessions, in sense of one, setted for the script, database-statistic. 
This script is intended to be used with oracle-database.
It's cli-utility, bash script, which works like top-utility, but with data about oracle sql-session;
```
Usage:
sesstop [options]
Options:
 -l     --list  [class]         show list of statistics in class
 -f     --find  [name]          find statistic with name
 -i     --id    <stat id>       run top on stat id number with default parameters (10 elements and 20 seconds delay)
 -d     --delay [number]        delay information update delay [default 20 sec]
 -t     --top-size              display number of top elements [default 10]
 -h     --help                  display this help and exit
 -n     --nodeletedb            Do not delete sqlitedb after script ending; By default: it'll be erased;
Statistics classes:
        1. User
        2. Redo
        3. Enqueue
        4. Cache
        5. OS
        6. Real Application Clusters
        7. SQL
        8. Debug
```

As a prerequirements: sqlite should be installed and be available.
Current version of the script was developed with sqlite 3.3.6;
You have to write full path to sqlite-binary and database-file to bash-variables __SQLITE, SQLITE_DB__ inside the script;
Or you can provide the script with that information (and make some other settings) through conf-file, which have to be placed at the same directory and named as __sesstop.conf__
For instance:
```bash
CONF_FILE="sesstop.conf"
cat << __EOF__ > "$CONF_FILE"
TMP_DIR="/tmp/sesstat_$$"
TMP_FILE="/tmp/sesstat_$$/temp.dat"
SQLITE="/usr/bin/sqlite3"
SQLITE_DB="/tmp/sesstat_$$/sesstop_$$.dbf"
DELAY="5"
TOP_SIZE="15"
__EOF__
./sesstop.sh -i 12
```
![screen](screen.png)

Script's concept and sql-queries was offered by Maksim Ivanov ([MaksimIvanovPerm](https://github.com/MaksimIvanovPerm) )

Some code and parameters options processing was developed by Denis Vodopyanov ([dvodop](https://github.com/dvodop) )

Thanks for the mentoring and support Maksim Ivanov and Denis Vodopyanov.

#event_hist.sh
This script provides dynamic report about disrtibution of duration of cases of given event;
It uses sys.v_$event_histogram as data-source; 
It pulls data about event which you set, from there, waits for setted period of time and pulls new data about the same event again, from the oracle-view;
Then it find out delta-values, between those two samples of data and shows it;
So you're able to see: how many cases of setted event happened and distribution of duration of those cases;
```
Usage:
event_hist.sh [options]
Options:
 -f     --find  [name]                  find id of interesting event;
                                        Optionally you're able to set name, or part of name of event to find;
 -i     --id    <event id>              run top on given event-id with default parameters (10 elements and 20 seconds delay)
 -d     --delay [number]        delay information update delay [default 20 sec]
 -t     --top-size              display number of top elements [default 10]
 -h     --help                  display this help and exit
 -n     --nodeletedb            Do not delete sqlitedb after script ending; By default: it'll be erased;
```
example:

![screen](event_hist.png)
