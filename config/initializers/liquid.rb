module Liquid
  # https://github.com/Shopify/liquid/pull/623
  remove_const :PartialTemplateParser
  remove_const :TemplateParser

  PartialTemplateParser       = /#{TagStart}.*?#{TagEnd}|#{VariableStart}(?:(?:[^'"{}]+|#{QuotedString})*?|.*?)#{VariableIncompleteEnd}/m
  TemplateParser              = /(#{PartialTemplateParser}|#{AnyStartingTag})/m
end
