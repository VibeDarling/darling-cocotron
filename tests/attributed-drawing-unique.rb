# Guard against two category implementations competing for public selectors.
root = File.expand_path('..', __dir__)
selectors = %w[drawAtPoint drawInRect drawWithRect size]
counts = Hash.new(0)
Dir[File.join(root, 'AppKit', '**', '*.m')].each do |path|
  File.read(path).scan(/@implementation NSAttributedString\b(.*?)@end/m).each do |body|
    body.first.scan(/^-\s*\([^\n)]*\)\s*(\w+)\s*[:{]/).each do |match|
      counts[match.first] += 1 if selectors.include?(match.first)
    end
  end
end
selectors.each do |selector|
  abort "#{selector}: expected one implementation, found #{counts[selector]}" unless counts[selector] == 1
end
puts 'PASS: one NSAttributedString implementation per public drawing selector'
