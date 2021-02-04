# GitHub actions
#
# Specific repos can provide their own customized file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_github/workflows/{workflow_name}.{repo_name}.yml
#
class profile::github_actions(
  Stdlib::Absolutepath $target_github_actions_dir = "${::repo_path}/.github/workflows",
  Optional[String[1]]  $target_repo_name = $facts.dig('module_metadata','name'),
  Array[String] $present_action_files = [
    # PR-triggered GLCI actions (+ a manual trigger for external contributors)
    'pr_glci.yml', 'pr_glci_cleanup.yml', 'pr_glci_manual.yml',
  ],
  Array[String] $absent_action_files = [],
){
  $project_type = $facts.dig('project_type').lest || {'unknown'}

  file{ [$target_github_actions_dir, dirname($target_github_actions_dir)]: ensure => directory }

  $absent_action_files.each |$action_file| {
    file{ "${target_github_actions_dir}/${action_file}": ensure => absent }
  }

  $present_action_files.each |$action_file| {
    $action = basename( $action_file, '.yml' )
    file{ "${target_github_actions_dir}/${action_file}":
      content => file(
        "profile/${project_type}/_github/workflows/${action}.${target_repo_name}.yml",
        "profile/${project_type}/_github/workflows/${action}.yml",
        "profile/_github/workflows/${action}.${target_repo_name}.yml",
        "profile/_github/workflows/${action}.yml"
      ),
    }
  }
}
