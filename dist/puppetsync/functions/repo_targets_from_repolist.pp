# Builds a collection of localhost Targets from repolist data
#
# @summary Builds a collection of localhost Targets from repolist data
#
# @param repo_config
#   Data structure with repos and branches
#
# @param inventory_group
#   Name of inventory group for the repo Targets
#
# @param default_moduledir
#   Path to directory where repos will be cloned
#
# @param project_dir
#   The bolt project directory.
#
# @return [TargetSpec] the repo Targets read from the Puppetfile
#
function puppetsync::repo_targets_from_repolist(
  Hash $repos_config,
  String[1] $inventory_group,
  Stdlib::Absolutepath $project_dir,
  String[1] $default_moduledir                  = '_repos',
) {
  $pf_repos = Hash($repos_config.map |$url, $data| {
    [
      $url.basename,
      {
        'git_url'      => $url,
        'name'         => $url.basename,
        'rel_path'     => "${default_moduledir}/${url.basename}",
        ###'mod_rel_path' => "${default_moduledir}/${url.basename}",  #  .split(/[-\/]/)[-1],
        ### 'install_path' => $default_moduledir,
        ###'mod_name'     => $url.basename,
        'repo_name'    => $url.basename('.git'),  # used by function template_git_commit_message()
        'branch'       => $data['branch'],
      }
    ]
  })

  # add a localhost Target for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $repos = $pf_repos.map |$mod, $mod_data| {
    warning("% ${mod}")
    warning($mod_data.to_yaml.regsubst('^','  ','G'))

    $target = Target.new('name' => $mod_data['name'])
    $target.set_var('mod_data', $mod_data )

    $repo_path     = "${project_dir}/${mod_data['rel_path']}"
    $repo_url_path = $mod_data['git_url'].regsubst('https?://[^/]+/?', '' ,'I')
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
    $target
  }.filter |$t| { $t }
  warning("repos.count=${repos.count}")
  return( $repos )
}
