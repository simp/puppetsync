# Build localhost repo Targets from GitHub PR records (as returned by the
# `puppetsync::list_github_prs` task), for the approve/merge plans.
#
# Mirrors puppetsync::repo_targets_from_repolist's target construction, with
# each target's branch taken from its PR's base ref.
#
# @param prs
#   PR records: [{repo => <owner/name>, number => <int>, base => <branch>}]
#
# @return [Array[Target]] repo Targets
function puppetsync::repo_targets_from_prs(
  Array[Hash] $prs,
) {
  $localhost = get_target('localhost')
  $prs.map |$pr| {
    $name = $pr['repo'].split('/')[-1]
    $target = Target.new('name' => $name)
    $target.set_var('repo_url_path', $pr['repo'])
    $target.set_var('pr_number', $pr['number'])
    $target.set_var('mod_data', {
      'branch'    => $pr['base'],
      'repo_name' => $name,
      'git_url'   => "https://github.com/${pr['repo']}",
    })
    $target.set_config( ['transport'], $localhost.config.dig('transport'))
    $target.set_config(
      ['local', 'interpreters', '.rb'],
      $localhost.config.dig('local', 'interpreters', '.rb')
    )
    $target.set_config(
      ['local', 'tmpdir'], $localhost.config.dig('local', 'tmpdir')
    )
    $target.set_var('puppetsync_stage_results', Hash({}))
    $target
  }
}
