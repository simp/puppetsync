#!/opt/puppetlabs/bolt/bin/ruby
#
# Refresh GitHub Actions workflow files from their baseline templates while
# preserving the Renovate-managed values already in the repo.
#
# The template text is canonical — structure, jobs, comments, and formatting
# all come from it byte-for-byte. The only things carried over from the
# existing file are the scalar values of `preserve_keys` (action refs,
# container image tags, ruby versions, ...), including any trailing
# comment — pinned-digest conventions keep the human-readable version there.
#
# Matching pairs occurrences of the same key + identity positionally, where
# the identity is the part of the value Renovate never changes:
#
#   uses:  actions/checkout@v5      -> identity 'actions/checkout'
#   image: ghcr.io/foo/builder:8    -> identity 'ghcr.io/foo/builder'
#   ruby-version: '3.2'             -> no identity (paired per key)
#
# Values new in the template keep the template's value; entries that
# vanished from the template vanish from the file. Scalars are located via
# Psych's node line/column info, so this needs no YAML re-serialization:
# template comments and formatting can't be disturbed by construction.
# See simp/puppetsync#50.
#
# `preserve_blocks` extends the same idea to whole mapping subtrees: the
# EXISTING file is authoritative for each dot-path (e.g. 'jobs.acceptance').
# Its block replaces the template's wholesale; when the template lacks the
# block it is appended to the parent; and when the EXISTING file lacks it,
# the template's block is REMOVED — the template must not introduce a
# repo-owned section (an acceptance job would be dead weight on a module
# with no acceptance suites). A removed job is also dropped from every
# other job's `needs:`, since GitHub rejects a workflow whose `needs:`
# names a job that doesn't exist (the template's aggregate check job
# needs every job, acceptance included).
#
# `refresh_identities` names identities (e.g. 'ruby/setup-ruby') whose values
# come from the template even when the repo already has one, including inside
# `preserve_blocks`: the way a session deliberately changes a preserved value,
# such as moving an action from a branch ref to a release tag, without
# touching the repo's other Renovate-managed values. An occurrence the
# template has no counterpart for (e.g. in a repo-owned block) takes the
# template's first value for that identity.

require 'fileutils'
require 'json'
require 'psych'

DEFAULT_PRESERVE_KEYS = %w[uses image container ruby-version runs-on].freeze

# All scalar values of the given mapping keys, in document order, as
# [mapping_path, key, value_node] triples. The path contains mapping key
# names only (sequence positions are deliberately excluded, so steps can be
# reordered within a job without losing their values).
def preserved_scalars(node, keys, path = [], acc = [])
  case node
  when Psych::Nodes::Mapping
    node.children.each_slice(2) do |key, value|
      key_name = key.is_a?(Psych::Nodes::Scalar) ? key.value : '?'
      acc << [path.join('.'), key_name, value] if keys.include?(key_name) && value.is_a?(Psych::Nodes::Scalar)
      preserved_scalars(value, keys, path + [key_name], acc)
    end
  when Psych::Nodes::Stream, Psych::Nodes::Document, Psych::Nodes::Sequence
    node.children.each { |child| preserved_scalars(child, keys, path, acc) }
  end
  acc
end

# The part of a value Renovate never changes (nil when the whole value is
# the managed part, e.g. a bare version)
def identity(value)
  if value.include?('@')
    value.split('@', 2).first
  elsif value.match?(%r{\A[\w./:-]+:[\w.-]+\z})
    # image:tag, including ported registries (registry:5000/foo:8) — the
    # identity is everything before the final (tag) colon
    value.rpartition(':').first
  end
end

# { [path, key, identity] => [raw rest-of-line starting at the scalar
#   (value + trailing comment, exactly as written), ...] in document order }
def existing_values(text, keys)
  lines = text.split("\n", -1)
  preserved_scalars(Psych.parse(text), keys).each_with_object(Hash.new { |h, k| h[k] = [] }) do |(path, key, node), map|
    next unless node.start_line == node.end_line

    map[[path, key, identity(node.value)]] << lines[node.start_line][node.start_column..]
  end
end

# The document root mapping of a YAML text (nil when empty/scalar)
def root_mapping(text)
  doc = Psych.parse(text)
  root = doc && doc.root
  root.is_a?(Psych::Nodes::Mapping) ? root : nil
end

# [key_node, value_node] at a dot-path of mapping keys, or nil
def node_at_path(root, path)
  key_node = nil
  node = root
  path.split('.').each do |segment|
    return nil unless node.is_a?(Psych::Nodes::Mapping)

    pair = node.children.each_slice(2).find { |k, _v| k.is_a?(Psych::Nodes::Scalar) && k.value == segment }
    return nil unless pair

    key_node, node = pair
  end
  [key_node, node]
end

# Make the existing file authoritative for whole blocks: splice its version
# over the template's, append it when the template lacks it, or remove the
# template's when the existing file has none (Psych spans:
# key.start_line ... value.end_line, exclusive)
def preserve_existing_blocks(template, existing_text, paths)
  preserved = []
  removed = []
  existing_lines = existing_text.split("\n", -1)
  existing_root = root_mapping(existing_text)

  paths.each do |path|
    existing_pair = existing_root && node_at_path(existing_root, path)
    template_lines = template.split("\n", -1)
    template_root = root_mapping(template)
    next if template_root.nil?

    template_pair = node_at_path(template_root, path)
    if existing_pair.nil?
      # Repo has no such block; the template must not introduce one
      next if template_pair.nil?

      template_lines[template_pair[0].start_line...template_pair[1].end_line] = []
      removed << path
    elsif template_pair
      block = existing_lines[existing_pair[0].start_line...existing_pair[1].end_line]
      next if template_lines[template_pair[0].start_line...template_pair[1].end_line] == block

      template_lines[template_pair[0].start_line...template_pair[1].end_line] = block
    else
      block = existing_lines[existing_pair[0].start_line...existing_pair[1].end_line]
      parent_path = path.split('.')[0..-2].join('.')
      parent_pair = parent_path.empty? ? [nil, template_root] : node_at_path(template_root, parent_path)
      next if parent_pair.nil? || !parent_pair[1].is_a?(Psych::Nodes::Mapping)

      template_lines.insert(parent_pair[1].end_line, *block)
    end
    preserved << path
    template = template_lines.join("\n")
  end

  [template, preserved, removed]
end

# Drop the named jobs from every job's `needs:` (a scalar, a flow sequence
# on one line, or a block sequence with one item per line), removing the
# `needs:` key entirely when nothing is left. One edit per pass, re-parsing
# after each so line/column positions stay valid.
def prune_needs(template, job_names)
  return template if job_names.empty?

  loop do
    jobs = (root = root_mapping(template)) && node_at_path(root, 'jobs')
    return template unless jobs && jobs[1].is_a?(Psych::Nodes::Mapping)

    lines = template.split("\n", -1)
    edit = jobs[1].children.each_slice(2).lazy.map { |_name, job|
      needs = job.is_a?(Psych::Nodes::Mapping) && node_at_path(job, 'needs')
      next unless needs

      key, value = needs
      names = value.is_a?(Psych::Nodes::Sequence) ? value.children.map(&:value) : [value.value]
      kept = names - job_names
      next if kept == names

      if kept.empty?
        # A one-line value ends on the key's own line
        lines[key.start_line...[value.end_line, key.start_line + 1].max] = []
      elsif value.is_a?(Psych::Nodes::Sequence) && value.style == Psych::Nodes::Sequence::BLOCK
        drop = value.children.reject { |item| kept.include?(item.value) }.map(&:start_line)
        lines = lines.reject.with_index { |_l, i| drop.include?(i) }
      else
        line = lines[value.start_line]
        lines[value.start_line] = line[0...value.start_column] + "[#{kept.join(', ')}]" + line[value.end_column..]
      end
      lines.join("\n")
    }.find(&:itself)
    return template if edit.nil? || edit == template

    template = edit
  end
end

# The template's values for a refreshed identity at this [path, key,
# identity], or its first value for the identity anywhere when this context
# only exists in the repo (a preserved block the template lacks)
def template_refresh(template_values, id)
  list = template_values.fetch(id, [])
  return list unless list.empty?

  template_values.select { |(_path, _key, ident), _values| ident == id[2] }.values.flatten.first(1)
end

def merge_workflow(template, existing_text, keys, blocks, refresh = [])
  # Read before preserve_blocks splices repo content into the template
  template_values = refresh.empty? ? {} : existing_values(template, keys)
  template, preserved_blocks, removed_blocks = preserve_existing_blocks(template, existing_text, blocks)
  removed_jobs = removed_blocks.filter_map { |path| path.delete_prefix('jobs.') if path.match?(/\Ajobs\.[^.]+\z/) }
  template = prune_needs(template, removed_jobs)
  existing = existing_values(existing_text, keys)
  lines = template.split("\n", -1)
  updated = []

  # Pair occurrences positionally per [path, key, identity], so a value only
  # carries over when the same job/step context still has it — per-occurrence
  # differences (distinct versions per job, trailing comments) survive
  # verbatim. Template entries with no counterpart in the existing file
  # (a genuinely new or restored step) keep the template's value.
  # Refreshed identities take the template's values instead.
  counters = Hash.new(0)
  preserved_scalars(Psych.parse(template), keys).each do |path, key, node|
    next unless node.start_line == node.end_line

    id = [path, key, identity(node.value)]
    list = refresh.include?(id[2]) ? template_refresh(template_values, id) : existing[id]
    value = list[counters[id]] || list.last
    counters[id] += 1
    next if value.nil?

    line = lines[node.start_line]
    next if line[node.start_column..] == value

    lines[node.start_line] = line[0...node.start_column] + value
    updated << "#{key}: #{value.split(/\s+#/).first}"
  end

  [lines.join("\n"), updated, preserved_blocks]
end

def merge_gha_workflows(workflows, keys, blocks, refresh = [])
  results = {}
  workflows.each do |wf|
    path = wf.fetch('path')
    template = wf.fetch('template')

    unless File.exist?(path)
      # ensure_files can target a repo with no .github/workflows/ at all
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, template)
      results[path] = { 'changed' => true, 'created' => true }
      next
    end

    existing_text = File.read(path)
    merged, updated, preserved_blocks = merge_workflow(template, existing_text, keys, blocks, refresh)

    if merged == existing_text
      results[path] = { 'changed' => false }
    else
      File.write(path, merged)
      results[path] = { 'changed' => true, 'preserved_values' => updated, 'preserved_blocks' => preserved_blocks }
    end
  end

  { 'changed' => results.values.any? { |r| r['changed'] }, 'files' => results }
end

stdin = STDIN.read
params = JSON.parse(stdin)

workflows = params['workflows']
raise('No workflows given') unless workflows.is_a?(Array)
keys = params.fetch('preserve_keys', nil) || DEFAULT_PRESERVE_KEYS
blocks = params.fetch('preserve_blocks', nil) || []
refresh = params.fetch('refresh_identities', nil) || []

puts JSON.generate(merge_gha_workflows(workflows, keys, blocks, refresh))
