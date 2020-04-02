# This class manages EVERY repository you check out, so be careful
class profile::common {
  $org = $facts.dig('module_metadata','forge_org')
  if $org { notify{"======== org: ${org}":} }

}
