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
submitJob.sh mainframeHost library jclMember
```
