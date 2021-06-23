# Static .gitlab-ci.yml file for Puppet modules.
#
# There are two components of SIMP .gitlab-ci.yml pipelines:
#
#   1. The standardized CI pipeline for SIMP Puppet modules
#     - e.g., Cache, stages, YAML anchors, most jobs EXCEPT acceptance tests
#     - This section should be static across all module repositories
#
#   2. Repo-specific CI content
#     - Jobs that provide acceptance and compliance tests
#     - These jobs vary from repo to repo, and are managed directly in
#       repository
#
# This profile enforces the standardized content in `.gitlab-ci.yml`, but also
# persists existing repo-specific content.  The repo-specific content must be
# defined below the following two lines:
#
#  ```
#  # Repo-specific content
#  # ========================================================================
#  ```
#
# @param existing_pipeline_content
#   The content of the module's existing `.gitlab-ci.yml` file, used to detect
#   and perist local changes.
#
#   * By default, this content read directly from the target's `$::repo_path` on
#     the local filesystem.
#   * If the target doesn't have a `.gitlab-ci.yml` file, default starter
#     content will be sourced from this module.
#
#   Target-specific content will be detected by searching for a specific lines
#   (see the profile's documentation for an example)
#
#   Anything below those lines will be saved, and added to Puppet-managed
#   template.
#
class profile::pupmod::gitlab_ci(
  Stdlib::Absolutepath $target_gitlabci_yml_path = "${::repo_path}/.gitlab-ci.yml",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){

  # NOTE: as noted above, the default value first attempts to read in the
  # target's existing `.gitlab-ci.yml`.  This allows us to persist
  # locally-managed, repo-specific pipeline content while keeping the resource
  # idempotent.
  #
  # In idiomatic Puppet, this content would need to be read on a remote
  # target by a custom fact.  But--since we're running from the puppetsync Bolt
  # plan--we know each target repo is on the same localhost filesystem as the
  # Bolt compiler, and we can simply read it directly.
  #
  # The `file()` function only attempts to read content from the second
  # (default) file if the target's `gitlab-ci.yaml` file doesn't exist.
  $existing_pipeline_content = file(
    $target_gitlabci_yml_path,
    "${module_name}/pupmod/_gitlab-ci.blank_repo_section.yml"
  )

  # Capture everything from the existing file under the lines:
  #
  #    # Repo-specific content
  #    # ========================================================================
  #
  # TODO simplify the regex after all modules are consistent with the template
  $pipeline_components = $existing_pipeline_content.split(
    /^# (?i:Repo-specific(?: pipeline)? content|Acceptance tests)\s*(?:\n#)?\n# *(?:=|-){40,}\s*$/
  )
  if $pipeline_components.count > 1 {
    $repo_specific_content = $pipeline_components[1,-1].join("\n")
  } else {
    $repo_specific_content = file("${module_name}/pupmod/_gitlab-ci.blank_repo_section.yml")
  }

  $gitlab_ci_template_path = find_template(
    "${module_name}/pupmod/_gitlab-ci.yml.${target_module_name}.epp",
    "${module_name}/pupmod/_gitlab-ci.yml.epp"
  )

  file{ $target_gitlabci_yml_path:
    content => epp(
      $gitlab_ci_template_path, {
        'repo_specific_content' => $repo_specific_content,
      }
    ),
  }
}
