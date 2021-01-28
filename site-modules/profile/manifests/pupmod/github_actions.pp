# Static .travis.yml file for Puppet modules.
#
# Specific modules can provide their own .travis.yml file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_github/workflows/{workflow_name}.pupmod-simp-{name}.yml
#
class profile::pupmod::github_actions(
  Stdlib::Absolutepath $target_github_actions_dir = "${::repo_path}/.github/workflows",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
  Array[String] $present_action_files = [
    # PR-triggered GLCI actions (+ a manual trigger for external contributors)
    'pr_glci.yml', 'pr_glci_cleanup.yml', 'pr_glci_manual.yml',
    # PR-triggered Pupmod checks + test matrix
    'pr_tests.yml',
    # Check API tokens
    'validate_tokens.yml',
    # Release on tag
    'tag_deploy.yml',
  ],
  Array[String] $absent_action_files = [],
){
  file{ [$target_github_actions_dir, dirname($target_github_actions_dir)]:
    ensure => directory,
  }

  $absent_action_files.each |$action_file| {
    file{ "${target_github_actions_dir}/$action_file": ensure => absent }
  }

  $present_action_files.each |$action_file| {
    $action_base = basename( $action_file, '.yml' )
    file{ "${target_github_actions_dir}/${action_file}":
      content => file(
        "profile/pupmod/_github/workflows/${action_base}.${target_module_name}.yml",
        "profile/pupmod/_github/workflows/${action_base}.yml",
        "profile/_github/workflows/${action_base}.${target_module_name}.yml",
        "profile/_github/workflows/${action_base}.yml"
      ),
    }
  }
}
