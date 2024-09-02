require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
  t.libs.push "lib"
end

desc "Generate an epub from a Royal Road URL"
task :run do
  url = ENV["url"]
  if url.nil? || url == ""
    puts "Must provide url. Example usage: `bundle exec rake run url=https://www.royalroad.com/...`"
    exit 1
  end
  require_relative "lib/main"
  Main.new.run(url)
end

desc "Cleans the cache"
task :clean_cache do
  rm_r FileList["cache/*"] - FileList["cache/.gitkeep"]
end
