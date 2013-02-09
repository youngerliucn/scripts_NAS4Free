#!/bin/sh
#############################################################################
# Script containing several functions related to logging
#
# Author: fritz from NAS4Free forum
#############################################################################

# Log message type 
readonly LOG_INFO=1
readonly LOG_WARNING=2
readonly LOG_ERROR=3

##################################
# Format of the timestamp used in the log files
##################################
ts_format() {
	echo "%Y%m%d_%H%M%S" 
}

##################################
# Append an information message in a log file
# 	The 2nd argument is optional, the function can also
#	read data from the pipe
# Param 1: log file name (incl. path)
# Param 2: text to be logged
##################################
log_info() {
	log "$LOG_INFO" "$@" 
}

##################################
# Append a warning message in a log file
# 	The 2nd argument is optional, the function can also
#	read data from the pipe
# Param 1: log file name (incl. path)
# Param 2: text to be logged
##################################
log_warning() {
	log "$LOG_WARNING" "$@" 
}

##################################
# Append an information message in a log file
# 	The 2nd argument is optional, the function can also
#	read data from the pipe
# Param 1: log file name (incl. path)
# Param 2: text to be logged
##################################
log_error() {
	log "$LOG_ERROR" "$@" 
}

##################################
# Append a line into a log file
# 	The 3rd argument is optional, the function can also
#	read data from the pipe
# Param 1: message criticality 
# Param 2: path to the log file
# Param 3: message to be logged
##################################
log() {
	local criticality logfile text line 

	criticality="$1"
	logfile="$2"
	
	# If the text to be logged was provided through an argument pipe
	if [ -n "$3" ]; then
		text="$3"
		format_log_txt "$criticality" "$text" >> $logfile
		#echo "$criticality" "$text"
	# If the text to be logged was provided through the pipe
	else
		line="" 
		while read line
		do
			format_log_txt "$criticality" "$line" >> $logfile
			#echo "$criticality" "$line"
		done
	fi

	return 0 
}

##################################
# Append the date to the line to be logged
# Param 1: message criticality 
# Param 2: text to be logged 
##################################
format_log_txt() {

	local criticality text timestamp criticality_txt

	criticality="$1"
	text="$2"

	tsFormat=`ts_format`

	timestamp=`$BIN_DATE +$tsFormat` 
	
	if [ $criticality -eq $LOG_INFO ] 
	then 
		criticality_txt="INFO"
	elif [ $criticality -eq $LOG_WARNING ]  
	then
		criticality_txt="WARN"
	elif [ $criticality -eq $LOG_ERROR ]  
	then
		criticality_txt="ERROR"
	else 
		criticality_txt="UNKNOWN"
	fi
	
	echo "$timestamp	$criticality_txt	$text" 

	return 0	
}


##################################
# Echo the timestamp (in sec since 1970) 
# of the oldest entry in the log file
#
# Param 1: file path
# Return : 0 if no error occured
#	   1 if the log file does not exist
#	   2 if the timestamp could not be computed
##################################
get_log_oldest_ts() {

	local f timestamp timestamp1970 tsFormat ret_code
	
	f="$1"
	tsFormat=`ts_format`
	
	# Check if the file exists
	if [ ! -s "$f" ]; then
		echo "The file \"$f\" does not exists"
		return 1
	fi

	# get the timestamp of the 1st log entry	
	timestamp=`sed "1"!d "$f" | awk '{ print $1 }'`
 	timestamp1970=`$BIN_DATE -j -f "$tsFormat" "$timestamp" +"%s" 2>/dev/null`
	ret_code="$?"	

	# check if the timestamp1970 could be extracted
	if [ "$ret_code" -eq "0" ]; then
		echo $timestamp1970
		return 0
	else
		echo "Timestamp could not be extracted of the log file"
		return 2
	fi
}



##################################
# Returns an extract of a log file
# The functions returns the log entries generated
# during the last x seconds (see args)
#
# Param 1: file path
# Param 2: duration (in seconds)
##################################
get_log_entries() {
        local f t

        f="$1"
        t="$2"

        targetTimestamp1970=`$BIN_DATE -j -v-"$t"S +"%s"`

	get_log_entries_ts "$f" "$targetTimestamp1970"

	return "$?"	
}

##################################
# Returns an extract of a log file
# The functions returns the log entries generated
# during since the timestamp (see args) 
#
# Param 1: file path 
# Param 2: timestamp (in seconds since 1970) 
# Return : 0 if no error occurs
#	   1 if the log file does not exist
##################################
get_log_entries_ts() {
	local f targetTimestamp1970 tsFormat nbLinesInFile firstLine lastLine diffLines \
		midLine currentLine timestamp currentTimestamp1970 diffTimestamp \
		firstLineTimestamp1970 diffFirstLineTimestamp lastLineTimestamp1970 diffLastLineTimestamp 
	
	f="$1"
	targetTimestamp1970="$2"

	tsFormat=`ts_format`
	
	# Check if the file exists
	if [ ! -s "$f" ]; then
		echo "The file \"$f\" does not exists"
		return 1
	fi

	nbLinesInFile=`wc -l "$f" | awk ' { print $1 } '`	# find number of lines	

 	firstLine=1
	lastLine=$nbLinesInFile
	diffLines=$(($lastLine-$firstLine))

	# Find the oldest line to be returned using dichotomy
	while [ "$diffLines" -gt "1" ]
	do

		# get the line in the middle of the 1st and last one
		midLine=$((($lastLine+$firstLine)/2))
		currentLine=`sed "$midLine"!d "$f"`

		# get the timestamp of the line	
		timestamp=`echo "$currentLine" | awk '{ print $1 }'`
 		currentTimestamp1970=`$BIN_DATE -j -f "$tsFormat" "$timestamp" +"%s" 2>/dev/null`

		if [ "$?" -ne "0" ]; then
			echo "Bad timestamp format ($timestamp) in log file. Skipping file"
			return 1
		fi

		# decide which range shall be taken next
		diffTimestamp=$(($targetTimestamp1970-$currentTimestamp1970))

		if [ "$diffTimestamp" -gt "0" ]; then
			firstLine=$midLine
			lastLine=$lastLine
		else
			firstLine=$firstLine
			lastLine=$midLine
		fi

		diffLines=$(($lastLine-$firstLine))
	done


	# Now diffLines should equal 1 or 0

	currentLine=`sed "$firstLine"!d "$f"`
	timestamp=`echo "$currentLine" | awk '{ print $1 }'`
        firstLineTimestamp1970=`$BIN_DATE -j -f "$tsFormat" "$timestamp" +"%s" 2>/dev/null`
	diffFirstLineTimestamp=$(($targetTimestamp1970-$firstLineTimestamp1970))
	
	currentLine=`sed "$lastLine"!d "$f"`
	timestamp=`echo "$currentLine" | awk '{ print $1 }'`
        lastLineTimestamp1970=`$BIN_DATE -j -f "$tsFormat" "$timestamp" +"%s" 2>/dev/null`
	diffLastLineTimestamp=$(($targetTimestamp1970-$lastLineTimestamp1970))


	# refine the part of the log should be returned
	# If firstLine is new enough
	if [ "$diffFirstLineTimestamp" -le "0" ]; then
        	tail -$(($nbLinesInFile-$firstLine+1)) "$f"
	# If lastLine is new enough 
	elif [ "$diffLastLineTimestamp" -le "0" ]; then
                tail -$(($nbLinesInFile-$lastLine+1)) "$f"
	# Even the last line in the log is too old
	else
		echo "The data available in the log are to old" 
	fi

	return 0
}

