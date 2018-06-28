require 'train';
# foo = Train.create('vmware', viserver: '10.0.0.10', username: 'demouser', password: 'nope').connection
target_config  = Train.target_config(target: 'vmware://demouser:nope@10.0.0.10')
foo = Train.create('vmware', target_config).connection

things = [
  { cmd: 'echoz 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'echo 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'echo 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'echo 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
  { cmd: 'echo 1', output: '' },
  { cmd: 'Get-ChildItem', output: ''},
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
