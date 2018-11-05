require 'test_helper'

class RepositoryTest < ActiveSupport::TestCase
  test "validation" do
    repository = build(:repository, slug: "Hello")
    assert_equal true, repository.valid?

    repository.slug = "Hello-This_123"
    assert_equal true, repository.valid?

    repository.slug = "Hello This_123"
    assert_equal false, repository.valid?

    repository.slug = "H"
    assert_equal false, repository.valid?
  end

  test "destroy dependent :user_actives" do
    user0 = create(:user)
    user1 = create(:user)
    repo = create(:repository)

    UserActive.track(repo, user: user0)
    UserActive.track(repo, user: user1)
    assert_equal 2, UserActive.where(subject_type: "Repository").count

    repo.destroy
    assert_equal 0, UserActive.where(subject_type: "Repository").count
  end

  test "track user active" do
    user = create(:user)
    repo = create(:repository, creator_id: user.id)
    assert_equal 1, user.user_actives.where(subject: repo).count
    assert_equal 1, user.user_actives.where(subject: repo.user).count
  end

  test "find_by_slug" do
    repository = create(:repository)
    assert_equal repository, Repository.find_by_slug(repository.slug)

    assert_equal "/#{repository.user.slug}/#{repository.slug}", repository.to_path
  end

  test "preferences" do
    repo = create(:repository)
    assert_equal true, repo.preferences[:has_toc]
    assert_equal true, repo.has_toc?

    repo.preferences[:has_toc] = 1
    assert_equal 1, repo.has_toc
    assert_equal true, repo.has_toc?

    repo.has_toc = 0
    assert_equal 0, repo.preferences[:has_toc]
    assert_equal 0, repo.has_toc
    assert_equal false, repo.has_toc?

    repo.has_toc = "1"
    assert_equal true, repo.has_toc?
    repo.has_toc = "true"
    assert_equal true, repo.has_toc?
    repo.has_toc = "0"
    assert_equal false, repo.has_toc?

    repo.save
    repo.reload

    assert_equal({ "has_toc" => "0" }, repo.preferences)
  end

  test "toc_text / toc_html" do
    toc = [{ title: "Hello world", url: "/hello", id: nil, depth: 0 }.as_json].to_yaml.strip
    repo = create(:repository, toc: toc)
    assert_equal toc, repo.toc_text
    assert_html_equal BookLab::Toc.parse(toc).to_html, repo.toc_html
    assert_html_equal BookLab::Toc.parse(toc).to_html(prefix: "/prefix"), repo.toc_html(prefix: "/prefix")

    repo = create(:repository, toc: nil)
    assert_equal [].to_yaml, repo.toc_text

    doc1 = create(:doc, repository: repo)
    toc_hash = [{ title: doc1.title, depth: 0, id: doc1.id, url: doc1.slug }.as_json]
    toc = toc_hash.to_yaml
    assert_equal toc, repo.toc_text
    assert_html_equal BookLab::Toc.parse(toc).to_html, repo.toc_html

    doc2 = create(:doc, repository: repo)
    toc_hash << { title: doc2.title, depth: 0, id: doc2.id, url: doc2.slug }.as_json
    toc = toc_hash.to_yaml
    assert_equal toc, repo.toc_text
    repo = Repository.find(repo.id)
    assert_equal BookLab::Toc.parse(toc).to_html, repo.toc_html
  end

  test "validate toc" do
    toc = "foo\"\"\nsdk"
    repo = build(:repository, toc: toc)
    assert_equal false, repo.valid?
    assert_equal ["Invalid TOC format (required YAML format)."], repo.errors[:toc]

    toc = <<~TOC
    - name: Hello
      slug: hello
    TOC
    repo = build(:repository, toc: toc)
    assert_equal false, repo.valid?
    assert_equal ["Invalid TOC format (required YAML format)."], repo.errors[:toc]

    toc = <<~TOC
    - title: Hello
      url: hello
    TOC
    repo = build(:repository, toc: toc)
    assert_equal true, repo.valid?
  end
end
