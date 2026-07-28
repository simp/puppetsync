# Helpers for exercising puppetsync's Bolt tasks as standalone scripts.
#
# The tasks are plain Ruby scripts that read their parameters as JSON on
# stdin, so they can be tested without Bolt by running them as subprocesses.
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

REPO_ROOT = File.expand_path('..', __dir__)
TASKS_DIR = File.join(REPO_ROOT, 'dist', 'puppetsync', 'tasks')

# Run a task script the way Bolt does: parameters as JSON on stdin.
# @return [Array(String, String, Process::Status)] stdout, stderr, status
def run_task(task_file, params)
  Open3.capture3(RbConfig.ruby, File.join(TASKS_DIR, task_file), stdin_data: JSON.generate(params))
end
