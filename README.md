# Start-Multiping
Advanced ping tool for pinging multiple destinations at once. This command can return information as objects, print them to terminal as it go or save them to csv file.
The destination can be either dns name, IPv4 or IPv6 addresses. 
## Features
- All individual ping commands runs in paraller. This way if multiple destinations get time-out we only need to wait for one (in theory)
- Option to show (log) only iterations where at least one destination did not receive packet back (via -OnlyErrors parameter)
- Option to save ping data to CSV
- All iterations have time stamp
- Option to modify time format (via -TimeFormat parameter)
- Option to modify ping time-out (via -Timeout parameter)
## Examples
In Start-Multiping.ps1 file there is a function called Start-Multiping to use it you first need to load it by
```
. .\Start-MultiPing.ps1
```
and then you can call it
```
Start-MultiPing -Destinations "8.8.8.8","google.com"
```
This function by default returns objects with ping data, has 1000ms timeout and runs forewer so you need to stop it by ctrl+c.
We can change this behavior like this
```
Start-MultiPing -Destinations "8.8.8.8","google.com" -Passthrough:$false -Progress -count 10 -Timeout 200
```
This command only prints information to console (no objects) and stops after 10 iterations.
You can save the object output to variable and work with it and see live output in console and also save all data to csv file like this
```
$pings = Start-MultiPing -Destinations "8.8.8.8","google.com" -Progress -CsvPath "pings.csv"
```
By default last returned item is status information. You can access it like this.
```
$pings = Start-MultiPing -Destinations "8.8.8.8","google.com" -Progress
$pings[-1]
```
The Status information can be disabled with the parameter -NoStatus.

There is also an option for ignoring completly succesfull iterations and show (log) only the error ones
```
$pings = Start-MultiPing -Destinations "8.8.8.8","google.com" -Progress -OnlyErrors
```
You can also pipeline objects. You can pipeline an array of strings
```
"google.com","8.8.8.8" | Start-MultiPing
```
or an object with DNSHostName property
```
Get-ADComputer | Start-MultiPing
```
