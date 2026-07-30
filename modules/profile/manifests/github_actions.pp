# GitHub actions
#
# Specific repos can provide their own customized file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_github/workflows/{workflow_name}.{repo_name}.yml
#
# @param mode
#   `enforce` (default): workflow files are fully managed — puppetsync is
#   still the delivery mechanism for workflow changes. NOTE: the `uses:`
#   action refs in these files are Renovate-managed, so an `enforce` sync
#   can revert Renovate's bumps until the in-place merge stage exists
#   (simp/puppetsync#50); switch to `bootstrap` per project_type in Hiera
#   once that lands.
class profile::github_actions(
  Stdlib::Absolutepath $target_github_actions_dir = "${::repo_path}/.github/workflows",
  Optional[String[1]]  $target_repo_name = $facts.dig('module_metadata','name'),
  Array[String] $present_action_files = [],
  Array[String] $absent_action_files = [
    'pr_glci.yml', 'pr_glci_cleanup.yml', 'pr_glci_manual.yml',
  ],
  Enum['enforce','bootstrap'] $mode = 'enforce',
){
  $project_type = $facts.dig('project_type').lest || {'unknown'}
  $project_type2 = $project_type == 'pupmod_skeleton' ? {
    true    => 'pupmod',
    default => "NO_PROJECT_TYPE_FOR_${project_type}",
  }

  file{ [$target_github_actions_dir, dirname($target_github_actions_dir)]: ensure => directory }

  $absent_action_files.each |$action_file| {
    file{ "${target_github_actions_dir}/${action_file}": ensure => absent }
  }

  $present_action_files.each |$action_file| {
    $action = basename( $action_file, '.yml' )
    profile::managed_file{ "${target_github_actions_dir}/${action_file}":
      mode    => $mode,
      content => file(
        "${module_name}/${project_type}/_github/workflows/${action}.${target_repo_name}.yml",
        "${module_name}/${project_type}/_github/workflows/${action}.yml",
        "${module_name}/${project_type2}/_github/workflows/${action}.yml",
        "${module_name}/_github/workflows/${action}.${target_repo_name}.yml",
        "${module_name}/_github/workflows/${action}.yml"
      ),
    }
  }
}
