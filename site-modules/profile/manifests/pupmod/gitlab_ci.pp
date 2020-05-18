# Static .gitlab-ci.yml file for Puppet modules.
#
# There are two components of SIMP .gitlab-ci.yml pipelines:
#
#   1. The standardized CI pipeline for SIMP Puppet modules
#     - e.g., Cache, stages, YAML anchors, most jobs EXCEPT acceptance tests
#     - This section should be static across all module repositories
#
#   2. Repo-specific CI jobs
#     - acceptance tests and compliance tests
#
#
class profile::pupmod::gitlab_ci {
  $existing_pipeline_content = file(
    "${::repo_path}/.gitlab-ci.yml",
    "${module_name}/pupmod/_gitlab-ci.blank_repo_section.yml"
  )

  # Capture everything from the existing file under the lines:
  #
  #    # Repo-specific content
  #    # ========================================================================
  #
  # NOTE In idiomatic Puppet, this content would be provided by a fact.  But we
  # assume we're on a localhost target, so we can do this.
  #
  # TODO simplify ithe regex after all modules are consistent with the template
  $pipeline_components = $existing_pipeline_content.split(
     /^# (?i:Repo-specific(?: pipeline)? content|Acceptance tests)\s*\n# *(?:=|-){40,}\s*$/
  )

  if $pipeline_components.count > 1 {
    $repo_specific_content = $pipeline_components[1,-1].join("\n")
  } else {
    $repo_specific_content = file("${module_name}/pupmod/_gitlab-ci.blank_repo_section.yml")
  }

  file{ "${::repo_path}/.gitlab-ci.yml":
    content => epp(
      "${module_name}/pupmod/_gitlab-ci.yml.epp", {
        'repo_specific_content' => $repo_specific_content,
      }
    ),
  }
}
