# Manage Puppet module skeleton
#
# pupmod_skeleton is always identical to pupmod, but in Hiera it prefixes all
# the file paths to `skeleton/` and overrides the paths to local
# templates/files.
#
# The Hiera file where this happens is:
#   `data/project_types/pupmod_skeleton.yaml`
#
class role::pupmod_skeleton {
  include 'role::pupmod'
}
