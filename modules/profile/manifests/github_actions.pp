# @summary GitHub actions
#
# @param target_github_actions_dir
# @param target_repo_name
# @param present_action_files
# @param absent_action_files
#
# Specific repos can provide their own customized file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_github/workflows/{workflow_name}.{repo_name}.yml
#
class profile::github_actions (
  Stdlib::Absolutepath $target_github_actions_dir = "${::repo_path}/.github/workflows", # lint:ignore:top_scope_facts
  Optional[String[1]]  $target_repo_name = $facts.dig('module_metadata','name'),
  Array[String] $present_action_files = [],
  Array[String] $absent_action_files = [
    'pr_glci.yml', 'pr_glci_cleanup.yml', 'pr_glci_manual.yml',
  ],
) {
  $project_type = $facts.dig('project_type').lest || { 'unknown' }
  $project_type2 = $project_type == 'pupmod_skeleton' ? {
    true    => 'pupmod',
    default => "NO_PROJECT_TYPE_FOR_${project_type}",
  }

  file { [$target_github_actions_dir, dirname($target_github_actions_dir)]: ensure => directory }

  $absent_action_files.each |$action_file| {
    file { "${target_github_actions_dir}/${action_file}": ensure => absent }
  }

  $present_action_files.each |$action_file| {
    $action = basename( $action_file, '.yml' )
    file { "${target_github_actions_dir}/${action_file}":
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
