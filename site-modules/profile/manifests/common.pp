# Management common to EVERY repository (not just modules) ― so be careful!
class profile::common {
  $org = $facts.dig('module_metadata','forge_org')
  if $org { notify{"======== org: ${org}":} }
}
