# sesstop
This script report top N sql-sessions in db with statname.
```
sesstop [options]
Options:
 -l	--list	[class]		show list of statistics in class
 -f	--find  [name]		find statistic with name
 -i	--id	<stat id>	  run top on stat id number with default parameters (10 elements and 20 seconds delay)
 -d --delay [number]  delay information update delay [default 20 sec]
 -t --top-size			  display number of top elements [default 10]
 -h     --help        display this help and exit
 ```

Statistics classes:
1. User
2. Redo
3. Enqueue
4. Cache
5. OS
6. Real Application Clusters
7. SQL
8. Debug
  
Temp data used sqlite db.

This utility can be used to find and list stat name in database.

Idea and sql queries by Maksim Ivanov (MaksimIvanovPerm https://github.com/MaksimIvanovPerm)

Some code and parameters options by Denis Vodopyanov (dvodop https://github.com/dvodop)

sesstop: it's cli-utility, bash script, which works like top-utility, but with data about oracle sql-session;
![screen](screen.png)


Thanks for the mentoring and support Maksim Ivanov and Denis Vodopyanov.
