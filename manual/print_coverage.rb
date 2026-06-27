require 'simplecov'
require 'simplecov-console'

# 1. Setup SimpleCov to read old coverage data from the specified directory
# By default, SimpleCov uses the "coverage" directory, so if you changed it, make sure to update this path.
SimpleCov.coverage_dir('./public/coverage')
# We should set a longer timeout for merging results, by default it's 600 seconds (10 minutes), but you can adjust it based on your needs.
SimpleCov.merge_timeout(3600)

# 2. Set the formatter to Console (or MultiFormatter if you want both HTML and Console)
SimpleCov.formatter = SimpleCov::Formatter::Console

# 3. Read the latest coverage result from .resultset.json
# SimpleCov::ResultMerger.merged_result will load and merge old results
begin
  result = SimpleCov::ResultMerger.merged_result

  if result.nil?
    puts "No previous coverage data found in ./public/coverage/"
    exit 1
  end

  # 4. Use the Console formatter to print the results to the console
  # We can directly initialize it and call format like how SimpleCov does internally
  formatter = SimpleCov::Formatter::Console.new
  formatter.format(result)
rescue => e
  puts "Error reading coverage results: #{e.message}"
end
