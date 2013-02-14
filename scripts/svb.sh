#!/bin/sh

# script to mark messages as read before a date, or as unread after a date

set -e
scriptversion=1.35
database="${HOME}/Library/Vienna/database3.db"

# this directory is also referenced below
tempdb="/tmp/svb.db"

# 0 - message unread, 1 = message read
read_flag=0

voleid="uk.co.opencommunity.vienna"
cixnick="$(defaults read ${voleid} Username)"

function initialise_conference_list(){
cat << EOFXXX | sqlite3 "${database}" 
-- initialise conference list.
 attach '${tempdb}' as cf;
drop table if exists cf.folder_list;
create table cf.folder_list(action_id integer primary key);


drop table if exists cf.confs_temp;
create table cf.confs_temp(conf_id, conf_name);

insert into confs_temp(conf_id, conf_name) select folder_id, foldername from
	folders where parent_id = 4;

drop table if exists cf.confs;
create table cf.confs(conf_name,topic_name,topic_id);

insert into cf.confs(conf_name,topic_name,topic_id)
	select confs_temp.conf_name,foldername, folder_id 
	from confs_temp, folders
	where 	folders.parent_id = confs_temp.conf_id ;

drop table if exists cf.cixen;
create table cf.cixen( cixen unique);
insert or replace into cf.cixen(cixen)
        select sender from messages group by sender;
drop table if exists cf.parti;
create table cf.parti(parti unique);
EOFXXX

}
# end of function #
########################### update_list ########
function update_list(){
if [ -z "${1}" ]
then
exit
fi
printf 'insert or replace into folder_list (action_id) select topic_id from confs where \047%s\047 = conf_name;'  "${1}"  \
	| sqlite3 "${tempdb}" 

}
# end of function update_list #
#############################
function list_folders(){
printf 'select action_id from folder_list;' | sqlite3 "${tempdb}"
}
#############################
function list_participants(){
sqlite3 "${tempdb}" 'select parti from parti order by parti;'
}

#### start of function set_read_flags

function set_read_flags(){
sql_initialise
sql_topics
sql_participants
sql_finalise
}
##### end of function set_read_flags
###########################

function sql_initialise(){
printf '\055- sql.initialise\n'
printf 'BEGIN TRANSACTION;\nUPDATE messages SET read_flag = %s\n' "${read_flag}"
printf '  WHERE ( (date - strftime(\047%%s\047,\047%s %s\047)) %s 0 )\n' \
 	"${date}" "${time}" "${compare}"
printf '\n\055- end of sql.initialise\n'
}
###########################
function sql_topics(){
printf '\055- sql.topics\n'
if [ ! -z "$(list_folders)" ]
then
  list_folders | sql_clause "folder_id" 0
fi
printf '\055- end of sql.topics\n'
}
###########################
function sql_participants(){
printf '\055- sql_participants\n'
if [ ! -z "$(list_participants)" ]
then
list_participants | sql_clause "sender" 1
fi
printf '\055- end of sql_participants\n'
}
##########################
function sql_finalise(){
printf ';\nCOMMIT;\n'
}

##########################
function sql_clause(){
# two arguments - the comparison object and the type (integer = 0, string = 1)
awk -v co=$1 -v type=$2 '
BEGIN { print "AND (" }
END { print ")" }
{
       if(count++ > 0) printf("OR ");
	if (type == 0)
	       printf "%s = %s\n", co, $1
	else 
		printf "%s = \047%s\047\n", co, $1 
}
'
}
####################
function sql_add_participants(){
# one argument - the participant to add
[ -z "${1}" ] && return
printf 'insert or replace into parti(parti) values(\047%s\047);' "${1}" | sqlite3 "${tempdb}"
}
#####################
function suggest_conf(){
# one argument - the name of a conference to try and match
echo 'Here are some suggestions:'
st=$(/bin/echo  -n "${1}" | cut -b 1-2)

printf "select conf_name from confs where conf_name like \047%s%%\047 group by conf_name order by conf_name;" "${st}" \
 |	sqlite3 "${tempdb}" | cols

}
#######################
function suggest_topic(){
# two arguments, conf and topic
echo Topic list for conference: "${1}"
printf 'select topic_name from confs where conf_name = \047%s\047 group by topic_name order by topic_name;' "${1}" \
	| sqlite3 "${tempdb}" | cols
}
#####################
function get_conf(){
# look up conference in the database, conference is the first argument
printf "select conf_name from confs where conf_name = \047%s\047 limit 1;" \
   "${1}" | sqlite3 "${tempdb}" 
}
######################
function search_conf_list(){
# one argument - the name of the conference to search for
if [ -z $(get_conf "${1}" ) ] 
then
printf 'Conference %s does not exist in the database\n' "${1}"
suggest_conf "${1}"
echo
return 1
else
return 0
fi
}
##########################
function cols(){
# columnate stdin to stdout
awk '{
printf( "%-14.14s ", $1);
if(count++ == 4) {count=0; printf("\n") }
}
END { printf("\n"); }'
}
#################################
function add_topics(){
# add topics for a conference. $1 = name of conference
#
while true
do
  printf 'Enter a topic for conference \047%s\047 or all or done : ' "${1}"
  read topic
  topic=$(strip "${topic}")
  [ -z "${topic}" ] && continue;
  case "${topic}" in
      ( all  ) update_list "${1}" ; return 0 ;;
      ( done ) return 0 ;;
  esac
  if topic_exists "${1}" "${topic}"
  then
	add_new_topic "${1}" "${topic}"
  else
        suggest_topic "${1}"
  fi
done
}
########## add new topic ########
function add_new_topic(){
# two arguments, conference and topic
printf 'insert or replace into folder_list(action_id) select topic_id from confs where \047%s\047 = conf_name and \047%s\047 = topic_name ;' "${1}" "${2}" | sqlite3 "${tempdb}"
}
########### topic_exists ##########
function topic_exists(){
# two arguments, conf and topic
topiclist=$(printf 'select * from confs where \047%s\047 = conf_name and \047%s\047 = topic_name ;'   "${1}" "${2}" | sqlite3 "${tempdb}" )
[ ! -z "${topiclist}" ]
}

############## strip ###############
function strip(){
# strip evil apostrophes and quotation marks from $1
/bin/echo -n "${1}" | tr -d '\047\042' 
}
############# valid_date #############
# test date on stdin
function valid_date() {
awk '
BEGIN { FS="-"; exitcode = 1 }
/^[12][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]$/
# avoid 1970 as it may not work if localtime is selected. -ve value 
{ if ( $1 >= 1971 && $1 < 2100 && $2 >= 1 && $2 <= 12 && $3 >= 1 && $3 <= 31 ) exitcode = 0; }
  
END { exit exitcode }
'
}
################ valid time #############
# test valid time on stdin
function valid_time() {
awk '
BEGIN { FS=":" ; exitcode = 1 }
/^[0-2][0-9]:[0-5][0-9]$/ { if ( $1 <= 23) exitcode = 0 }
END { exit exitcode } 
'
}
############################ begining of main code #######################
echo
echo 'Set Vole/Vinkix/Vienna message base back, version' "${scriptversion}"
echo 

if [ -z "${cixnick}" ]
then 
  echo 'Unable to determine your Cix nickname. Sorry, quiting now.'
  echo
  exit 1
fi
echo 'Please wait while I initialise a database ...'
initialise_conference_list
echo 'Initialisation finished'
echo
echo "Welcome Cix user ${cixnick}"
echo
#sql_add_participants devans
#sql_add_participants fred
all_flag=0;
while true
do
  read -p 'Please enter a conference name, or all or done : ' cf
  cf=$(strip "${cf}")

  case "${cf}" in
	( done ) break ;;
	( all )  all_flag=1 ; break ;;
  esac 
  if [ ! -z "${cf}" ]
  then	
    if search_conf_list "${cf}"
    then
 #     update_list "${cf}"
       add_topics "${cf}"
    fi
  fi
done
while true
	do
	  read -p 'Please enter date in format YYYY-MM-DD : ' date
	  date=$(strip "${date}" )
	  if ( echo "${date}" | valid_date )
		then 
		break; fi
done
while true
	do
	  read -p 'Please enter time in format HH:MM      : ' time
	  time=$(strip "${time}" )
	  if(echo "${time}" | valid_time) then break; fi
done
echo
echo
echo 'Please enter R to mark messages read before date'
echo 'or U to mark messsages unread after date.'
echo
read -p 'Please choose R/U : ' ru
echo
case "${ru}" in
	[Rr] ) read_flag=1 ;;
	[Uu] ) read_flag=0 ;;
	*    ) echo 'Nothing to do, quiting'; exit 0 ;;
esac

if [ ${read_flag} -eq 0 ]
then
  compare='>='
else
  compare='<='
fi

echo 'Stage 1 of 6. Set read/unread.'

set_read_flags | sqlite3 "${database}"

echo 'Stage 2 of 6. Set folders unread count and priority_unread_count to zero.'
echo 'UPDATE folders SET unread_count=0, priority_unread_count=0 ; ' | sqlite3 "${database}"

echo 'Stage 3 of 6. Recalculate folders unread count.'
cat << EOFBBB > /tmp/run.$$.sql
$(sqlite3 ${database}   'SELECT folder_id asc, count() FROM  messages WHERE read_flag = 0 GROUP BY folder_id  ;' | awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }' )
EOFBBB



echo 'Stage 4 of 6. Run the SQL script from stage 3 to update unread counts'
echo '              in folders.'
sqlite3 < /tmp/run.$$.sql "${database}"
[ -z "${SCRIPT_DEBUG}" ] && rm -f /tmp/run.$$.sql

echo 'Stage 5 of 6. Recalculate folders priority unread count.'

printf 'SELECT folder_id asc, count(*) FROM  messages WHERE priority_flag=1 AND read_flag = 0 GROUP BY folder_id  ;'  \
    |  sqlite3 "${database}" \
    |  awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET priority_unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }'  > /tmp/run2.$$.sql


echo 'Stage 6 of 6. Run the SQL script from stage 5 to update priority unread'
echo '              counts in folders.'
sqlite3 < /tmp/run2.$$.sql "${database}"
[ -z "${SCRIPT_DEBUG}" ] && rm -f /tmp/run2.$$.sql

echo 'Finished with no errors.'
echo
