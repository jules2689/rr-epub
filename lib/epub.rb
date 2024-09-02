# frozen_string_literal: true
# typed: strict

require 'gepub'

require_relative "structs"

class Epub
  extend T::Sig

  sig { params(book: Structs::Book).returns(GEPUB::Book) }
  def self.generate_book(book)
    puts "Generating epub"
    gepub_book = GEPUB::Book.new
    gepub_book.primary_identifier(book.url, 'BookID', 'URL')
    gepub_book.language = 'en' # TODO
    gepub_book.add_title(
      book.title, 
      title_type: GEPUB::TITLE_TYPE::MAIN,
      lang: 'en', # TODO
      display_seq: 1
    )

    gepub_book.add_creator(book.author, display_seq: 1)

    ext_name = File.extname(URI(book.cover_image_url).path || "")[1..-1]
    puts "Downloading cover image: #{book.cover_image_url} (#{ext_name})"
    uri = URI.parse(book.cover_image_url)
    gepub_book.add_item("img/cover_img.#{ext_name}", content: uri.open).cover_image

    # within ordered block, add_item will be added to spine.
    gepub_book.ordered do
      cover_content = <<~COVER
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>cover page</title>
        </head>
        <body>
          <h1>#{book.title}</h1>
          <h3>by #{book.author} <small>#{book.rating}</small></h3>
          <img src="../img/cover_img.#{ext_name}" />
        </body>
      </html>
      COVER
      gepub_book.add_item('text/cover.xhtml', content: StringIO.new(cover_content)).landmark(type: 'cover', title: 'cover page')

      book.chapters.each do |chapter|
        content = <<~CHAPTER
          <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>#{chapter.title}</title></head>
          <body>
            #{chapter.paragraphs.join}
          </body></html>
        CHAPTER
        gepub_book
          .add_item("text/chap#{chapter.order}.xhtml")
          .add_content(StringIO.new(content))
          .toc_text(chapter.title)
          .landmark(type: 'bodymatter', title: chapter.title)
      end
    end
  
    title_slug = book.title.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    epub_dir = File.expand_path("../epub/", __dir__)
    epub_path = File.join(epub_dir, "#{title_slug}.epub")

    # if you do not specify a nav document with add_item, 
    # generate_epub will generate simple navigation text.
    # auto-generated nav file will not appear on the spine.
    puts "Generating epub at #{epub_path}"
    gepub_book.generate_epub(epub_path)
    gepub_book
  end
end