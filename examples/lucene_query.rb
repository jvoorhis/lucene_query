require File.dirname(__FILE__) + '/../lib/lucene_query'

describe LuceneQuery do
  
  it "should passthru most primitives" do
    lambda { :example }.should generate_query("example")
    lambda { 42 }.should generate_query("42")
    lambda { 3.14159 }.should generate_query("3.14159")
    lambda { true }.should generate_query("true")
    lambda { false }.should generate_query("false")
  end
  
  it "should cope with empty Arrays" do
    lambda { Array.new }.should generate_query("")
  end
  
  it "should cope with empty Hashes" do
    lambda { Hash.new }.should generate_query("")
  end
  
  it "should quote Strings" do
    lambda { "example" }.should generate_query("'example'")
  end
  
  it "should escape Strings" do
    lambda { "this || that" }.should generate_query("'this \\|| that'")
    lambda { "this && that" }.should generate_query("'this \\&& that'")
    lambda { "Query builder for the Lucene (and Solr) search engine." }.should generate_query("'Query builder for the Lucene \\(and Solr\\) search engine.'")
    lambda { "~jvoorhis" }.should generate_query("'\\~jvoorhis'")
    lambda { "-spam" }.should generate_query("'\\-spam'")
    lambda { "+ham" }.should generate_query("'\\+ham'")
    lambda { '\d{10}' }.should generate_query("'\\\\d\\{10\\}'")
  end
  
  it "should downcase incorrectly-located keywords" do
    lambda { "Me AND" }.should generate_query("'Me and'")
    lambda { "You OR" }.should generate_query("'You or'")
    lambda { "Maybe NOT" }.should generate_query("'Maybe not'")
  end

  it "should group Arrays" do
    lambda { [:red, :green, :blue] }.should generate_query("(red green blue)")
  end
  
  it "should join terms with AND" do
    lambda { And(:symbol, 42, "string") }.should generate_query("(symbol AND 42 AND 'string')")
  end
  
  it "should join terms with OR" do
    lambda { Or(:symbol, 42, "string") }.should generate_query("(symbol OR 42 OR 'string')")
  end
  
  it "should negate a term with NOT" do
    lambda { Not("me") }.should generate_query("NOT 'me'")
  end
  
  it "should support fields" do
    lambda { Field(:city, "Portland") }.should generate_query("city:'Portland'")
    lambda { Field("city", "Portland") }.should generate_query("'city':'Portland'")
  end
  
  it "should AND together Hash terms" do
    t1 = /state:'Oregon'/
    t2 = /city:'Portland'/
    re = /\((#{t1} AND #{t2}|#{t2} AND #{t1})\)/
    lambda { { :city => "Portland", :state => "Oregon" } }.should generate_query(re)
  end
  
  it "should OR together IN terms" do
    lambda { In(:id, [110, 220, 330]) }.should generate_query("(id:110 OR id:220 OR id:330)")
  end
  
  it "should require terms" do
    lambda { Required("lucene") }.should generate_query("+'lucene'")
    lambda { { :marine_life => [Required("fish"), Required("dolphins")] } }.should generate_query("(marine_life:(+'fish' +'dolphins'))")
  end
  
  it "should prohibit terms" do
    lambda { Prohibit("bugs") }.should generate_query("-'bugs'")
    lambda { { :marine_life => [Required("fish"), Prohibit("eels")] } }.should generate_query("(marine_life:(+'fish' -'eels'))")
  end
  
  it "should produce fuzzy terms" do
    lambda { Fuzzy("term") }.should generate_query("term~")
    lambda { Fuzzy("multiple terms") }.should generate_query("multiple~ terms~")
    lambda { Fuzzy("term", 0.7) }.should generate_query("term~0.7")
    lambda { Fuzzy("*") }.should generate_query("\\*~")
  end
  
  it "should produce an inclusive range query by default" do
    lambda { To("here", "eternity") }.should generate_query("[here TO eternity]")
    lambda { ("here" .. "eternity") }.should generate_query("[here TO eternity]")
    lambda { ~~("here" .. "eternity") }.should generate_query("[here TO eternity]")
  end
  
  it "should optionally produce an exclusive range query" do
    lambda { To("soup", "nuts", true) }.should generate_query("{soup TO nuts}")
    lambda { ~("soup" .. "nuts") }.should generate_query("{soup TO nuts}")
  end
end

class QueryMatcher
  def initialize(expected)
    @expected = expected
  end
  
  def matches?(target)
    @target = target
    @actual = LuceneQuery.new(&@target).to_s
    @expected === @actual
  end
  
  def failure_message
    "Expected\n\t#@expected\nbut received\n\t#@actual"
  end
end

def generate_query(query)
  QueryMatcher.new(query)
end
