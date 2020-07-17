# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),

## [Unreleased]

### Added

- `pupmod_skeleton` project type
  - `role::pupmod_skeleton` class
  - `Puppetfile.skeleton`
- Skeleton-friendly `pupmod::` profiles accept paths as parameters

### Changed

- The `$puppetsync::puppet_role` parameter is now optional
  - If left undefined, a Hiera lookup a `classes` is used for each Target
  - `puppet_role` is optional in `puppetsync_planconfig.yaml`

## [SIMP-7848] - 2020-07-16

- Last version before changelog

[Unreleased]: https://github.com/op-ct/puppetsync/compare/SIMP-7848...HEAD
[SIMP-7848]: https://github.com/op-ct/puppetsync/releases/tag/SIMP-7848
