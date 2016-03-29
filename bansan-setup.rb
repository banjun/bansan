require 'xcodeproj'

f = Dir.glob("*.xcodeproj").first
p = Xcodeproj::Project.open f
t = p.targets.first
if t.build_phases.any?{|p| p.respond_to?(:name) && p.name.include?("bansan check")} then
  puts "bansan check already installed to #{t.name}."
  exit 0
end
puts "add bansan check build phase to #{t.name}..."
t.new_shell_script_build_phase("👀 bansan check").tap{|b|
  b.shell_path = '/bin/zsh'
  b.show_env_vars_in_log = '0'
  b.shell_script = <<-EOS
if which bansan >/dev/null; then
  bansan ${SRCROOT}/**/*.swift
else
  echo "warning: bansan does not exist, download from https://github.com/banjun/bansan"
fi
EOS
}
p.save

