# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed

- Bumped modules' default Gemfile simp-beaker-helpers version to `= 1.22.1`

### Fixed

- (SIMP-9519) GLCI RELENG checks use pup6+ `pdk build` to test-build modules
  - This replaces the previous (and EOL) pup5 + `puppet module build`

### Added

- Add various directories to `.pmtignore` to better support `pdk build`

## [SIMP-9408] - 2021-03-02

### Changed

- :warning: Converted Bolt project to Bolt 3.0+
  - Moved `site-modules/` to `modules/`
  - Removed `Puppetfile`, modules are now defined in `bolt-project.yaml` and
    installed with `bolt module install`
  - Updated `Rakefile install` to reflect recent changes
- :warning: Puppetsync configuration is now managed as Hiera data
  - `puppetsync_planconfig.yaml` has been replaced by `data/sync/config/*.yaml`
  - `Puppetfile.repos` has been replaced by `data/sync/repolists/*.yaml`
- :warning: Invoking puppetsync now requires  `config=` and `repolist=`
  parameters:

  ```sh
  bolt plan run puppetsync config=SIMP-9239 repolist=rubygems
  ```

  - Both `config=` and `repolist=` default to `latest`, so it is possible to
    duplicate the old behavior by symlinking each parameter's `latest.yaml`
    file in Hiera to the current Puppetsync session's files:

    ```sh
    # ONLY when `data/sync/config/latest.yaml` and
    # `data/sync/repolists/latest.yaml` are pointed to the correct files!
    bolt plan run puppetsync
    ```

  - PROTIP: Make sure both `latest.yaml` files are symlinked to the correct
    targets before handing off a Puppetsync session to be mass-approved!

- The main `puppetsync` plan now requires a new environment variable,
  `GITLAB_API_TOKEN`, which should contain a private API token with `api`
  scope.  This is now required to access GitLab's CI Lint API:
  https://gitlab.com/gitlab-org/gitlab/-/issues/321290

### Fixed

- (SIMP-9399) GHA: Forked pupmod & rubygem repos no longer try to release on tag
- (SIMP-9400) GHA: Rubygem releases now validate that .gem version matches tag
- (SIMP-9407) GHA: Fixed jq quote bug while reading gems' `workflows.local.json`
- Customized simp-cli's GHA workflows so it won't try to publish releases to
  rubygems.org

### Added

- New 'filter_permitted_repos' option for `puppetsync::` plans
- Prepared puppetsync to handle misc `simp-*` repos (type `simp_unknown`)
- (SIMP-9407) GHA: Rubygem override file now provides `gem_pkg_dir`

## [SIMP-9239] - 2021-02-05

### Added

- (SIMP-9239) GHA CLI workflows for RubyGems

### Changed

- Moved repolists and configs into Hiera

### Fixed

- GitHub actions now use password-less sudo with `apt-get`

### Removed

- (SIMP-9239) Removed `.travis.yml` from RubyGems
- Removed Travis-related files and classes

## [SIMP-9266] - 2021-01-29

### Added

- GHA: GLCI trigger workflows now use
  [`github-action-gitlab-ci-pipeline-trigger@v1`](https://github.com/simp/github-action-gitlab-ci-pipeline-trigger)
- GHA: GLCI trigger workflows now use
  [`github-action-gitlab-ci-syntax-check@v1`](https://github.com/simp/github-action-gitlab-ci-syntax-check)
- New option key, `github_api_delay_seconds`

### Changed

- `.gitlab-ci.yml`: Collapse GLCI logspam during `&setup_bundler_env`
- `.gitlab-ci.yml`: (SIMP-9279) `.fixtures.yml` changes trigger acceptance
  tests

### Fixed

- GHA: (SIMP-9226) GLCI trigger now smart enough to NOT cancel + restart
  existing [pipelines](pipelines) for identical hashrefs
- 'bolt-project.yaml` no longer tries to write to logs under
  `~/.puppetlabs/bolt/`, because it causes errors for users who don't have that
  directory.

### Removed


## [SIMP-9126] - 2021-01-26

### Added

- GHA: (SIMP-9126) Add GitHub actions workflows to `role::pupmod`
- New project_types:
  - `rubygem`
  - `unknown_simp` (unidentified repos that start with `simp-`)
- New roles:
  - `role::rubygem`
  - `role::unknown_with_ci`

### Changed

- `.gitlab-ci.yml`: Collapse GLCI logspam during `&setup_bundler_env`
- All project_types use `profile::obsoletes`,

### Fixed

- (SIMP-9149) `Gemfile` pins pathspec to `~> 0.2` when Ruby < 2.6
- `hiera.yaml` uses the correct repo name with `repos/*.yaml`

### Removed

- (SIMP-9150) No more `.travis.yml` file in Puppet modules

## [SIMP-8958] - 2020-12-15

### Added

- GLCI: (SIMP-8958) `rvm use` sets ruby version when RVM is present
- GLCI: (SIMP-8984) Changed latest pup anchor to `pup_<maj>x`
- GLCI: (SIMP-8984) Changed pinned pup anchor to `pup_<maj>_pe`
- `.gitignore` ignores local tmp droppings (thanks, @DavidS!)
- `bolt-project.yaml` defaults to `concurrency: 10` (thanks, @DavidS!)
- GLCI: New `pup_7` anchor,in `gitlab-ci.yml`, introduces Puppet 7 support

### Changed

- GLCI: (SIMP-8994) More files trigger spec and acceptance tests
- Bumped Pupmod Gemfiles' minimum 'simp-beaker-helpers' version to 1.21.4
- Bumped `pup_5_pe` PUPPET_VERSION to 5.5.22

### Removed

- (SIMP-8839) Removed EL6 from Puppet modules' metadata, hiera, and nodesets
- (SIMP-8931) No more `.ruby-version` file in Puppet modules

## [SIMP-8703] - 2020-12-15

### Changed

- [SIMP-8703] Disabled all testing in modules' Travis CI pipelines
- Updated `.gitlab-ci.yml` from Puppet 6.16.0 to 6.18.0
- Updated `.travis.yml` from Puppet 6.10 to 6.18
- Updated PE LTS EOL versions in `.gitlab-ci.yml` and `.travis.yml`
- Added puppetsync management notice to static files

## [SIMP-7855] - 2020-08-11

### Changed

- In `.gitlab-ci.yaml`:
  - Updated `.gitlab-ci.yml` to Puppet 5.5.20 to match PE 2018.1 LTS
  - Moved pup5/pup6 (latest) unit tests to `with_SIMP_SPEC_MATRIX_LEVEL_2`

### Fixed

- Reintroduced missing `--no-parameter_order-check` to `.puppet-lint.rc`


## [SIMP-8139] - 2020-08-03

### Added

- `role::pupmod` now manages common files: `.gitignore`,
  `.gitattributes`, `.puppet-lint.rc`, `.ruby-version`, `.pmtignore`
- `role::pupmod` now removes obsolete files: `spec/manifests/site.pp`,
  `spec/fixtures/manifests/site.pp`
- README now has a Troubleshooting section


## [SIMP-7974] - 2020-07-30

### Added

- Features for `.gitlab-ci.yaml`:
  - spec and acceptance tests only run if relevant files have changed
  - CI variables `SIMP_MATRIX_LEVEL` and `SIMP_FORCE_MATRIX`
  - CI commit message directives `CI: SKIP MATRIX`, `CI MATRIX LEVEL [0123]`

### Fixed

- `puppetsync::modernize_gitlab_files` is now idempotent

### Removed

- `.gitlab-ci.yaml` CI variable `SIMP_FULL_MATRIX` (existing instances
  converted to run jobs when `SIMP_MATRIX_LEVEL` == 3

## [SIMP-7977] - 2020-07-17

### Added

- `pupmod_skeleton` project type
  - `role::pupmod_skeleton` class
  - `Puppetfile.skeleton`
- Skeleton-friendly `pupmod::` profiles accept paths as parameters

### Changed

- The `$puppetsync::puppet_role` parameter is now optional
  - If left undefined, a Hiera lookup a `classes` is used for each Target
  - `puppet_role` is optional in `puppetsync_planconfig.yaml`

### Fixed

- The plans `puppetsync::approve_github_prs` and `puppetsync::merge_github_prs`
  now install any task-required gems while executing the plan
  - Result: There's no more need to manually add the `extra_gem_path=` argument

## [SIMP-7848] - 2020-07-16

- Last version before changelog

[SIMP-7848]: https://github.com/op-ct/puppetsync/releases/tag/SIMP-7848
[SIMP-7977]: https://github.com/op-ct/puppetsync/compare/SIMP-7848...SIMP-7977
[SIMP-7974]: https://github.com/op-ct/puppetsync/compare/SIMP-7977...SIMP-7974
[SIMP-8139]: https://github.com/op-ct/puppetsync/compare/SIMP-7974...SIMP-8139
[SIMP-7855]: https://github.com/op-ct/puppetsync/compare/SIMP-8139...SIMP-7855
[SIMP-8703]: https://github.com/op-ct/puppetsync/compare/SIMP-7855...SIMP-8703
[SIMP-8958]: https://github.com/op-ct/puppetsync/compare/SIMP-8703...SIMP-8958
[SIMP-9126]: https://github.com/op-ct/puppetsync/compare/SIMP-8958...SIMP-9126
[SIMP-9266]: https://github.com/op-ct/puppetsync/compare/SIMP-9126...SIMP-9266
[SIMP-9239]: https://github.com/op-ct/puppetsync/compare/SIMP-9266...SIMP-9239
[SIMP-9408]: https://github.com/op-ct/puppetsync/compare/SIMP-9239...SIMP-9408
[Unreleased]: https://github.com/op-ct/puppetsync/compare/SIMP-9408...HEAD
