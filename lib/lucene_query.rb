class LuceneQuery
  ## Syntax Nodes
  ::String.class_eval do
    def to_lucene; "'#{escape_lucene}'" end
    def parens; "(#{self})" end
    def escape_lucene
      gsub(/([-+!\(\)\{\}\[\]^"~*?:\\]|&&|\|\|)/) { |m| "\\#{m}" }
    end
  end
  
  ::Symbol.class_eval do
    def to_lucene; to_s end
  end
  
  ::Array.class_eval do
    def to_lucene
      hd, *tl = self
      tl.inject(hd.to_lucene) { |q,t| q + " " + t.to_lucene }.parens
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
  
  class Field
    def initialize(key, val)
      @key, @val = key, val
    end
    
    def to_lucene
      @key.to_lucene + ":" + @val.to_lucene
    end
  end
  
  class BooleanOperator
    def initialize(*terms) @terms = terms end
    
    def to_lucene
      hd, *tl = @terms
      tl.inject(hd.to_lucene) { |q,t|
        q + " " + operator + " " + t.to_lucene
      }.parens
    end
  end
  
  class And < BooleanOperator
    def operator; "AND" end
  end
  
  class Or < BooleanOperator
    def operator; "OR" end
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
  
  ## DSL Helpers
  def Field(key, val) Field.new(key, val) end
  def And(*terms) And.new(*terms) end
  def Or(*terms) Or.new(*terms) end
  def In(field, terms)
    Or.new(*terms.map { |term| Field.new(field, term) })
  end
  def Not(term) Not.new(term) end
  def Required(term) Required.new(term) end
  def Prohibit(term) Prohibit.new(term) end
  
  def initialize(&block)
    @term = instance_eval(&block)
  end
  
  def to_s; @term.to_lucene end
  alias :to_str :to_s
end

SolrQuery = LuceneQuery unless defined?(SolrQuery)
