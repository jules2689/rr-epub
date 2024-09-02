#!/usr/bin/env ruby
# frozen_string_literal: true
# typed: strict

require 'rubygems'
require 'sorbet-runtime'
require 'net/http'
require 'uri'
require 'json'
require 'cli/ui'
require 'digest'
require 'open-uri'

require_relative 'chapter_parser'
require_relative 'epub'
require_relative 'structs'

class Main
  extend T::Sig

  sig { params(url: String).void }
  def run(url)
    CLI::UI::StdoutRouter.enable

    CLI::UI::Frame.open(url) do
      book = fetch_cached_book(url) || fetch_book(url)
      cache_book!(book)

      CLI::UI::Frame.divider("Book Details")
      puts CLI::UI.fmt("{{bold:Title:}} #{book.title}")
      puts CLI::UI.fmt("{{bold:Author:}} #{book.author}")
      puts CLI::UI.fmt("{{bold:Description:}} #{book.description[0..100]}...")
      puts CLI::UI.fmt("{{bold:# Chapters:}} #{book.chapters.length}")
      puts CLI::UI.fmt("{{bold:Rating:}} #{book.rating}")

      CLI::UI::Frame.divider("Epub Generation")
      Epub.generate_book(book)
    end
  end

  sig { params(series_url: String).returns(Structs::Book) }
  private def fetch_book(series_url)
    doc = Nokogiri::HTML(get_response(series_url))

    # Metadata
    cover_image = doc.css('meta[property="og:image"]').attribute('content').value
    title = doc.css('title').text.split("|").first.strip
    author = doc.css('meta[property="books:author"]').attribute('content').value
    description = doc.css('.description').text.strip

    # Rating
    rating = doc.css('meta[property="books:rating:value"]').attribute('content').value
    rating_base = doc.css('meta[property="books:rating:scale"]').attribute('content').value
    rating = Structs::Rating.new(rating: rating.to_f, base: rating_base.to_f)

    # Chapters
    options = doc.css('script')
    chapters_outline_script = options.detect { |o| o.text.include?('window.chapters')}
    chapters_line = chapters_outline_script.text.lines.detect { |l| l.include?('window.chapters') }
    # Remove preceeding "window.chapters = " and ; at the end
    chapter_json = chapters_line.strip.gsub(/window\.chapters = /, '')[0..-2]
    parsed_chapters = JSON.parse(chapter_json)

    # Chapter downloading
    chapters = T.let([], T::Array[Structs::Chapter])
    CLI::UI::Spinner.spin("Fetching chapters") do |spinner|
      chapters = parsed_chapters.map do |parsed_chapter|
        spinner.update_title("Fetching chapter #{parsed_chapter['order'] + 1} of #{parsed_chapters.length}: #{parsed_chapter['title']}")
        url = "https://royalroad.com" + parsed_chapter['url']

        # For chapters
        resp = get_response(url)
        chap_doc = Nokogiri::HTML(resp)
        
        Structs::Chapter.new(
          id: parsed_chapter['id'],
          order: parsed_chapter['order'],
          url: url,
          title: parsed_chapter['title'],
          release_date: parsed_chapter['date'],
          paragraphs: ChapterParser.fetch_chapter_paragraphs(chap_doc)
        )
      end.sort_by(&:order)
    end

    Structs::Book.new(
      title: title,
      url: series_url,
      cover_image_url: cover_image,
      author: author,
      description: description,
      rating: rating,
      chapters: chapters
    )
  end

  sig { params(url: String).returns(T.nilable(Structs::Book)) }
  private def fetch_cached_book(url)
    cache_dir = File.expand_path("../cache/", __dir__)
    path = File.join(cache_dir, "#{Digest::SHA256.hexdigest(url)}.json")
    return nil if !File.exist?(path)

    puts CLI::UI.fmt("Fetching cached book details")
    parsed_json = JSON.parse(File.read(path))
    Structs::Book.from_hash(parsed_json)
  end

  sig { params(book: Structs::Book).void }
  private def cache_book!(book)
    cache_dir = File.expand_path("../cache/", __dir__)
    path = File.join(cache_dir, "#{Digest::SHA256.hexdigest(book.url)}.json")
    File.write(path, book.serialize.to_json)
  end

  sig { params(url: String).returns(T.nilable(String)) }
  private def get_response(url)
    body = T.let(nil, T.nilable(String))
    CLI::UI::Spinner.spin("Fetching #{url}") do |spinner|
      body = fetch_with_redirects(url, 10, spinner).body
    end
    raise Errors::HTTPRequestFailed.new("body was nil for #{url}") if body.nil?
    body
  end

  sig { params(uri_str: String, limit: Integer, spinner: T.untyped).returns(Net::HTTPResponse) }
  def fetch_with_redirects(uri_str, limit, spinner)
    raise Errors::HTMLRedirectTooDeep.new('HTTP redirect too deep') if limit == 0
    
    uri = URI.parse(uri_str)
    req = Net::HTTP::Get.new(uri.path, { 'User-Agent' => 'Mozilla/5.0 (etc...)' })
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then
      spinner.update_title("Redirecting to #{response['location']}")
      fetch_with_redirects(response['location'], limit - 1, spinner)
    else
      response.error!
    end
  end
end
