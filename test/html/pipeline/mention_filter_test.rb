require "test_helper"

class HTML::Pipeline::MentionFilterTest < Test::Unit::TestCase
  def setup
    @defunkt  = User.make :login => 'defunkt'
    @mojombo  = User.make :login => 'mojombo'
    @kneath   = User.make :login => 'kneath'
    @tmm1     = User.make :login => 'tmm1'
    @atmos    = User.make :login => 'atmos'
    @mislav   = User.make :login => 'mislav'
    @rtomayko = User.make :login => 'rtomayko'
  end

  def filter(html, base_url='/')
    HTML::Pipeline::MentionFilter.call(html, :base_url => base_url)
  end

  def test_filtering_a_documentfragment
    body = "<p>@kneath: check it out.</p>"
    doc  = Nokogiri::HTML::DocumentFragment.parse(body)

    res  = filter(doc, '/')
    assert_same doc, res

    link = "<a href=\"/kneath\" class=\"user-mention\">@kneath</a>"
    assert_equal "<p>#{link}: check it out.</p>",
      res.to_html
  end

  def test_filtering_plain_text
    body = "<p>@kneath: check it out.</p>"
    res  = filter(body, '/')

    link = "<a href=\"/kneath\" class=\"user-mention\">@kneath</a>"
    assert_equal "<p>#{link}: check it out.</p>",
      res.to_html
  end

  def test_not_replacing_mentions_in_pre_tags
    body = "<pre>@kneath: okay</pre>"
    assert_equal body, filter(body).to_html
  end

  def test_not_replacing_mentions_in_code_tags
    body = "<p><code>@kneath:</code> okay</p>"
    assert_equal body, filter(body).to_html
  end

  def test_not_replacing_mentions_in_links
    body = "<p><a>@kneath</a> okay</p>"
    assert_equal body, filter(body).to_html
  end

  def test_entity_encoding_and_whatnot
    body = "<p>@&#x6b;neath what's up</p>"
    link = "<a href=\"/kneath\" class=\"user-mention\">@kneath</a>"
    assert_equal "<p>#{link} what's up</p>", filter(body, '/').to_html
  end

  def test_html_injection
    body = "<p>@kneath &lt;script>alert(0)&lt;/script></p>"
    link = "<a href=\"/kneath\" class=\"user-mention\">@kneath</a>"
    assert_equal "<p>#{link} &lt;script&gt;alert(0)&lt;/script&gt;</p>",
      filter(body, '/').to_html
  end

  MarkdownPipeline =
    HTML::Pipeline::Pipeline.new [
      HTML::Pipeline::MarkdownFilter,
      HTML::Pipeline::MentionFilter
    ]

  def mentioned_usernames
    result = {}
    MarkdownPipeline.call(@body, {}, result)
    result[:mentioned_users].map { |user| user.to_s }
  end

  def test_matches_usernames_in_body
    User.make :login => 'test'
    @body = "@test how are you?"
    assert_equal %w[test], mentioned_usernames
  end

  def test_matches_usernames_with_dashes
    User.make :login => 'some-user'
    @body = "hi @some-user"
    assert_equal %w[some-user], mentioned_usernames
  end

  def test_matches_usernames_followed_by_a_single_dot
    User.make :login => 'some-user'
    @body = "okay @some-user."
    assert_equal %w[some-user], mentioned_usernames
  end

  def test_matches_usernames_followed_by_multiple_dots
    User.make :login => 'some-user'
    @body = "okay @some-user..."
    assert_equal %w[some-user], mentioned_usernames
  end

  def test_does_not_match_email_addresses
    @body = "aman@tmm1.net"
    assert_equal [], mentioned_usernames
  end

  def test_does_not_match_domain_name_looking_things
    @body = "we need a @github.com email"
    assert_equal [], mentioned_usernames
  end

  def test_does_not_match_organization_team_mentions
    User.make :login => 'github'
    @body = "we need to @github/enterprise know"
    assert_equal [], mentioned_usernames
  end

  def test_matches_colon_suffixed_names
    @body = "@tmm1: what do you think?"
    assert_equal %w[tmm1], mentioned_usernames
  end

  def test_matches_list_of_names
    @body = "@defunkt @atmos @kneath"
    assert_equal %w[defunkt atmos kneath], mentioned_usernames
  end

  def test_matches_list_of_names_with_commas
    @body = "/cc @defunkt, @atmos, @kneath"
    assert_equal %w[defunkt atmos kneath], mentioned_usernames
  end

  def test_matches_inside_brackets
    @body = "(@mislav) and [@rtomayko]"
    assert_equal %w[mislav rtomayko], mentioned_usernames
  end

  def test_ignores_invalid_users
    @body = "@defunkt @mojombo and @somedude"
    assert_equal ['defunkt', 'mojombo'], mentioned_usernames
  end

  def test_returns_distinct_set
    @body = "/cc @defunkt, @atmos, @kneath, @defunkt, @defunkt"
    assert_equal %w[defunkt atmos kneath], mentioned_usernames
  end

  def test_does_not_match_inline_code_block_with_multiple_code_blocks
    @body = "something\n\n`/cc @defunkt @atmos @kneath` `/cc @atmos/atmos`"
    assert_equal %w[], mentioned_usernames
  end
end