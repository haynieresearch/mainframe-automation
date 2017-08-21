#!/bin/bash
#**********************************************************
#* CATEGORY    APPLICATIONS
#* GROUP       MAINFRAME
#* AUTHOR      LANCE HAYNIE <LANCE@HAYNIEMAIL.COM>
#* DATE        2016-06-15
#* PURPOSE     MAINFRAME AUTOMATION
#**********************************************************
#* MODIFICATIONS
#* 2016-06-15 - LHAYNIE - INITIAL VERSION
#* 2016-10-24 - LHAYNIE - UPDATES FOR JOBNUM
#* 2016-10-25 - LHAYNIE - UPDATES FOR CONDITIONAL CHECK
#* 2016-10-26 - LHAYNIE - ADDED ERROR TRAP FOR BAD JCL
#* 2016-11-01 - LHAYNIE - ADDED DATESTAMP TO JOB LOG
#* 2016-11-01 - LHAYNIE - ADDED ERROR TRAP FOR NO JOB FOUND
#* 2016-11-30 - LHAYNIE - REMOVED $PDW REFERENCE FOR AUTOSYS
#* 2016-11-30 - LHAYNIE - REMOVED EXTRA ECHO IN EMAIL LOG
#* 2016-12-02 - LHAYNIE - UPDATED JOB DOWNLOAD PROC
#* 2016-12-02 - LHAYNIE - SPLIT EXIT 206 INTO 206 AND 207
#* 2016-12-05 - LHAYNIE - CHANGED EXIT 206 AND 207 TO WARNINGS
#* 2017-01-04 - LHAYNIE - UPDATES TO CLEANUP PROCESS
#* 2017-01-05 - LHAYNIE - ADDED EXIT FOR JCL ERROR
#* 2017-01-05 - LHAYNIE - ADDED MYSQL LOGGING
#* 2017-01-05 - LHAYNIE - ADDED END SLEEP
#* 2017-05-12 - LHAYNIE - ADDED FUNCTION TO OPEN ISSUE ON FAILURE
#* 2017-05-15 - LHAYNIE - ADDED DO NOT DISTRUB FUNCTION FOR JOBS THAT ARE EXPECTED TO FAIL
#* 2017-05-18 - LHAYNIE - UPDATED MYSQL QUERIES TO DYNAMIC HOST FOR DEV/PROD
#* 2017-05-18 - LHAYNIE - ADDED JOB COMM FUNCTIONALITY
#* 2017-05-18 - LHAYNIE - UPDATED SUCCESS/NOTIFY/WARNING/FAILURE WATERFALL
#* 2017-05-18 - LHAYNIE - SUPPRESSED NEW ISSUES ON FAILURE WHEN IN DEV
#**********************************************************

#**********************************************************
#* INCLUDES AND VARIABLES
#**********************************************************

#include master password file
source /path/to/password/file/passwords.cfg

#some argument variables
pid=$$
currentUser=$USER
mainframeServer=$1
libraryName=$2
jclMember=$3
emailFlag=$4
baseFileName=`basename "$0"`
currentHost=$(hostname)
currentDate=$(date +%Y%m%d)
jobDoNotDisturb="NO"

if [ "$currentHost" == "devserver" ] || [ "$currentHost" == "devserver.yourdns.com" ]; then
	baseDir=/path/to/this/software
	env="DEV"
elif [ "$currentHost" == "prodserver" ] || [ "$currentHost" == "prodserver.yourdns.com" ]; then
	baseDir=/path/to/this/software
	env="PROD"
else
	baseDir=$PWD
fi

#folder and file variables
logDir=/logs
tempFolder=/tmp
pidfile=/var/run/submitJob.pid
jobNumFile=/tmp/jobsub.jobNumber.$$
jobOutputFile=/tmp/jobsub.jobOutput.$$
jobNameFile=/tmp/jobsub.jobName.$$
jclDownloadResult=/tmp/jobsub.jclDownloadResult.$$

#other variables
appVersion="0.2.0"
appName="Mainframe Remote Submit Utility"
adminEmail=$(mysql -h $currentHost -uMYSQLUSER -pMYSQLPASSWORD mainframe_automation -se "select email from job_comm where library = '$libraryName' and member = '$jclMember'")

if [ -z $emailFlag ]; then
        emailSendTo=$adminEmail
elif [ $emailFlag == "0" ]; then
        emailSendTo=/dev/null
else
        emailSendTo=$adminEmail
fi

if [ -z $adminEmail ]; then
	emailSendTo="ADMIN@YOURDNS.COM"
else
	emailSendTo=$adminEmail
fi
#**********************************************************
#* FUNCTIONS
#**********************************************************

function fileCleanup {
	rm -f $jobNumFile
	rm -f $jobOutputFile
	rm -f $jobNameFile
	rm -f $jclDownloadResult
	rm -f $tempFolder/$jobNumber
	rm -f $tempFolder/$jclMember

lftp $host << EOF
set ftp:ssl-allow true
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ftp:ssl-protect-list true
set ssl:verify-certificate no
set xfer:clobber 1
open -u $user,$pass
site file=jes
get -a $jobNumber
rm $jobNumber
bye
EOF
}

#function to send email notifications
function emailNotify {

        if [ "$jobDoNotDisturb" == "YES" ]; then
                emailSubject="NOTIFICATION ONLY: Mainframe Job: $jclMember - Library: $libraryName - Server: $mainframeServer"
        elif [ "$finalExitCode" == 4 ] || [ "$finalExitCode" == 206 ] || [ "$finalExitCode" == 207 ]; then
                emailSubject="WARNING: Mainframe Job: $jclMember - Library: $libraryName - Server: $mainframeServer"
        elif [ "$finalExitCode" != 0 ]; then
                emailSubject="FAILURE: Mainframe Job: $jclMember - Library: $libraryName - Server: $mainframeServer"
        else
                emailSubject="SUCCESS: Mainframe Job: $jclMember - Library: $libraryName - Server: $mainframeServer"
        fi

/usr/sbin/sendmail "$emailSendTo" << EOF
Content-Type: text/html
MIME-Version: 1.0
Subject:$emailSubject
From:$appName <no-reply@yourdns.com>
To:$emailSendTo
<b>JOB DETAILS:</b><br>
<pre>
-----------------------------------------------
Linux Process ID.: $pid
Linux Host.......: $currentHost
Linux User ID....: $currentUser
Remote Server....: $mainframeServer
Library..........: $libraryName
Member...........: $jclMember
Job Name.........: $jobName
Job Number.......: $jobNumber
Result Code......: $condCode
Exit Code........: $finalExitCode
Start Time.......: $startTime
End Time.........: $endTime
-----------------------------------------------
</pre>
<br>
$appName<br>
Version: $appVersion<br>
<br>
<b>LOG DETAILS:</b><br>
<pre>
$logContents
</pre>
EOF
}

#creates header for display output
function header {
	startTime=$(date +'%Y-%m-%d %H:%M:%S')
	echo $appName
	echo "Version.....:  $appVersion"
	echo "*****************JOB START*****************"
	echo "Start Time..:  $startTime"
}

#creates footer for display output
function footer {
	endTime=$(date +'%Y-%m-%d %H:%M:%S')
	echo "End Time....:  $endTime"
	echo "*****************JOB   END*****************"
}

#creates usage display
function usageDisplay {
	echo "Usage: <server> <library-name> <jcl-member-name>"
}

#function to ensure filename is constant
#this is important for the processCheck function
function fileNameCheck {
	if [ $baseFileName != "submitJob.sh" ]; then
		header
		echo "Error: Script name is not submitJob.sh!"
		footer
		condCode="Error: Script name is not submitJob.sh!"
		finalExitCode=200
		logResult
		fileCleanup > /dev/null 2>&1
		exit 200
	fi
}

#function to check if other submitJob process is running and what
#jobname is currently being ran
function processCheck {
trap "rm -f -- '$pidfile'" EXIT
echo $pid > "$pidfile"

for pidcheck in $(pidof -x submitJob.sh); do
	if [ $pidcheck != $$ ]; then
		currentJobName=`cat /tmp/jobsub.jobName.$pidcheck`
		currentJobNumberFile=/tmp/jobsub.jobNumber.$pidcheck

		if [ ! -f $currentJobNumberFile ]; then
			currentJobNumber="Unknown"
		elif [ -z "$currentJobNumber" ]; then
			currentJobNumber="Unknown"
		else
			tmpCurrentJobNumber=`awk '/./{line=$0} END{print $2}' $currentJobNumberFile`
			currentJobNumber="${tmpJobNumber//,}"
		fi

		if [ $jobName == $currentJobName ]; then
			clear
			header
			echo ""
			echo "Error: cannot run simultaneous jobs with"
			echo "the same job name!"
			echo ""
			echo "Job Name...........: $currentJobName"
			echo "Current Job Number.: $currentJobNumber"
			echo "Current PID........: $pidcheck"
			echo "Current Linux Host.: $currentHost"
			echo "Current User ID....: $currentUser"
			echo ""
			echo "Waiting for other process to end..."
			footer
			sleep 10
			exec bash "$0" $mainframeServer $libraryName $jclMember $jobName
		fi
	fi
done
}

#function to ensure all options have been given upon execution
function checkOptions() {
	if [ -z "$mainframeServer" ]; then
		echo "Missing Mainframe Server Option"
		usageDisplay
		condCode="Error: Missing Mainframe Server Option"
		finalExitCode=201
		logResult
		fileCleanup > /dev/null 2>&1
		exit 201
	elif [ "$mainframeServer" == "help" ]; then
        	echo $appName
        	echo "Version: $appVersion"
        	usageDisplay
        	echo "Optional: If the 4th parameter contains"
       		echo "a 0, a notification email will not be sent"
		exit 0
	elif [ -z $libraryName ]; then
		echo "Missing PDS Library Name"
		usageDisplay
		condCode="Error: Missing PDS Library Name"
		finalExitCode=202
		logResult
		fileCleanup > /dev/null 2>&1
		exit 202
	elif [ -z $jclMember ]; then
		echo "Missing JCL Member Name"
		usageDisplay
		condCode="Error: Missing JCL Member Name"
		finalExitCode=203
		logResult
		fileCleanup > /dev/null 2>&1
		exit 203
	else
		#if all options were given, display job information
		header
		echo "PID.........:  $pid"
		echo "Linux Host..: " $currentHost
		echo "Linux User..: " $currentUser
		echo "Server......: " $mainframeServer
		echo "Library.....: " $libraryName
		echo "Member......: " $jclMember
	fi
}

#function to set host and user variables based on the server name provided
function selectServer() {
	if [ "$mainframeServer" == "MAINFRAME1" ] || [ "$mainframeServer" == "mainframe1" ]; then
		user=$mainframe1user
		pass=$mainframe1pass
		host=$mainframe1host
	elif [ "$mainframeServer" == "MAINFRAME2" ] || [ "$mainframeServer" == "mainframe2" ]; then
		user=$mainframe2user
		pass=$mainframe2pass
		host=$mainframe2host
	elif [ "$mainframeServer" == "MAINFRAME3" ] || [ "$mainframeServer" == "mainframe3" ]; then
		user=$mainframe3user
		pass=$mainframe3pass
		host=$mainframe3host
	else
		echo "Error: Unknown Mainframe Server."
		condCode="Error: Unknown Mainframe Server."
		finalExitCode=204
		logResult
		fileCleanup > /dev/null 2>&1
		exit 204
	fi
}

function downloadJcl {
(
cd $tempFolder
touch $jclMember
rm -f $jclMember

lftp $host << EOF
set ftp:ssl-allow true
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ftp:ssl-protect-list true
set ssl:verify-certificate no
open -u $user,$pass
cd "'$libraryName'"
get -a "$jclMember"
bye
EOF
)
}

function checkJclDownload {
	jclDownloadTemp=`awk 'NR==1{print $3}' $jclDownloadResult`

	if [ "$jclDownloadTemp" == "failed:" ]; then
		finalExitCode=205
		condCode="Error Downloading JCL"
		echo "Result Code.:  $condCode"
		echo "Exit Code...:  $finalExitCode"
		footer
		logResult
		fileCleanup > /dev/null 2>&1
		exit 205
	fi
}

function submitJcl {
(
lftp $host << EOF
set ftp:ssl-allow true
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ftp:ssl-protect-list true
set ssl:verify-certificate no
set xfer:clobber 1
open -u $user,$pass
quote site filetype=jes recfm=f lrecl=80 blksize=80
put -a $tempFolder/$jclMember
bye
EOF
)
}

function processJobName {
cd $tempFolder
jobNameTemp=`awk 'NR==1{print $1}' $jclMember`
jobName=${jobNameTemp:2}
echo $jobName > $jobNameFile
echo "Job Name....: " $jobName
}

function processJobNumber {
(
lftp $host << EOF
set ftp:ssl-allow true
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ftp:ssl-protect-list true
set ssl:verify-certificate no
set xfer:clobber 1
open -u $user,$pass
quote site filetype=jes recfm=f lrecl=80 blksize=80
ls $jobName
bye
EOF
) 2>&1 | tee $jobNumFile
}

function getJobNumber {
sleep 10
processJobNumber > /dev/null 2>&1
tmpJobNumber=`awk '/./{line=$0} END{print $2}' $jobNumFile`
jobNumber="${tmpJobNumber//,}"
jobNumOnly=${jobNumber:3}

if [ "$jobNumber" == "jobs" ]; then
	echo "Job No......: ERROR!"
        echo "Result Code.: ERROR!"
        condCode="Error: Unable to download job file"
        finalExitCode=207
        logResult
	fileCleanup > /dev/null 2>&1
        exit 207
else
	echo "Job No......: " $jobNumber
fi
}

function downloadJobFile {
cd $tempFolder
lftp $host << EOF
set ftp:ssl-allow true
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ftp:ssl-protect-list true
set ssl:verify-certificate no
set xfer:clobber 1
open -u $user,$pass
site file=jes
get -a $jobNumber
bye
EOF
cp $jobNumber $baseDir$logDir/$currentDate-$mainframeServer-$libraryName-$jclMember-$jobNumber
logContents=$(cat $baseDir$logDir/$currentDate-$mainframeServer-$libraryName-$jclMember-$jobNumber)
}

function getJobFile {
cd $tempFolder
loopCounter=0
until [ $loopCounter == 25 ]; do

downloadJobFile > /dev/null 2>&1

if [ "$loopCounter" != 25 ]; then
	if [ ! -f $jobNumber ]; then
	let loopCounter+=1
	sleep 30
	else
	loopCounter=25
	fi
else
	echo "Result Code.:  ERROR!"
	condCode="Error: Unable to download job file"
	finalExitCode=206
	logResult
	fileCleanup > /dev/null 2>&1
	exit 206
fi
done
}

function checkJclError {
cd $tempFolder
awk '/JCL ERROR/ {print}' $jobNumber > $jobOutputFile

while read jclCode
   do
      if [ "$jclCode" != "" ]; then
         finalExitCode=208
	 condCode="JCL Error"
         echo "Result Code.:  $condCode"
         echo "Exit Code...:  $finalExitCode"
         footer
         logResult
	 fileCleanup > /dev/null 2>&1
         exit 208
      fi
done < $jobOutputFile
}

function getResultCode {
cd $tempFolder
resultCode=ERR
awk '/IEF142I/ {print $NF}' $jobNumber > $jobOutputFile

while read condCode
   do
      if [ "$condCode" == "0004" ]; then
         finalExitCode=0
         echo "Result Code.:  $condCode"
         echo "Exit Code...:  $finalExitCode"
         footer
         logResult
	 fileCleanup > /dev/null 2>&1
         exit 0
      elif [ "$condCode" == "0008" ]; then
         finalExitCode=8
         echo "Result Code.:  $condCode"
         echo "Exit Code...:  $finalExitCode"
         footer
         logResult
	 fileCleanup > /dev/null 2>&1
         exit 8
      elif [ "$condCode" == "0012" ]; then
         finalExitCode=12
         echo "Result Code.:  $condCode"
         echo "Exit Code...:  $finalExitCode"
         footer
         logResult
	 fileCleanup > /dev/null 2>&1
         exit 12
      fi
done < $jobOutputFile
finalExitCode=0
condCode=0000
echo "Result Code.:  $condCode"
echo "Exit Code...:  $finalExitCode"
footer
logResult
fileCleanup > /dev/null 2>&1
exit 0
}

function logResult {
suppressLogging=$(mysql -h $currentHost -uMYSQLUSER -pMYSQLPASSWORD$ mainframe_automation -se "select id from notification_suppress where library = '$libraryName' and member = '$jclMember'")

if [ -z "$suppressLogging" ]; then
	if [ "$finalExitCode" != "0" ]; then
		if [ "$env" != "prod" ]; then
			emailNotify
			writeDatabase
		else
			emailNotify
			writeDatabase
		fi
	else
		emailNotify
		writeDatabase
	fi
else
	jobDoNotDisturb="YES"
	emailNotify
fi
}

function writeDatabase {
echo "INSERT INTO job_history (environment,linux_pid,linux_host,remote_server,library,member,job_name,job_number,result_code,exit_code,start_time,end_time) VALUES ('$env','$pid','$currentHost','$mainframeServer','$libraryName','$jclMember','$jobName','$jobNumber','$condCode','$finalExitCode','$startTime','$endTime');" | mysql -h $currentHost -uMYSQLUSER -pMYSQLPASSWORD mainframe_automation;
}

#**********************************************************
#* MAIN PROGRAM
#**********************************************************

clear
fileNameCheck
checkOptions
selectServer
downloadJcl > $jclDownloadResult 2>&1
checkJclDownload
processJobName
processCheck
submitJcl > /dev/null 2>&1
getJobNumber
getJobFile
checkJclError
getResultCode
sleep 60
