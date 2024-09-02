# frozen_string_literal: true
# typed: strict

module Errors
  class BaseError < StandardError
  end

  class HTMLRedirectTooDeep < BaseError
  end

  class HTTPRequestFailed < BaseError
  end
end