require 'helper'
require 'fileutils'
require 'eventmachine'

TEST_DIR = '/tmp/emdwtest' # Dir.mktmpdir

class TestTreeFileList < Test::Unit::TestCase
  
  def setup
    FileUtils.rm_rf TEST_DIR
    FileUtils.mkdir_p TEST_DIR
  end

  should "should be empty for an empty directory" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    assert_equal "", @tree.full_file_list.join(", ").strip
  end

  should "should return a single file" do
    FileUtils.touch File.join(TEST_DIR, 'foo')

    @tree = EMDirWatcher::Tree.new TEST_DIR
    assert_equal "foo", @tree.full_file_list.join(", ").strip
  end

  should "should return a file in a subdirectory" do
    FileUtils.mkdir File.join(TEST_DIR, 'bar')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo')

    @tree = EMDirWatcher::Tree.new TEST_DIR
    assert_equal "bar/foo", @tree.full_file_list.join(", ").strip
  end

  should "should return a sorted list of files" do
    FileUtils.touch File.join(TEST_DIR, 'aa')
    FileUtils.touch File.join(TEST_DIR, 'zz')
    FileUtils.mkdir File.join(TEST_DIR, 'bar')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo')

    @tree = EMDirWatcher::Tree.new TEST_DIR
    assert_equal "aa, bar/foo, zz", @tree.full_file_list.join(", ").strip
  end

end

class TestTreeExcludes < Test::Unit::TestCase

  def setup
    FileUtils.rm_rf TEST_DIR
    FileUtils.mkdir_p TEST_DIR

    FileUtils.mkdir File.join(TEST_DIR, 'bar')
    FileUtils.mkdir File.join(TEST_DIR, 'bar', 'boo')

    FileUtils.touch File.join(TEST_DIR, 'aa')
    FileUtils.touch File.join(TEST_DIR, 'biz')
    FileUtils.touch File.join(TEST_DIR, 'zz')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'biz')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'biz.html')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'boo', 'bizzz')

    @list = ['aa', 'biz', 'zz', 'bar/foo', 'bar/biz', 'bar/biz.html', 'bar/boo/bizzz'].sort
  end

  def join list
    list.join(", ").strip
  end

  should "ignore a single file excluded by path" do
    @tree = EMDirWatcher::Tree.new TEST_DIR, ['bar/biz']
    assert_equal join(@list - ['bar/biz']), join(@tree.full_file_list)
  end

  should "ignore files excluded by name" do
    @tree = EMDirWatcher::Tree.new TEST_DIR, ['biz']
    assert_equal join(@list - ['biz', 'bar/biz']), join(@tree.full_file_list)
  end

  should "ignore files excluded by name glob" do
    @tree = EMDirWatcher::Tree.new TEST_DIR, ['biz*']
    assert_equal join(@list - ['biz', 'bar/biz', 'bar/biz.html', 'bar/boo/bizzz']), join(@tree.full_file_list)
  end

  should "ignore a directory excluded by name glob" do
    @tree = EMDirWatcher::Tree.new TEST_DIR, ['bo*']
    assert_equal join(@list - ['bar/boo/bizzz']), join(@tree.full_file_list)
  end

  should "ignore a files and directories excluded by regexp" do
    @tree = EMDirWatcher::Tree.new TEST_DIR, [/b/]
    assert_equal join(['aa', 'zz']), join(@tree.full_file_list)
  end

end

class TestTreeRefreshing < Test::Unit::TestCase

  def setup
    FileUtils.rm_rf TEST_DIR
    FileUtils.mkdir_p TEST_DIR

    FileUtils.mkdir File.join(TEST_DIR, 'bar')
    FileUtils.mkdir File.join(TEST_DIR, 'bar', 'boo')

    FileUtils.touch File.join(TEST_DIR, 'aa')
    FileUtils.touch File.join(TEST_DIR, 'biz')
    FileUtils.touch File.join(TEST_DIR, 'zz')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'biz')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'biz.html')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'boo', 'bizzz')

    @list = ['aa', 'biz', 'zz', 'bar/foo', 'bar/biz', 'bar/biz.html', 'bar/boo/bizzz'].sort
  end

  def join list
    list.join(", ").strip
  end

  should "no changes when nothing has changed" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    changed_paths = @tree.refresh!
    assert_equal "", join(changed_paths)
    assert_equal join(@list), join(@tree.full_file_list)
  end

  should "single file modification" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    sleep 1
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/foo']), join(changed_paths)
  end

  should "single file deletion" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.rm File.join(TEST_DIR, 'bar', 'biz')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/biz']), join(changed_paths)
  end

  should "single directory deletion" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.rm_rf File.join(TEST_DIR, 'bar')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/foo', 'bar/biz', 'bar/biz.html', 'bar/boo/bizzz'].sort), join(changed_paths)
  end

  should "single file creation" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.touch File.join(TEST_DIR, 'bar', 'miz')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/miz']), join(changed_paths)
  end

  should "single directory creation" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.mkdir File.join(TEST_DIR, 'bar', 'koo')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'koo', 'aaa')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'koo', 'zzz')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/koo/aaa', 'bar/koo/zzz'].sort), join(changed_paths)
  end

  should "not report changes on empty directory creation" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.mkdir File.join(TEST_DIR, 'bar', 'koo')
    changed_paths = @tree.refresh!
    assert_equal "", join(changed_paths)
  end

  should "files turned into a directory" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.rm File.join(TEST_DIR, 'bar', 'foo')
    FileUtils.mkdir File.join(TEST_DIR, 'bar', 'foo')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo', 'aaa')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'foo', 'zzz')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/foo', 'bar/foo/aaa', 'bar/foo/zzz'].sort), join(changed_paths)
  end

  should "directory turned into a file" do
    @tree = EMDirWatcher::Tree.new TEST_DIR
    FileUtils.rm_rf File.join(TEST_DIR, 'bar', 'boo')
    FileUtils.touch File.join(TEST_DIR, 'bar', 'boo')
    changed_paths = @tree.refresh!
    assert_equal join(['bar/boo/bizzz', 'bar/boo'].sort), join(changed_paths)
  end

end
