# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),

<!-- ## [Unreleased] -->

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

[Unreleased]: https://github.com/op-ct/puppetsync/compare/SIMP-7977...HEAD
[SIMP-7848]: https://github.com/op-ct/puppetsync/releases/tag/SIMP-7848
[SIMP-7977]: https://github.com/op-ct/puppetsync/compare/SIMP-7848...SIMP-7977
[SIMP-7974]: https://github.com/op-ct/puppetsync/compare/SIMP-7977...SIMP-7974
