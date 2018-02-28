function Start-MultiPing{
param(
	[parameter(ValueFromPipelineByPropertyName)]$DNSHostName,
	[parameter(ValueFromPipeline)]$pip_in,
	$Destinations,
	[int]$count,
	[int]$Timeout = 1000,
	[string]$CsvPath,
	[string]$TimeFormat="HH:mm:ss.fff",
	[switch]$OnlyErrors,
	[switch]$Progress,
	[switch]$Passthrough=$true,
	[switch]$NoStatus

)
Begin {
	$addresses = @()
}
Process {
	if ($Destinations -is [string]){
		$addresses = @($Destinations)
	} else {
		if ($Destinations -is [array]){
			$addresses = $Destinations
		} else {
			if ($pip_in -is [string]){
				$addresses += $pip_in
			} else {
				if ($DNSHostName -is [string]){
					$addresses += $DNSHostName
				} else {
					throw "Destinatons variable cannot be empty"
				}
			}
		}
	}
}

End{
	Try {
		[console]::TreatControlCAsInput = $true

		if (!$count){
			$endless = $true
		} else {
			$endless = $false
		}
		
		
		if (($CsvPath) -and (Test-Path $CsvPath)) {
			Remove-Item $CsvPath
			New-Item $CsvPath -ItemType file | out-null
		}
		
		$all_data = @()
		
		while ( ($count -gt 0) -or ($endless) ){
		
			$time = Get-date
		
			$iter_data = New-Object -TypeName "PSObject"
			$iter_data | Add-Member -MemberType "NoteProperty" -Name "Time" -Value $time
			$iter_data | Add-Member -MemberType "NoteProperty" -Name "Time_string" -Value (Get-date -Date $time -Format $TimeFormat)
			
			$error = $false
			$jobs = @()
			foreach ($address in $addresses){
				$jobs += Start-Job -ArgumentList @($address,$Timeout) -ScriptBlock {
					param($address,$Timeout)
		
					$Filter = 'Address="{0}" and Timeout={1}' -f $address, $Timeout
					$raw_res = Get-WmiObject -Class Win32_PingStatus -Filter $Filter
					
					if (! $raw_res.PrimaryAddressResolutionStatus){
						if ( $raw_res.ResponseTime -is [Uint32] ){
							$raw_res.ResponseTime
						}
					} else {
						return "Unsuccessful address resolution"
					}
					
					switch ($raw_res.StatusCode){
						11001{"Buffer Too Small"}
						11002{"Destination Net Unreachable"}
						11003{"Destination Host Unreachable"}
						11004{"Destination Protocol Unreachable"}
						11005{"Destination Port Unreachable"}
						11006{"No Resources"}
						11007{"Bad Option"}
						11008{"Hardware Error"}
						11009{"Packet Too Big"}
						11010{"Request Timed Out"}
						11011{"Bad Request"}
						11012{"Bad Route"}
						11013{"TimeToLive Expired Transit"}
						11014{"TimeToLive Expired Reassembly"}
						11015{"Parameter Problem"}
						11016{"Source Quench"}
						11017{"Option Too Big"}
						11018{"Bad Destination"}
						11032{"Negotiating IPSEC"}
						11050{"General Failure"}
					}
				}
			}
			
			Wait-job $jobs | out-null
			
			$n=0
			foreach ($job in $jobs){
				$res = Receive-job $job
				if ( $res -isnot [Uint32] ){
					$error = $true
				} 
				$iter_data | Add-Member -MemberType "NoteProperty" -Name $addresses[$n] -Value $res
				$n++
			}
			
			if ($OnlyErrors){
				if ($error) {
					if ($CsvPath){
						$iter_data | select * -ExcludeProperty "Time" | Export-Csv -Path $CsvPath -UseCulture -Append
					}
					if ($Progress){
						$iter_data | select * -ExcludeProperty "Time" | Write-host
					}
					if ($passthrough){
						$iter_data | select * -ExcludeProperty "Time_string"
					}
				}
			} else {
				if ($CsvPath){
					$iter_data | select * -ExcludeProperty "Time" | Export-Csv -Path $CsvPath -UseCulture -Append
				}
				if ($Progress){
					$iter_data | select * -ExcludeProperty "Time" | Write-host
				}
				if ($passthrough){
					$iter_data | select * -ExcludeProperty "Time_string"
				}
			}
			
			$all_data += $iter_data
			
			$count--
			
			$time_diff = new-timespan -Start( get-date ) -end ( $time.AddMilliseconds($Timeout) )
			if ($time_diff -gt 0){
				sleep -Milliseconds $time_diff.TotalMilliseconds
			}
			
			# Check if user is not aborting us
			if ([console]::KeyAvailable) {
				$key = [system.console]::readkey($true)
				if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
					break
				}
			}
		}
	
	}
	Finally {
		[console]::TreatControlCAsInput = $true
		
		if (!$NoStatus){
			$iter_data = New-Object -TypeName "PSObject"
			
			foreach ($address in $addresses){
				$status = New-Object -TypeName "PSObject"
				$status | Add-Member -MemberType "NoteProperty" -Name "Successes" -Value ( ($all_data.$address | where{$_ -is [Uint32]} | measure ).Count )
				$status | Add-Member -MemberType "NoteProperty" -Name "Errors" -Value ( ($all_data.$address | where{$_ -isnot [Uint32]} | measure ).Count )
				$status | Add-Member -MemberType "NoteProperty" -Name "Maximum" -Value ( ($all_data.$address | where{$_ -is [Uint32]} | measure -Maximum ).maximum )
				$status | Add-Member -MemberType "NoteProperty" -Name "Minimum" -Value ( ($all_data.$address | where{$_ -is [Uint32]} | measure -Minimum ).minimum )
				$status | Add-Member -MemberType "NoteProperty" -Name "Average" -Value ( ($all_data.$address | where{$_ -is [Uint32]} | measure -Average ).average )
				
				$iter_data | Add-Member -MemberType "NoteProperty" -Name $address -Value ($status)
			}
			if ($CsvPath){
				$iter_data | Export-Csv -Path $CsvPath -UseCulture -Append -Force
			}
			if ($Passthrough){
				$iter_data
			}
			if ($Progress){
				Write-host
				Write-host "Status:"
				Write-host ($iter_data | format-list | out-string)
			}
		}
	}
}
}