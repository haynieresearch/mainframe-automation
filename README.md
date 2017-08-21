# Mainframe Remote Submit Utility
The mainframe remote submit utility is an automation tool for automating mainframe jobs on
IBM Mainframes. This tool utilizes the JES integration into FTP on the mainframe. The
only package that must be installed on your linux machine is LFTP. This software does
not installed on the mainframe itself. This software is targeted for users who wish to
automate jobs but are not able to do so via traditional means.

In my case, only production jobs subject to production change control can be automated
on the mainframe. This software provides a work-around so that ad-hoc jobs can be automated
without going through the normal production processes. The jobs that I use this for generally
are very agile and fluid, changing often. This would make submitting to production a nightmare.

### Assumptions
* As stated above, you need to have LFTP installed on your machine.
* The FTP-JES interface needs to be installed on your mainframe, it normally is.
* You will be submitting jobs from a Linux or UNIX machine.

### Configuration
1. Create a passwords.cfg file with your mainframe user, password, and host
   1. search for function selectServer() to see what it is looking for
2. Edit the current host parameters at the top of the script
   1. This changes the actions based on prod/dev instance of the script
3. Search for MYSQLUSER and MYSQLPASSWORD and replace with your information
   1. Create a database called mainframe_automation
   2. In this database, create a job_comm, notification_suppress and job_history table
      1. The job_comm table holds information on who to notify when jobs complete
         1. id - int(11) auto increment
         2. library - varchar(50)
         3. member - varchar(8)
         4. email - varchar(500)
      2. The notification_suppress table holds the jobs that will not get notifications
         1. id - int(11) auto increment
         2. library - varchar(50)
         3. member - varchar(8)
      3. The job_history table holds all of the job history
         1. job_id - int(11) auto increment
         2. environment - varchar(4)
         3. linux_pid - int(10)
         4. linux_host - varchar(45)
         5. remote_server - varchar(45)
         6. library - varchar(45)
         7. member - varchar(8)
         8. jobname - varchar(8)
         9. job_number - varchar(25)
         10. result_code - varchar(50)
         11. exit_code - int(5)
         12. start_time - datetime
         13. end_time - datetime
4. Search for emailSendTo="ADMIN@YOURDNS.COM" and change the email to your admin email

### Usage
```
./submitJob.sh <server> <library-name> <jcl-member> 
```

### Successful Output
```
*****************JOB START*****************
Start Time..:  Tue Oct 25 12:34:39 CDT 2016
PID.........:  9610
Server......:  SERVER
Library.....:  MY.PDS.LIBRARY
Member......:  TEST
Job Name....:  TESTINGA
Job No......:  JOB27154
Result Code.:  0000
Exit Code...:  0
End Time....:  Tue Oct 25 12:34:54 CDT 2016
*****************JOB   END*****************
```

### Successful Email
```
From: Mainframe Remote Submit Utility [mailto:email@domain.com] 
Sent: Tuesday, December 06, 2016 10:00 AM
Subject: SUCCESS: Mainframe Job: TEST - Library: MY.PDS.LIBRARY - Server: SERVER

JOB DETAILS:

-----------------------------------------------
Linux Process ID.: 10905
Linux Host.......: prod.server.yourdomain.com
Linux User ID....: local_user
Remote Server....: SERVER
Library..........: MY.PDS.LIBRARY
Member...........: TEST
Job Name.........: TESTINGA
Job Number.......: JOB19790
Result Code......: 0000
Exit Code........: 0
Start Time.......: Tue Dec  6 11:00:02 CST 2016
End Time.........: Tue Dec  6 11:00:22 CST 2016
-----------------------------------------------

Mainframe Remote Submit Utility
Version: 0.0.6

LOG DETAILS:

1                   J E S 2  J O B  L O G  --  S Y S T E M  X 8 3 2   
0 
 11.00.10 JOB19790 ---- TUESDAY,   06 DEC 2016 ----
 11.00.10 JOB19790  TSS7000I USER Last-Used 06 Dec 16 07:00 System=X832 Facility=BATCH
 11.00.10 JOB19790  TSS7001I Count=06624 Mode=Fail Locktime=None Name=
 11.00.10 JOB19790  $HASP373 TESTINGA   STARTED - INIT 1    - CLASS S        - SYS X832
 11.00.10 JOB19790  IEF403I TESTINGA - STARTED - TIME=11.00.10
 11.00.11 JOB19790  -                                         --TIMINGS (MINS.)--
 11.00.11 JOB19790  -JOBNAME  STEPNAME PROCSTEP    RC    EXCP    CPU    SRB  CLOCK   SERV  PG
 11.00.11 JOB19790  -TESTINGA            NDMCBNV     00     280    .00    .00    .02  46621   0
 11.00.11 JOB19790  IEF404I TESTINGA - ENDED - TIME=11.00.11
 11.00.11 JOB19790  -TESTINGA   ENDED.  NAME-*NIX SCR IMPT        TOTAL CPU TIME=   .00  TOTAL ELAPSED TIME=   .02
 11.00.11 JOB19790  $HASP395 SLSSSB   ENDED
0------ JES2 JOB STATISTICS ------
-  06 DEC 2016 JOB EXECUTION DATE
-           16 CARDS READ
-          332 SYSOUT PRINT RECORDS
-            0 SYSOUT PUNCH RECORDS
-           28 SYSOUT SPOOL KBYTES
-         0.02 MINUTES EXECUTION TIME
 !! END OF JES SPOOL FILE !!
        1 //SLSSSB JOB (),'*NIX SCR IMPT',                              JOB19790
          //         CLASS=S,MSGCLASS=V,   TIME=(,20),                            00002000
          //         NOTIFY=SLSSS,                                                00003000
          //         USER=USER,                                                        
          // PASSWORD=                                                                                                              
        2 //NDMCBNV  EXEC PGM=DMBATCH                                                     
        3 //DMPUBLIB DD DSN=                          
        4 //DMNETMAP DD DSN=                                    
        5 //DMMSGFIL DD DSN=
        6 //DMPRINT  DD SYSOUT=*                                                          
        7 //NDMCMDS  DD SYSOUT=*                                                          
        8 //SYSIN    DD *                                                                 
 !! END OF JES SPOOL FILE !!
```

### Exit Codes
```
200 = Incorrect Program File Name
201 = Missing Mainframe Server Option
202 = Missing PDS Library Option
203 = Missing Member Option
204 = Unknown Mainframe Server
205 = Unable to Download JCL
206 = Unable to Download Job File for Log Processing
207 = Unable to Download Job File for Job Number
208 = JCL Error
```

### Considerations
Due to the way the tool scrapes job information, no two jobs with the same job name can be submitted at the same time. If they are, the tool will wait until the first job completes and then submit the second job and so on.

The job name is the first part of the job card in your JCL, in the example below USERA (userid + 1 character) is the job name. Note the comment directly below the job card. While putting the library and member name in the JCL is not required; putting it directly below the job card is helpful when debugging.
```
//USERA      JOB (),'COMPILE & LINK COBOL',
//            CLASS=E,MSGCLASS=V,NOTIFY=&SYSUID
//*MY.PDS.LIBRARY(TEST)     
```
If you attempt to submit more the one job with the same job name, the following text will display on the screen or in the log. Depending on if the first job has made it through the initial submitting stages, a job number may or may not be displayed. If it is a quick job, it most likely will not. However, longer running jobs will display the current running job number.

### Unrelated Jobs
If you have more than one unrelated job that needs to be submitted at the same time, it is recommended that you use different job names so they will execute as expected. Example: userid + A, userid + B, and so on.

### Related Jobs
If you have related jobs with dependencies, it is recommended you use the same job name and automate with Autosys. If you build the job dependencies properly in Autosys the constraint of no simultaneous jobs with the same job name is a moot point. However, we will eventually run out of unique job names per FID so planning job names for automated jobs is important.
```
*****************JOB START*****************
Start Time..:  Tue Oct 25 12:43:19 CDT 2016

Error: cannot run simultaneous jobs with
the same job name!

Job Name...........: USERA
Current Job Number.: Unknown
Current PID........: 11277

Waiting for other process to end...
End Time....:  Tue Oct 25 12:43:19 CDT 2016
*****************JOB   END*****************
```
