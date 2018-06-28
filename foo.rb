require 'train';
foo = Train.create('vmware', viserver: '10.0.0.10', username: 'demouser', password: 'nope').connection

require 'pry'; binding.pry
things = [
  { cmd: 'echo 1', output: '' },
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
  sleep 0.1
  thing[:output] = foo.run_command(thing[:cmd]).stdout
end

puts foo
