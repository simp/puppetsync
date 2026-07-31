#!/opt/puppetlabs/bolt/bin/ruby
#
# Merge the baseline Gemfile template into an existing Gemfile IN PLACE:
#
#   - Gems from the template that are missing from the target are added to
#     the matching `group ... do` block (created at EOF when absent),
#     together with any comment lines attached to them in the template
#   - Gems in `remove_gems` are deleted (along with an attached
#     `# renovate:` comment line)
#   - Everything else — most importantly the version constraints of gems
#     that already exist, which Renovate manages — is left untouched
#
# If the target file does not exist, the full template is written out
# (bootstrap behavior; see simp/puppetsync#50).

require 'json'

GEM_LINE_RE = /^\s*gem\s*\(?\s*['"](?<name>[\w.-]+)['"]/
GROUP_RE    = /^\s*group\s+(?<sig>.+?)\s+do\s*$/
# Statement block openers that require a matching `end` (inline modifiers
# like `gem 'x' if cond` deliberately don't match)
OPENER_RE   = /(\bdo\s*(\|[^|]*\|)?\s*(#.*)?$)|(^\s*(if|unless|case|begin|module|class|def)\b)/
END_RE      = /^\s*end\b/
# Local variable assignments (e.g. `puppet_version = ENV.fetch(...)`) that
# gem lines may reference; excludes == and =~
ASSIGN_RE   = /^\s*(?<var>[a-z_]\w*)\s*=(?![=~])/

# Parse Gemfile text into:
#   groups: { normalized_signature => { start:, end: } }  (top-level groups only)
#   gems:   { gem_name => { index:, group: normalized_signature_or_nil } }
def parse_gemfile(lines)
  groups = {}
  gems = {}
  stack = []

  lines.each_with_index do |line, idx|
    if (m = line.match(GEM_LINE_RE))
      enclosing_group = stack.reverse.find { |frame| frame[:group] }
      gems[m[:name]] ||= { index: idx, group: enclosing_group&.dig(:sig) }
    end

    if (m = line.match(GROUP_RE))
      sig = m[:sig].strip
      stack.push({ group: true, sig: sig, start: idx })
    elsif line.match?(END_RE)
      frame = stack.pop
      groups[frame[:sig]] = { start: frame[:start], end: idx } if frame && frame[:group] && stack.empty?
    elsif line.match?(OPENER_RE)
      stack.push({ group: false })
    end
  end

  { groups: groups, gems: gems }
end

# Comment lines immediately above index `idx` (attached documentation, e.g.
# `# renovate:` manager hints)
def attached_comments(lines, idx)
  first = idx
  first -= 1 while first.positive? && lines[first - 1].match?(/^\s*#/)
  (first...idx).map { |i| lines[i] }
end

def merge_gemfile(path, template, remove_gems)
  unless File.exist?(path)
    File.write(path, template)
    added = template.split("\n").filter_map { |l| l.match(GEM_LINE_RE)&.[](:name) }
    return { 'changed' => true, 'created' => true, 'added' => added, 'removed' => [] }
  end

  original = File.read(path)
  lines = original.split("\n", -1)
  template_lines = template.split("\n", -1)
  template_parsed = parse_gemfile(template_lines)

  added = []
  removed = []

  # --- Removals ---------------------------------------------------------
  remove_gems.each do |name|
    parsed = parse_gemfile(lines)
    next unless parsed[:gems].key?(name)

    idx = parsed[:gems][name][:index]
    first = idx
    first -= 1 if first.positive? && lines[first - 1].match?(/^\s*#\s*renovate:/)
    lines.slice!(first..idx)
    removed << name
  end

  # --- Additions --------------------------------------------------------
  template_parsed[:gems].each do |name, tmeta|
    next if remove_gems.include?(name)

    parsed = parse_gemfile(lines)
    next if parsed[:gems].key?(name)

    insert_lines = attached_comments(template_lines, tmeta[:index]) + [template_lines[tmeta[:index]]]

    if tmeta[:group].nil?
      # Top-level gem: after the last top-level gem, else before the first
      # group, else EOF
      top_level = parsed[:gems].values.select { |g| g[:group].nil? }.map { |g| g[:index] }
      insert_at = if top_level.any?
                    top_level.max + 1
                  elsif parsed[:groups].any?
                    parsed[:groups].values.map { |g| g[:start] }.min
                  else
                    lines.length
                  end
    elsif (target_group = parsed[:groups][tmeta[:group]])
      group_gems = parsed[:gems].values.select { |g| g[:group] == tmeta[:group] }.map { |g| g[:index] }
      insert_at = group_gems.any? ? group_gems.max + 1 : target_group[:start] + 1
    else
      # Group missing entirely: copy the template's whole block verbatim at
      # EOF (so group-local variable assignments etc. come along)
      tgroup = template_parsed[:groups][tmeta[:group]]
      block = template_lines[tgroup[:start]..tgroup[:end]]
      lines << '' unless lines.last.to_s.empty?
      lines.concat(block + [''])
      added.concat(block.filter_map { |l| l.match(GEM_LINE_RE)&.[](:name) })
      next
    end

    lines.insert(insert_at, *insert_lines)
    added << name

    # Top-level gems have no group body to source assignments from
    next if tmeta[:group].nil?

    # Ensure any group-local variable assignments the inserted lines
    # reference (e.g. `gem 'puppet', puppet_version`) exist in the target.
    # References are transitive (an assignment may reference an earlier
    # one); insert them at the top of the group in template order.
    tgroup = template_parsed[:groups][tmeta[:group]]
    group_body = template_lines[(tgroup[:start] + 1)...tgroup[:end]]
    assignments = group_body.filter_map { |l| (v = l.match(ASSIGN_RE)&.[](:var)) && [v, l] }.to_h

    referenced_text = insert_lines.join("\n")
    needed_vars = []
    loop do
      new_vars = assignments.keys.reject { |v| needed_vars.include?(v) }
                            .select { |v| referenced_text.match?(/\b#{Regexp.escape(v)}\b/) }
      break if new_vars.empty?

      needed_vars.concat(new_vars)
      referenced_text += "\n#{new_vars.map { |v| assignments[v] }.join("\n")}"
    end

    needed = group_body.select do |tline|
      var = tline.match(ASSIGN_RE)&.[](:var)
      var && needed_vars.include?(var) && lines.none? { |l| l.match(ASSIGN_RE)&.[](:var) == var }
    end
    lines.insert(target_group[:start] + 1, *needed) if needed.any?
  end

  content = lines.join("\n")
  changed = content != original
  File.write(path, content) if changed
  { 'changed' => changed, 'added' => added, 'removed' => removed }
end

stdin = STDIN.read
params = JSON.parse(stdin)

raise('No path given') unless params['path']
raise('No template given') unless params['template']
remove_gems = params.fetch('remove_gems', nil) || []

puts JSON.generate(merge_gemfile(params['path'], params['template'], remove_gems))
