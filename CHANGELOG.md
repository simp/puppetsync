# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- GLCI: (SIMP-8958) `rvm use` sets ruby version when RVM is present
- GLCI: (SIMP-8984) Changed latest pup anchor to `pup_<maj>x`
- GLCI: (SIMP-8984) Changed pinned pup anchor to `pup_<maj>_pe`
- `.gitignore` ignores local tmp droppings (thanks, @DavidS!)
- `bolt-project.yaml` defaults to `concurrency: 10` (thanks, @DavidS!)
- GLCI: New `pup_7` anchor,in `gitlab-ci.yml`, introduces Puppet 7 support

### Changed

- GLCI: (SIMP-8994) More files trigger spec and acceptance testsd
- Bumped Pupmod Gemfiles' minimum 'simp-beaker-helpers' version to 1.21.4

### Removed

- (SIMP-8839) EL6 is removed from Puppet modules' metadata, hiera, and nodesets
- (SIMP-8931) The `.ruby-version` file is removed from Puppet modules

## [SIMP-8703]

### Changed

- [SIMP-8703] Disabled all testing in modules' Travis CI pipelines
- Updated `.gitlab-ci.yml` from Puppet 6.16.0 to 6.18.0
- Updated `.travis.yml` from Puppet 6.10 to 6.18
- Updated PE LTS EOL versions in `.gitlab-ci.yml` and `.travis.yml`
- Added puppetsync management notice to static files

## [SIMP-7855]

### Changed

- In `.gitlab-ci.yaml`:
  - Updated `.gitlab-ci.yml` to Puppet 5.5.20 to match PE 2018.1 LTS
  - Moved pup5/pup6 (latest) unit tests to `with_SIMP_SPEC_MATRIX_LEVEL_2`

### Fixed

- Reintroduced missing `--no-parameter_order-check` to `.puppet-lint.rc`


## [SIMP-8139]

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
[Unreleased]: https://github.com/op-ct/puppetsync/compare/SIMP-8703...HEAD
