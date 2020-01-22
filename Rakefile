require 'rake/testtask'

task_files = FileList.new('lib/tasks/*.rake')
task_files.each { |filepath| load filepath }

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/test_*.rb']
end

task default: :test
