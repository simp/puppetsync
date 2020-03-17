#!/bin/bash

# This script
#   - updates
#
#

# Halt on errors
set -e

#                     T  G
# - [x] ssh          [x][x] https://gitlab.com/simp/pupmod-simp-ssh/pipelines/35533505
# - [x] polkit       [x][x] https://gitlab.com/simp/pupmod-simp-polkit/pipelines/35533507
# - [x] sssd         [x][x] https://gitlab.com/simp/pupmod-simp-sssd/pipelines/35533512
# - [x] sudo         [x][x] https://gitlab.com/simp/pupmod-simp-sudo/pipelines/35533517
# - [x] sudosh       [x][x] https://gitlab.com/simp/pupmod-simp-sudosh/pipelines/35533519
# - [x] tcpwrappers  [x][x] https://gitlab.com/simp/pupmod-simp-tcpwrappers/pipelines/35533522
# - [x] tftpboot     [x][x] https://gitlab.com/simp/pupmod-simp-tftpboot/pipelines/35533525
# - [x] resolv       [x][x] https://gitlab.com/simp/pupmod-simp-resolv/pipelines/35533529
# - [x] simpcat      [x][x] https://gitlab.com/simp/pupmod-simp-simpcat/pipelines/35533533
# - [x] openldap     [x][x] https://gitlab.com/simp/pupmod-simp-simp_openldap/pipelines/35533014
# - [x] pupmod       [x][r] https://gitlab.com/simp/pupmod-simp-pupmod/pipelines/35533017

#export REPOS=(pupmod-simp-{ssh,polkit,sssd,sudo,sudosh,tcpwrappers,tftpboot})
#export REPOS=(pupmod-simp-{resolv,simpcat,simp_openldap,pupmod})
#export REPOS=(pupmod-simp-{simp_openldap,pupmod})

#export REPOS=(pupmod-simp-{ssh,polkit,sssd,sudo,sudosh,tcpwrappers,tftpboot,resolv,simpcat,simp_openldap,pupmod})
#export REPOS=(pupmod-simp-{pam,pki,postfix,rsync,rsyslog,selinux,simplib,simp_apache,simp_banners,stunnel})
#export REPOS=(pupmod-simp-{simp_rsyslog,svckill,swap,tpm,tuned,upstart,useradd,xinetd})
#export REPOS=(pupmod-simp-{simp_gitlab,simp_elasticsearch,simp_docker,openscap,libvirt})
#export REPOS=(pupmod-simp-simp)
export REPOS=(pupmod-simp-simp_apache)

function banner()
{
  echo "== $*"
}

simpdev_gitremote()
{
  name="$(basename "$(pwd)")"
  git remote -v
  hub fetch op-ct || ( hub fork "simp/${name}" && hub fetch op-ct )
  hub config hub.protocol https
  git remote remove origin
  hub fetch simp
  git remote rename simp upstream
  git remote -v | grep fetch | sed -e 's/ (fetch)//' | column -t
  hub config hub.protocol git
  git remote remove op-ct
  hub remote add op-ct
  git remote add gitlab-simp git@gitlab.com:simp/${name}
  git remote add gitlab-opct git@gitlab.com:chris.tessmer/${name}
  hub config hub.protocol https
}

function clone_repos()
{
  banner 'clone repos '
  cwd="$(pwd)"
  for i in "${@}"; do
    echo "   -- $i                (cwd: $(basename $cwd))"
    cd "${cwd}"
    simpdev_gitremote $i
    cd "${cwd}"
  done
  echo "   +++++                (cwd: $(basename $cwd))"
  cd "${cwd}"
}

function update_gemfile()
{
  banner "$1 - Updating Gemfile"
  sed -i.$(date '+%Y%m%d%H%M%S') \
      -e "s/^.*PUPPET_VERSION.*$/  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 5.5')/g" \
      -e "s/^.*SIMP_RSPEC_PUPPET_FACTS_VERSION.*$/  gem 'simp-rspec-puppet-facts', ENV.fetch('SIMP_RSPEC_PUPPET_FACTS_VERSION', '~> 2.2')/g" \
       -e "s/^.*SIMP_BEAKER_HELPERS_VERSION.*$/  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 1.12')/g" \
       -e "s/^.*SIMP_RAKE_HELPERS_VERSION.*$/  gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 5.6')/g" \
       -e "s/^.*gem 'beaker'.*$/  gem 'beaker'/g" \
       -e "s/^.*PUPPET_VERSION.*$/  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 5.5')/" \
      Gemfile
}

function update_rubyversion()
{
  banner "$1 - Updating .ruby-version"
  [ -f .ruby-version ] && cp -p .ruby-version "$backup_dir/"
  echo 2.4.4 > .ruby-version
}

update_gitlabyml()
{
  banner "$1 - updating .gitlab-ci.yml"
  ls -la
  [ -f .gitlab-ci.yml ] && cp -p .gitlab-ci.yml "$backup_dir/"

  # only keep acceptance tests + below
  awk 'BEGIN {found = 0} {if (found || $0 ~ /^# Acceptance/) {found = 1; print}}' .gitlab-ci.yml > .gitlab-ci.yml.acc

  if [ "$(stat --printf="%s" .gitlab-ci.yml.acc)" == 0 ]; then
    echo "**** no acceptance test pipeline found"
    if ! find spec/acceptance -name \*_spec.rb &> /dev/null; then
      echo "**** no acceptance tests found"
      if ! egrep '^# Acceptance' .gitlab-ci.yml &> /dev/null; then
        echo "**** Adding boilerplate no acceptance tests message to pipelines"
        cat "${files_dir}/no-acceptance-tests-msg.yml" > .gitlab-ci.yml.acc
      fi
    fi
  fi

  # sanitize test names
  sed -i -e 's/-acceptance:\s*$/:/g' \
      -e 's/-compliance:\s*$/:/g' \
      -e 's/^default-/pup5.5.7-/g' \
      -e 's/^default:\s*$/pup5.5.7:/g' \
      -e 's/^pup5.5.7-puppet5:\s*$/pup4.10:/g' \
      -e 's/-compliance:\s*$/:/g' \
      .gitlab-ci.yml.acc

  # cat files together
  cat "${files_dir}/gitlab-ci.common.yml" .gitlab-ci.yml.acc > .gitlab-ci.yml

  # sanitize anchor names
  sed -i -e 's/\<pup_4_10_X\>/pup_4_10/g' \
    -e 's/\<acceptance_test\>/acceptance_base/g' \
    -e 's/\<acceptance_tests\>/acceptance_base/g' \
    .gitlab-ci.yml
}

lint_gitlabyml()
{
  banner "$1 - Linting $(pwd)/.gitlab-ci.yml"
  export GITLAB_CI_URL="${GITLAB_CI_URL:-https://gitlab.com/api/v4/ci/lint}"
  rake --rakefile  "${files_dir}/gitlabci_lint.rake"  gitlab_ci:lint
}

update_travisyml()
{
  banner "$1 - updating .travis.yml"
  cp -p .travis.yml "$backup_dir/"

  egrep '^    - stage: deploy\s*$' .travis.yml &> /dev/null
  # only keep acceptance tests + below
  awk 'BEGIN {found = 0} {if (found || $0 ~ /^    - stage: deploy\s*$/) {found = 1; print}}' .travis.yml > .travis.yml.acc

  # cat files together
  cat "${files_dir}/travis.common.yml" .travis.yml.acc > .travis.yml
}

lint_compliance_tests()
{
  banner "$1 - linting compliance tests"
  # if there's an oel test, ensure that there's an oel nodeset
  if [ -d spec/acceptance/suites/compliance ] && \
    find spec/acceptance/suites/compliance -name \*_spec.rb &> /dev/null; then
    if ! grep "beaker:suites\[compliance\>" .gitlab-ci.yml &> /dev/null; then
      echo
      echo "ERROR: compliance _spec.rb files exist, but $1/.gitlab-ci.yml does not contain beaker:suites[compliance]"
      exit 33
    fi
    echo "OK: compliance _spec.rb files exist, beaker:suites[compliance] exists"
  fi
}


lint_beaker_suites()
{
  banner "$1 - linting beaker:suites"
  if grep "beaker:suites\[.*\>" .gitlab-ci.yml &> /dev/null ; then
    echo "    -- beaker:suites in $1/.gitlab-ci.yml:"
    for suite in $(grep "beaker:suites\[.*\>" .gitlab-ci.yml | \
      egrep -v '^\s*#' | \
      sed -e 's/.*\[\([0-9a-z_-]*\)[^0-9a-z_-].*$\?/\1/' | \
      sort -u ); do
      echo "     * $suite"
      if ! find spec/acceptance/suites/$suite -name \*_spec.rb &> /dev/null; then
        echo
        echo "ERROR:  $1/.gitlab-ci.yml contains beaker:suites[$suite], but no _spec.rb files exist under spec/acceptance/suites/$suite/*_spec.rb files exist."
        exit 44
      fi
    done
  fi
}

ensure_oel_nodeset()
{
  banner "$1 - updating oel nodesets"
  # if there's an oel test, ensure that there's an oel nodeset
  if grep 'beaker:suites..*,oel.' .gitlab-ci.yml &> /dev/null; then
    for ns_dir in ./spec/acceptance/nodesets spec/acceptance/suites/default/nodesets; do
        if [ ! -f "$ns_dir/oel.yml" ]; then
        echo "========= ensureing OEL.yml in $ns_dir"
        sed -e 's@centos/7@onyxpoint/oel-7-x86_64@g' -e 's@centos/6@onyxpoint/oel-6-x86_64@g' "$ns_dir/default.yml" > "$ns_dir/oel.yml"
      fi
    done
  fi
}

function process_repos()
{
  cwd="$(pwd)"
  files_dir="${cwd}/files"
  for i in "${@}"; do
    run_date="$(date '+%Y%m%d%H%M%S')"
    backup_dir="${cwd}/.backups/$i/$run_date"
    mkdir -p "${backup_dir}"

    cd "${cwd}/$i"
    pwd
#    update_gemfile $i
#    update_rubyversion $i
    update_gitlabyml $i
    lint_gitlabyml $i
#    update_travisyml $i
#    ensure_oel_nodeset $i

    # our own sanity lints:
    lint_compliance_tests $i
    lint_beaker_suites $i
    echo "----------------------------------------"
    echo
    echo
    cd "${cwd}"
  done
}

function git_commit()
{
  banner "$1 - git commit"
  name="$(echo $1 |  sed -e 's/^.*-\([^-]*\)$/\1/')"
  BRANCH_NAME="SIMP-5585-ensure-puppet5-assets"
  git checkout -b "$BRANCH_NAME" 2>/dev/null || :

  # prepare commit message
  sed -e "s/MODNAME/$name/g" "${files_dir}/git_commit_message.txt" > ./git_commit_message.txt
  if ! find spec/acceptance -name \*_spec.rb; then
    sed -e "s/MODNAME/$name (no acceptance test)/g" "${files_dir}/git_commit_message.txt" > ./git_commit_message.txt
    echo "SIMP-5632 #comment Added pup5 test assets to $name (no acceptance test)" >> ./git_commit_message.txt
  fi
  git add .travis.yml .gitlab-ci.yml .ruby-version Gemfile

  [ -f ./spec/acceptance/nodesets/oel.yml ] && git add ./spec/acceptance/nodesets/oel.yml

  cat ./git_commit_message.txt
  git lg -3 | cat
  if [[ "$(git lg -1)" =~ "(SIMP-5585)" ]]; then
    echo git commit --amend -F ./git_commit_message.txt
    git commit --amend -F ./git_commit_message.txt
    git push op-ct "$BRANCH_NAME" --force
    git push gitlab-simp "$BRANCH_NAME" --force
  else
    echo git commit -F ./git_commit_message.txt
    git commit -F ./git_commit_message.txt
    git push op-ct "$BRANCH_NAME"
    git push gitlab-simp "$BRANCH_NAME"
  fi

}

function gitcommit_repos()
{
  cwd="$(pwd)"
  files_dir="${cwd}/files"
  for i in "${@}"; do
    run_date="$(date '+%Y%m%d%H%M%S')"
    backup_dir="${cwd}/.backups/$i/$run_date"
    mkdir -p "${backup_dir}"
    cd "$i"
    git_commit $i
    cd "${cwd}"
  done
  cd "${cwd}"
}

top_dir="$(pwd)"
    run_date="$(date '+%Y%m%d%H%M%S')"
    files_dir="$(realpath $top_dir/../../../files)"
    backup_dir="$(realpath $top_dir/../.backups/$i/$run_date)"
    base_name="$(basename "$top_dir")"
echo "  top_dir:   '${top_dir}'"
echo "  files_dir: '${files_dir}'"
echo "  backup_dir '${backup_dir}'"
echo "  pwd:       $PWD"
echo "  base_name: $base_name"
    test -d "$files_dir" || echo ERROR: no files_dir at "$files_dir"
    mkdir -p "${backup_dir}"
    update_gitlabyml $base_name
    bundle
    lint_gitlabyml $base_name
clone_repos "${REPOS[@]}"
exit 9
cd "${top_dir}"
process_repos "${REPOS[@]}"
cd "${top_dir}"
#gitcommit_repos "${REPOS[@]}"
cd "${top_dir}"
banner 'FIN!'


