# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"

class CheckRepositoryPolicyMergeCommitTest < ActiveSupport::TestCase
  CHECKER = Rails.root.join("bin/check_repository_policy").to_s

  setup do
    @dir = Dir.mktmpdir("check-repo-policy-merge-")
    run_git("init", "-b", "main")
    run_git("config", "user.email", "test@example.com")
    run_git("config", "user.name", "Test User")
  end

  teardown do
    FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
  end

  test "accepts a GitHub style merge commit while auditing its non-merge commits" do
    commit("chore: establish base", "- Establish the base\n", "base.txt" => "base\n")
    base = head_sha

    run_git!("checkout", "-b", "feature")
    commit("feat: add feature", "- Add the feature\n", "feature.txt" => "feature\n")

    run_git!("checkout", "main")
    commit("docs: update main", "- Update main documentation\n", "main.txt" => "main\n")
    merge_feature

    output, _error, status = run_checker("HEAD", base)

    assert status.success?, output
  end

  test "still rejects an invalid non-merge commit inside a merged range" do
    commit("chore: establish base", "- Establish the base\n", "base.txt" => "base\n")
    base = head_sha

    run_git!("checkout", "-b", "feature")
    commit("not conventional", "plain body", "feature.txt" => "feature\n")
    invalid_sha = head_sha

    run_git!("checkout", "main")
    commit("docs: update main", "- Update main documentation\n", "main.txt" => "main\n")
    merge_feature

    output, _error, status = run_checker("HEAD", base)

    assert_not status.success?
    assert_includes output, invalid_sha
    assert_match(/subject not conventional/, output)
    assert_match(/body has no bullet line/, output)
  end

  private

  def run_git(*args, env: {})
    Open3.capture3(env, "git", *args, chdir: @dir)
  end

  def run_git!(*args, env: {})
    output, error, status = run_git(*args, env: env)
    assert status.success?, "git #{args.join(' ')} failed:\n#{output}\n#{error}"
    output
  end

  def commit(subject, body, files)
    files.each do |path, content|
      FileUtils.mkdir_p(File.join(@dir, File.dirname(path)))
      File.write(File.join(@dir, path), content)
    end

    run_git!("add", "-A")
    run_git!("commit", "-m", subject, "-m", body)
  end

  def merge_feature
    run_git!(
      "merge",
      "--no-ff",
      "feature",
      "-m",
      "Merge pull request #11 from example/feature",
      "-m",
      "Example feature"
    )
  end

  def head_sha
    run_git!("rev-parse", "HEAD").chomp
  end

  def run_checker(*args)
    Open3.capture3(CHECKER, *args, chdir: @dir)
  end
end
