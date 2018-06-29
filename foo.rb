require 'train';

username = 'demouser'
password = `pass esxi.home/demouser`.chomp
viserver = '10.0.0.10'

foo = Train.create('vmware', viserver: viserver, username: username, password: password).connection
#target_config  = Train.target_config(target: "vmware://#{username}:#{password}@#{viserver}")
#foo = Train.create('vmware', target_config).connection

things = [
  { cmd: 'echoz 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'echo 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'Get-ChildItem | select Name', output: ''}, # Test pipe
  { cmd: 'Get-VMhost | Get-VMHostService | Where {$_.key -eq "TSM-SSH" -and $_.running -eq $False}', output: ''}, # Test pipe
]

things.each do |thing|
  cmd = foo.run_command(thing[:cmd])
  puts 'CMD: ' + thing[:cmd]
  puts 'STDOUT: ' + cmd.stdout
  puts 'STDERR: ' + cmd.stderr
  puts 'EXIT_STATUS: ' + cmd.exit_status.to_s
  puts
  puts "========================================================"
end

puts foo.platform.name
puts foo.platform.release

# puts foo
