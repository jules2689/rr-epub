# frozen_string_literal: true
# typed: strict

module Structs
  class Chapter < T::Struct
    const :id, Integer
    const :order, Integer
    const :url, String
    const :title, String
    const :release_date, String
    const :paragraphs, T::Array[String]
  end
  
  class Rating < T::Struct
    extend T::Sig
    const :rating, Float
    const :base, Float

    sig { returns(String) }
    def to_s
      "#{rating} / #{base}"
    end
  end
  
  class Book < T::Struct
    const :title, String
    const :url, String
    const :cover_image_url, String
    const :author, String
    const :description, String
    const :chapters, T::Array[Chapter]
    const :rating, Rating
  end
end
