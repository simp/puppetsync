# Fill out the git comment template for specific repo using data from a
# session's puppetsynce_config data
#
# @return [String] Customized git commit message
function puppetsync::template_git_commit_message(
  Target $repo,
  Hash   $puppetsync_config,
){
  $commmit_template = $puppetsync_config.dig('git','commit_message').lest || {
    fail("ERROR: ${repo.name} missing required var ['git']['commit_message']")
  }
  $component_name = $repo.vars['mod_data']['repo_name'].lest || {
    fail("ERROR: ${repo.name} missing required var ['mod_data']['repo_name']")
  }

  $puppetsync_config['git']['commit_message'].regsubst( '%COMPONENT%', $component_name, 'G')
}
