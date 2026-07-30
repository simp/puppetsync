# @summary Manage a baseline file in a target repo
#
# @param content
#   Full file content
#
# @param mode
#   How the file is managed:
#
#   * `enforce` (default) ― content is fully managed; local changes are
#     always overwritten by the next sync
#   * `bootstrap` ― lay down the complete file only if it does not exist
#     yet. Use this for files whose values are maintained in place after
#     creation (e.g. version pins managed by Renovate), so a sync never
#     clobbers them. (In-place structural updates are handled separately —
#     see the merge stages planned in simp/puppetsync#50.)
#
# @param path
#   Absolute path of the file to manage (defaults to the resource title)
define profile::managed_file (
  String                      $content,
  Enum['enforce','bootstrap'] $mode = 'enforce',
  Stdlib::Absolutepath        $path = $title,
) {
  file { $path:
    content => $content,
    replace => $mode ? { 'bootstrap' => false, default => true },
  }
}
