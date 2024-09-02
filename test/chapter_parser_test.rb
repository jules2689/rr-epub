# typed: true

require_relative "test_helper"
require "chapter_parser"

class ChapterParserTest < Minitest::Test
  def test_parses
    content = <<~HTML
      <html>
        <body>
          <div class="chapter-inner chapter-content">
            <p class="abcdef" style="text-align: center" data-original-margin=""><strong>Chapter 001<br></strong><strong>Hello everyone</strong></p>
            <p class="abcdef" data-original-margin="">Lorem Ipsum Lorem Ipsum</p>
            <p class="abcdef" data-original-margin="">“Good morning, everyone“ I heard. “Morning, morning, <em>MORNING</em>!!!”</p>
          </div>
        </body>
      </html>
    HTML

    chap_doc = Nokogiri::HTML(content)

    result = ChapterParser.fetch_chapter_paragraphs(chap_doc)
    assert_equal(5, result.length)

    assert_equal("<p style=\"text-align: center\"><strong>Chapter 001</strong></p>", result[0])
    assert_equal("<p> </p>", result[1])
    assert_equal("<p style=\"text-align: center\"><strong>Hello everyone</strong></p>", result[2])
    assert_equal("<p>Lorem Ipsum Lorem Ipsum</p>", result[3])
    assert_equal("<p>“Good morning, everyone“ I heard. “Morning, morning, <em>MORNING</em>!!!”</p>", result[4])
  end
end
