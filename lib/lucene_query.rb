class LuceneQuery
  ## Syntax Nodes
  ::String.class_eval do
    def to_lucene; "'#{escape_lucene.downcase_ending_keywords}'" end
    
    def parens
      if self =~ /^\s*$/
        self
      else
        "(#{self})"
      end
    end
    
    # The Lucene documentation declares special characters to be:
    #   + - && || ! ( ) { } [ ] ^ " ~ * ? : \
    RE_ESCAPE_LUCENE = /
      ( [-+!\(\)\{\}\[\]^"~*?:\\] # A special character
      | &&                        # Boolean &&
      | \|\|                      # Boolean ||
      )
    /x unless defined?(RE_ESCAPE_LUCENE)
    
    def escape_lucene
      gsub(RE_ESCAPE_LUCENE) { |m| "\\#{m}" }
    end

    ENDING_KEYWORDS = /(AND$ | OR$ | NOT$)/x unless defined?(ENDING_KEYWORDS)

    def downcase_ending_keywords
      gsub(ENDING_KEYWORDS) { |w| w.downcase }
    end    
  end
  
  ::Symbol.class_eval do
    def to_lucene; to_s end
  end
  
  ::Array.class_eval do
    def to_lucene
      map { |t| t.to_lucene }.join(" ").parens
    end
  end
  
  ::Hash.class_eval do
    def to_lucene
      inner = map { |k,v| Field.new(k, v) }
      LuceneQuery::And.new(*inner).to_lucene
    end
  end
  
  ::Numeric.module_eval do
    def to_lucene; to_s end
  end
  
  ::TrueClass.class_eval do
    def to_lucene; to_s end
  end
  
  ::FalseClass.class_eval do
    def to_lucene; to_s end
  end
  
  ::Range.class_eval do
    def ~@; To.new(first, last, true) end
    
    def to_lucene
      To.new(first, last).to_lucene
    end
  end
  
  class Field
    def initialize(key, val)
      @key, @val = key, val
    end
    
    def to_lucene
      @key.to_lucene + ":" + @val.to_lucene
    end
  end
  
  class InfixOperator
    def initialize(*terms) @terms = terms end
    
    def to_lucene
      @terms.map { |t| t.to_lucene }.join(" #{operator} ").parens
    end
  end
  
  class And < InfixOperator
    def operator; "AND" end
  end
  
  class Or < InfixOperator
    def operator; "OR" end
  end
  
  class To
    def initialize(term_1, term_2, exclusive = false)
      @term_1, @term_2, @exclusive = term_1, term_2, exclusive
    end
    
    def ~@; self.class.new(@term_1, @term_2, !@exclusive) end
    
    def to_lucene
      if @exclusive
        "{#{@term_1} TO #{@term_2}}"
      else
        "[#{@term_1} TO #{@term_2}]"
      end
    end
  end
  
  class Not
    def initialize(term) @term = term end
    
    def to_lucene
      "NOT #{@term.to_lucene}"
    end
  end
  
  class Required
    def initialize(term) @term = term end
    
    def to_lucene
      "+" + @term.to_lucene
    end
  end
  
  class Prohibit
    def initialize(term) @term = term end
    
    def to_lucene
      "-" + @term.to_lucene
    end
  end
  
  class Fuzzy
    def initialize(term, boost=nil)
      @term, @boost = term, boost
    end
    
    def to_lucene
      @term.split(/\s+/).map { |t|
        @boost ? "%s~%1.1f" % [t.escape_lucene, @boost] : "%s~" % t.escape_lucene
      } * " "
    end
  end
  
  ## DSL Helpers
  class QueryBuilder
    def self.generate(*args, &block)
      new.generate(*args, &block)
    end
    
    def generate(&block)
      instance_eval(&block)
    end
    
    def Field(key, val) Field.new(key, val) end
    def And(*terms) And.new(*terms) end
    def Or(*terms) Or.new(*terms) end
    def In(field, terms)
      Or.new(*terms.map { |term| Field.new(field, term) })
    end
    def To(term_1, term_2, exclusive = false) To.new(term_1, term_2, exclusive) end
    def Not(term) Not.new(term) end
    def Required(term) Required.new(term) end
    def Prohibit(term) Prohibit.new(term) end
    def Fuzzy(*args) Fuzzy.new(*args) end
  end
  
  def initialize(&block)
    @term = QueryBuilder.generate(&block)
  end
  
  def to_s; @term.to_lucene end
  alias :to_str :to_s
end

SolrQuery = LuceneQuery unless defined?(SolrQuery)
