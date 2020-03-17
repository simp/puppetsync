warning( "\$::repo_path = '${::repo_path}'" )
warning( "\$::module_metadata = '${::module_metadata}'" )
warning( "\$::module_metadata = '${::module_metadata['forge_org']}'" )

if !$facts.dig('repo_path') {
  fail ( 'The fact $::repo_path must be defined!  Hint: use `rake apply`' )
}

lookup('classes', {'value_type'    => Array[String],
                  'merge'         => 'unique',
                  'default_value' => [],
                  }).include
