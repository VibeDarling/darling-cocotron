require 'tmpdir'
root=File.expand_path('..',__dir__)
source=File.read("#{root}/AppKit/NSBitmapImageRep.m")
start=source.index('- initWithBitmapDataPlanes:') or abort 'initializer missing'
finish=source.index('- initWithBitmapDataPlanes:',start+1) or abort 'overload missing'
initializer=source[start...finish]
start=source.index('- (void) dealloc {') or abort 'dealloc missing'
finish=source.index('- (int) incrementalLoadFromData:',start) or abort 'dealloc boundary missing'
dealloc=source[start...finish]
test=File.read("#{__dir__}/bitmap-allocation-failure.m")
test=test.sub('// ACTUAL_METHODS',initializer+dealloc)
if ARGV.empty?
  puts test
  exit
end
Dir.mktmpdir('bitmap-allocation-probe-') do |dir|
  path="#{dir}/probe.m"
  File.write(path,test)
  abort 'build failed' unless system({'COCOTRON_DIR'=>root},'ruby',ARGV.fetch(0),path)
end
