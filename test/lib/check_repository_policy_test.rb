# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"

class CheckRepositoryPolicyTest < ActiveSupport::TestCase
  CHECKER = Rails.root.join("bin/check_repository_policy").to_s

  setup do
    @dir = Dir.mktmpdir("check-repo-policy-")
    run_git("init")
    run_git("config", "user.email", "test@example.com")
    run_git("config", "user.name", "Test User")
  end

  teardown do
    FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
  end

  def run_git(*args, env: {})
    Open3.capture3(env, "git", *args, chdir: @dir)
  end

  def commit(subject:, body: nil, files: { "README.md" => "# Repo\n" }, author_date: nil, committer_date: nil)
    files.each do |path, content|
      FileUtils.mkdir_p(File.join(@dir, File.dirname(path)))
      File.write(File.join(@dir, path), content)
    end
    run_git("add", "-A")

    args = [ "commit", "-m", subject ]
    args.concat([ "-m", body ]) if body
    env = {}
    if author_date
      env["GIT_AUTHOR_DATE"] = author_date
      env["GIT_COMMITTER_DATE"] = committer_date || author_date
    end
    _out, _err, status = run_git(*args, env: env)
    assert status.success?, "failed to create test commit"
  end

  def head_sha
    out, = run_git("rev-parse", "HEAD")
    out.chomp
  end

  def run_checker(*args)
    Open3.capture3(CHECKER, *args, chdir: @dir)
  end

  test "accepts a valid repository" do
    commit(subject: "feat(auth): add refresh rotation", body: "- Rotate tokens with one successor\n")
    commit(subject: "docs: update usage", body: "- Clarify cookie usage\n", files: {
      ".github/workflows/ci.yml" => "jobs:\n  test:\n    steps:\n      - uses: actions/checkout@v7\n"
    })

    _out, _err, status = run_checker("HEAD")

    assert status.success?
  end

  test "rejects a tracked lockfile" do
    commit(subject: "chore: add lockfile", body: "- Track dependencies\n", files: { "Gemfile.lock" => "GEM\n" })

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/Gemfile\.lock/, out)
  end

  test "rejects a non-conventional subject" do
    commit(subject: "unconventional subject", body: "- Any body\n")

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/subject/, out)
  end

  test "rejects a body without a bullet line" do
    commit(subject: "feat: no bullets", body: "plain paragraph without a dash")

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/bullet/, out)
  end

  test "rejects mismatched author and committer dates" do
    commit(
      subject: "feat: backdated commit",
      body: "- Backdated on purpose\n",
      author_date: "2020-01-01T00:00:00Z",
      committer_date: "2021-01-01T00:00:00Z"
    )

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/author date/, out)
  end

  test "rejects a migration stamped after its commit" do
    commit(
      subject: "feat: add migration",
      body: "- Create the table\n",
      files: { "db/migrate/20260201000000_create_things.rb" => "class CreateThings < ActiveRecord::Migration\nend\n" },
      author_date: "2026-01-01T00:00:00Z"
    )

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/migration/i, out)
  end

  test "rejects a v4 workflow action" do
    commit(subject: "ci: bump actions", body: "- Move to v4\n", files: {
      ".github/workflows/ci.yml" => "jobs:\n  test:\n    steps:\n      - uses: actions/checkout@v4\n"
    })

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/@v4/, out)
  end

  test "rejects a downgraded required action version" do
    commit(subject: "ci: pin checkout", body: "- Pin to v4\n", files: {
      ".github/workflows/ci.yml" => "jobs:\n  test:\n    steps:\n      - uses: actions/upload-artifact@v4\n"
    })

    out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/actions\/upload-artifact/, out)
  end

  test "rejects changes to protected manual files against a base ref" do
    commit(subject: "docs: add manual file", body: "- Add protected file\n", files: { "manual/tracker.md" => "original\n" })
    base = head_sha
    commit(subject: "docs: edit manual file", body: "- Change protected file\n", files: { "manual/tracker.md" => "modified\n" })

    out, _err, status = run_checker("HEAD", base)

    assert_not status.success?
    assert_match(/manual\/tracker\.md/, out)
  end

  test "accepts unchanged protected manual files against a base ref" do
    commit(subject: "docs: add manual file", body: "- Add protected file\n", files: { "manual/tracker.md" => "original\n" })
    base = head_sha
    commit(subject: "feat: app change", body: "- Add app code\n", files: { "app/models/user.rb" => "class User\nend\n" })

    _out, _err, status = run_checker("HEAD")

    assert status.success?
  end

  test "rejects a commit dated in the future" do
    future = (Time.now.utc + 2.days).iso8601
    commit(
      subject: "feat: future-dated",
      body: "- Commit stamped ahead of now\n",
      files: { "future.txt" => "future\n" },
      author_date: future
    )

    _out, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/future/, _out)
  end

  test "rejects modification of a protected manual file" do
    commit(subject: "docs: add manual file", body: "- Add protected file\n", files: { "manual/reference.txt" => "original\n" })
    commit(subject: "docs: edit manual file", body: "- Change protected file\n", files: { "manual/reference.txt" => "changed\n" })

    output, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/manual\/reference\.txt/, output)
  end

  test "rejects deletion of a protected manual file" do
    commit(subject: "docs: add manual file", body: "- Add protected file\n", files: { "manual/reference.txt" => "original\n" })
    FileUtils.rm(File.join(@dir, "manual", "reference.txt"))
    run_git("add", "-A")
    _out, _err, status = run_git("commit", "-m", "chore: remove manual file", "-m", "- Remove protected file")
    assert status.success?, "failed to create removal commit"

    output, _err, status = run_checker("HEAD")

    assert_not status.success?
    assert_match(/manual\/reference\.txt/, output)
  end

  test "allows subsequent changes to Bash manual scripts" do
    commit(subject: "chore: add manual script", body: "- Add Bash script\n", files: { "manual/check.sh" => "#!/usr/bin/env bash\n" })
    commit(subject: "chore: extend manual script", body: "- Add strict mode\n", files: { "manual/check.sh" => "#!/usr/bin/env bash\nset -e\n" })

    _output, _err, status = run_checker("HEAD")

    assert status.success?
  end
end
