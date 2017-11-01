module Ingreedy
  class RootParser < Parslet::Parser
    include CaseInsensitiveParser

    rule(:range) do
      AmountParser.new.as(:amount) >>
        whitespace.maybe >>
        range_separator >>
        whitespace.maybe >>
        AmountParser.new.as(:amount_end)
    end

    rule(:conjunction) do
      AmountParser.new.as(:amount) >>
        whitespace.maybe >>
        conjunction_separator >>
        whitespace.maybe >>
        AmountParser.new.as(:amount_end)
    end

    rule(:range_separator) do
      range_separators.map { |separator| str(separator) }.inject(:|)
    end

    rule(:conjunction_separator) do
      dictionary_conjunctions.map { |separator| str(separator) }.inject(:|)
    end

    rule(:amount) do
      AmountParser.new.as(:amount)
    end

    rule(:whitespace) do
      match("\s")
    end

    rule(:container_amount) do
      AmountParser.new
    end

    rule(:unit) do
      if unit_matches.any?
        unit_matches.map { |u| str(u) }.inject(:|)
      else
        str("")
      end
    end

    rule(:container_unit) do
      unit
    end

    rule(:unit_and_preposition) do
      unit.as(:unit) >> (preposition_or_whitespace | any.absent?)
    end

    rule(:preposition_or_whitespace) do
      if prepositions.empty?
        whitespace
      else
        preposition | whitespace
      end
    end

    rule(:preposition) do
      whitespace >>
        prepositions.map { |preposition| str(preposition) }.inject(:|) >>
        whitespace
    end

    rule(:amount_unit_separator) do
      whitespace | str("-")
    end

    rule(:container_size) do
      # e.g. (12 ounce) or 12 ounce
      str("(").maybe >>
        container_amount.as(:container_amount) >>
        amount_unit_separator.maybe >>
        container_unit.as(:container_unit) >>
        str(")").maybe >> preposition_or_whitespace
    end

    rule(:amount_and_unit) do
       amount_and_units >>
        whitespace.maybe >>
        unit_and_preposition.maybe >>
        container_size.maybe
    end

    rule(:quantity) do
      amount_and_unit | unit_and_preposition
    end

    rule(:standard_format) do
      # e.g. 1/2 (12 oz) can black beans
      quantity >> any.repeat.as(:ingredient)
    end

    rule(:reverse_format) do
      # e.g. flour 200g
      ((whitespace >> quantity).absent? >> any).repeat.as(:ingredient) >>
        whitespace >>
        quantity
    end

    rule(:imprecise) do
      imprecise_amounts.map { |con| stri(con) }.inject(:|).as(:imprecise_amount) >>
      whitespace >>
      any.repeat.as(:ingredient)
    end

    rule(:ingredient_addition) do
      if imprecise_amounts.any?
        imprecise | standard_format | reverse_format
      else
        standard_format | reverse_format
      end
    end

    root :ingredient_addition

    def initialize(original_query)
      @original_query = original_query
    end

    def parse
      super(original_query)
    end

    private

    attr_reader :original_query

    def amount_and_units
      rules = [range]
      rules.push(conjunction) if dictionary_conjunctions.any?
      rules.push(amount)
      rules.inject(:|)
    end

    def imprecise_amounts
      Ingreedy.dictionaries.current.imprecise_amounts
    end

    def prepositions
      Ingreedy.dictionaries.current.prepositions
    end

    def range_separators
      Ingreedy.dictionaries.current.range_separators
    end

    def dictionary_conjunctions
      Ingreedy.dictionaries.current.conjunctions
    end

    def unit_matches
      @unit_matches ||= original_query.
                        scan(UnitVariationMapper.regexp).
                        sort_by(&:length).
                        reverse
    end
  end
end
