# Static .gitlab-ci.yml file for Puppet modules.
class profile::pupmod::gitlab_ci {
  $repo_content_rel_path = '.gitlab-ci-acceptance.repo.yml'

  $repo_content = file(
    "${facts['sync_metadata_dir']}/${repo_content_rel_path}",
    "${module_name}/pupmod/_gitlab-ci.default.repocontent.yml"
  )

  file{ "${::repo_path}/.gitlab-ci.yml":
    content => epp(
      "${module_name}/pupmod/_gitlab-ci.yml.epp",
      { 'repo_specific_content' => $repo_content }
    ),
  }
}
