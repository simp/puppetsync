# This class manags EVERY repository you check out
class profile::common {
  $org = $facts.dig('module_metadata','forge_org')
  if $org {
     notify{"======== ${org}":}
  }

}
