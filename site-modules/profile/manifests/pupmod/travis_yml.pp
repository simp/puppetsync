class profile::pupmod::travis_yml {
  file{ "${::repo_path}/.travis.yml":
      content => file('profile/pupmod/_travis.yml'),
  }
}
