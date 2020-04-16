# Summarize a repo target as a printable String
# @return [String] Summary of each Target
function puppetsync::summarize_repo_targets(
  TargetSpec $repos,
  Boolean $verbose = false,
){
  warning( "=@@@@@ repos.type = '${repos.type}'" )
  $t_summ = $repos.map |$idx, $target| {
    $t_idx  = "  [${idx}]: ${target.name}"
    $t_vars = $target.vars.to_yaml.regsubst('^','       ','G')
    $t_facts = $target.facts.to_yaml.regsubst('^','       ','G')
    $verbose ? {
      true    => "${t_idx}\nvars:${t_vars}\nfacts:\n${t_facts}",
      default => $t_idx
    }
  }.join("\n")


  "Targets: ${repos.size}:\n${t_summ}"
}
