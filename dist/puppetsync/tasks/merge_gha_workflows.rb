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

def merge_workflow(template, existing_text, keys)
  existing = existing_values(existing_text, keys)
  lines = template.split("\n", -1)
  updated = []

  # Pair occurrences positionally per [path, key, identity], so a value only
  # carries over when the same job/step context still has it — per-occurrence
  # differences (distinct versions per job, trailing comments) survive
  # verbatim. Template entries with no counterpart in the existing file
  # (a genuinely new or restored step) keep the template's value.
  counters = Hash.new(0)
  preserved_scalars(Psych.parse(template), keys).each do |path, key, node|
    next unless node.start_line == node.end_line

    id = [path, key, identity(node.value)]
    list = existing[id]
    value = list[counters[id]] || list.last
    counters[id] += 1
    next if value.nil?

    line = lines[node.start_line]
    next if line[node.start_column..] == value

    lines[node.start_line] = line[0...node.start_column] + value
    updated << "#{key}: #{value.split(/\s+#/).first}"
  end

  [lines.join("\n"), updated]
end

def merge_gha_workflows(workflows, keys)
  results = {}
  workflows.each do |wf|
    path = wf.fetch('path')
    template = wf.fetch('template')

    unless File.exist?(path)
      File.write(path, template)
      results[path] = { 'changed' => true, 'created' => true }
      next
    end

    existing_text = File.read(path)
    merged, updated = merge_workflow(template, existing_text, keys)

    if merged == existing_text
      results[path] = { 'changed' => false }
    else
      File.write(path, merged)
      results[path] = { 'changed' => true, 'preserved_values' => updated }
    end
  end

  { 'changed' => results.values.any? { |r| r['changed'] }, 'files' => results }
end

stdin = STDIN.read
params = JSON.parse(stdin)

workflows = params['workflows']
raise('No workflows given') unless workflows.is_a?(Array)
keys = params.fetch('preserve_keys', nil) || DEFAULT_PRESERVE_KEYS

puts JSON.generate(merge_gha_workflows(workflows, keys))
