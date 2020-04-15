# Builds a collection of localhost Targets from a Puppetfile's git repos
#
# (Ignores any `mod` entry that does not have a `:git` repo)
#
# @summary Builds a collection of localhost Targets from a Puppetfile's git repos
#
# @param puppetfile
#   A special Puppetfile containing `mod` entries with :git repos
#
# @param inventory_group
#   Name of inventory group for the repo Targets
#
# @param default_moduledir
#   Path to directory where repos will be cloned
#
# @param exclude_repos_from_other_module_dirs
#   When `true`, drops any repo with a moduledir or installpath that is
#   different from `default_moduledir`.
#
# @param project_dir
#   The bolt project directory.
#
# @return [TargetSpec] the repo Targets read from the Puppetfile
#
#
function puppetsync::repo_targets_from_puppetfile(
  Stdlib::Absolutepath $puppetfile,
  String[1] $inventory_group,
  String[1] $default_moduledir                  = '_repos',
  Boolean $exclude_repos_from_other_module_dirs = true,
  Stdlib::Absolutepath $project_dir             = dirname($puppetfile),
) {
  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile_data = file::read($puppetfile)

  $pf_mods                = puppetsync::parse_puppetfile($puppetfile_data, $default_moduledir)
  $pf_alt_moduledir_repos = $pf_mods.filter |$mod, $mod_data| {
    $mod_data['install_path'] != $default_moduledir
  }

  if !$pf_alt_moduledir_repos.empty {
    warning( @("END")
      ====== WARNING: found repos with moduledir != '$default_moduledir':
      ${pf_alt_moduledir_repos.map |$k,$v|{ "  - ${v['name']}:\t${k}" }.join("\n")}
    END
  )}

  if $exclude_repos_from_other_module_dirs {
    if !$pf_alt_moduledir_repos.empty {
      warning( "====== WARNING: REJECTING the non-default moduledir repos, because \$exclude_repos_from_other_module_dirs=true" )
    }
    $pf_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] == $default_moduledir }
  } else {
    $pf_repos = $pf_mods
  }

  # add a localhost Target for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $pf_repos.each |$mod, $mod_data| {
    warning("% ${mod}")
    warning($mod_data.to_yaml.regsubst('^','  ','G'))

    if ('git' in $mod_data){
      $target = Target.new('name' => $mod_data['name'])
      $target.add_to_group( $inventory_group )
      $target.set_var('mod_data', $mod_data )

      $repo_path     = "${project_dir}/${mod_data['mod_rel_path']}"
      $repo_url_path = $mod_data['git'].regsubst('https?://[^/]+/?', '' ,'I')
      $target.set_var('repo_path', $repo_path )
      $target.set_var('repo_url_path', $repo_url_path )

      # Use the same ruby interpreter the 'localhost' target is using (which is
      # automagically configured by bolt to point to its own ruby executable)
      # This keeps the inventory as cross-platform as possible
      $localhost = get_target('localhost')
      $target.set_config( ['transport'], $localhost.config.dig('transport'))
      $target.set_config(
        ['local', 'interpreters', '.rb'],
       $localhost.config.dig('local', 'interpreters', '.rb')
      )
      $target.set_config(
        ['local', 'tmpdir'], $localhost.config.dig('local', 'tmpdir')
      )
      $target.set_var('puppetsync_stage_results',Hash({}))
    } else {
      warning( "====== WARNING: REJECTING Puppetfile 'mod' entry '${mod}' - it is **NOT** a :git repo" )
    }
  }
  $repos = get_targets($inventory_group)
  warning("repos.count=${repos.count}")
  return( $repos )
}
