# frozen_string_literal: true
# typed: strict

require 'nokogiri'
require 'sorbet-runtime'

class ChapterParser
  extend T::Sig

  sig { params(chapter_doc: Nokogiri::HTML4::Document).returns(T::Array[String]) }
  def self.fetch_chapter_paragraphs(chapter_doc)
    paragraphs = []

    # Paragraphs are typically defined by <p> elements, however
    # there can be <br> elements which are not supported in epub.
    #
    # We basically need to split the content at <br> but also close the tags on either side.
    # e.g. <strong>cool<br>stuff</strong> cannot become "<p><strong>cool</p>", "<p>stuff</strong></p>"
    # it must become "<p><strong>cool</strong></p>", "<p><strong>stuff</strong></p>"
    #
    # We can do this by:
    # - looping all paragraphs present
    # - for each paragraph we need to:
    #   - loop through the children to accumulate text or html content like em and strong
    #   - if the html content has a br, split at that point and wrap with the appropriate tag
    chapter_doc.css('.chapter-content p').each do |ch|
      style = ch.attribute("style")&.content
      p_open_element = style.nil? ? "<p>" : "<p style=\"#{style}\">"

      # Acc is per paragraph. Each paragraph can result in many paragraphs if <br> is involved
      acc = []

      ch.children.each do |child_element|
        # The "appropriate tag"
        wrapping_element = child_element.name

        # If the element is text or doesn't have a <br>, we can just accumulate text/html as needed.
        # If it does have a br then we need to do extra parsing.
        case child_element
        when Nokogiri::XML::Text
          acc << child_element.text
        when Nokogiri::XML::Element
          has_br = child_element.children.any? { |c| c.name == "br" }
          if !has_br
            acc << child_element.to_html
            next
          end

          # If we have a <br> element, we need to accumulate children partitioned by <br>
          # We can do this by walking the children and flushing any time we see a <br> (as well as flushing an empty space for <br>)
          child_acc = []
          wrapper_name = child_element.name
          child_element.children.each do |grandchild_element|
            case grandchild_element
            when Nokogiri::XML::Text
              child_acc << grandchild_element.text
            when Nokogiri::XML::Element
              if grandchild_element.name != "br"
                child_acc << grandchild_element.to_html
                next
              end

              # We have hit a <br>, so flush with the appropriate wrapper name (and the empty space),
              # reset the acc and continue
              paragraphs << "#{p_open_element}<#{wrapper_name}>#{child_acc.join}</#{wrapper_name}></p>"
              paragraphs << "<p> </p>" # Mimic <br>
              child_acc = []
            else
              raise ArgumentError.new(grandchild_element.inspect)
            end
          end
          if child_acc.any?
            paragraphs << "#{p_open_element}<#{wrapper_name}>#{child_acc.join}</#{wrapper_name}></p>"
          end
        end
      end

      if acc.any?
        paragraphs << "#{p_open_element}#{acc.join}</p>"
      end
    end

    paragraphs
  end
end
