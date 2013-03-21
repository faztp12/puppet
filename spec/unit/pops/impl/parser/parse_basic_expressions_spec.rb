#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'
require 'puppet/pops/impl/parser/eparser'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe Puppet::Pops::Impl::Parser::Parser do
  include ParserRspecHelper
  Model ||= Puppet::Pops::API::Model

  context "When running these examples, the setup" do

    it "should include a ModelTreeDumper for convenient string comparisons" do
      x = literal(10) + literal(20)
      dump(x).should == "(+ 10 20)"
    end

    # TODO: Revisit when finished with the rest - probably not needed
    # (needed if comparing against manually created models vs. parser created to ensure that
    #  manual model gets correct precedence).
    #
    it "should use a Factory that applies arithmetic precedence to operators" do
      x = literal(2) * literal(10) + literal(20)
      dump(x).should == "(+ (* 2 10) 20)"
    end

    it "should parse a code string and return a model" do
      model = parse("$a = 10").current
      model.class.should == Model::AssignmentExpression
      dump(model).should == "(= $a 10)"
    end

  end

  context "When the parser parses arithmetic" do

    context "with Integers" do
      it "$a = 2 + 2"   do; dump(parse("$a = 2 + 2")).should == "(= $a (+ 2 2))"      ; end
      it "$a = 7 - 3"   do; dump(parse("$a = 7 - 3")).should == "(= $a (- 7 3))"      ; end
      it "$a = 6 * 3"   do; dump(parse("$a = 6 * 3")).should == "(= $a (* 6 3))"      ; end
      it "$a = 6 / 3"   do; dump(parse("$a = 6 / 3")).should == "(= $a (/ 6 3))"      ; end
      it "$a = 6 % 3"   do; dump(parse("$a = 6 % 3")).should == "(= $a (% 6 3))"      ; end
      it "$a = -(6/3)"  do; dump(parse("$a = -(6/3)")).should == "(= $a (- (/ 6 3)))" ; end
      it "$a = -6/3"    do; dump(parse("$a = -6/3")).should == "(= $a (/ (- 6) 3))"   ; end
      it "$a = 8 >> 1 " do; dump(parse("$a = 8 >> 1")).should == "(= $a (>> 8 1))"    ; end
      it "$a = 8 << 1 " do; dump(parse("$a = 8 << 1")).should == "(= $a (<< 8 1))"    ; end
    end

    context "with Floats" do
      it "$a = 2.2 + 2.2"  do; dump(parse("$a = 2.2 + 2.2")).should == "(= $a (+ 2.2 2.2))"      ; end
      it "$a = 7.7 - 3.3"  do; dump(parse("$a = 7.7 - 3.3")).should == "(= $a (- 7.7 3.3))"      ; end
      it "$a = 6.1 * 3.1"  do; dump(parse("$a = 6.1 - 3.1")).should == "(= $a (- 6.1 3.1))"      ; end
      it "$a = 6.6 / 3.3"  do; dump(parse("$a = 6.6 / 3.3")).should == "(= $a (/ 6.6 3.3))"      ; end
      it "$a = -(6.0/3.0)" do; dump(parse("$a = -(6.0/3.0)")).should == "(= $a (- (/ 6.0 3.0)))" ; end
      it "$a = -6.0/3.0"   do; dump(parse("$a = -6.0/3.0")).should == "(= $a (/ (- 6.0) 3.0))"   ; end
      it "$a = 3.14 << 2"  do; dump(parse("$a = 3.14 << 2")).should == "(= $a (<< 3.14 2))"      ; end
      it "$a = 3.14 >> 2"  do; dump(parse("$a = 3.14 >> 2")).should == "(= $a (>> 3.14 2))"      ; end
    end

    context "with hex and octal Integer values" do
      it "$a = 0xAB + 0xCD" do; dump(parse("$a = 0xAB + 0xCD")).should == "(= $a (+ 0xAB 0xCD))"  ; end
      it "$a = 0777 - 0333" do; dump(parse("$a = 0777 - 0333")).should == "(= $a (- 0777 0333))"  ; end
    end

    context "with strings requiring boxing to Numeric" do
      # Test that numbers in string form does not turn into numbers
      it "$a = '2' + '2'"       do; dump(parse("$a = '2' + '2'")).should == "(= $a (+ '2' '2'))"             ; end
      it "$a = '2.2' + '0.2'"   do; dump(parse("$a = '2.2' + '0.2'")).should == "(= $a (+ '2.2' '0.2'))"     ; end
      it "$a = '0xab' + '0xcd'" do; dump(parse("$a = '0xab' + '0xcd'")).should == "(= $a (+ '0xab' '0xcd'))" ; end
      it "$a = '0777' + '0333'" do; dump(parse("$a = '0777' + '0333'")).should == "(= $a (+ '0777' '0333'))" ; end
    end
    context "precedence should be correct" do
      it "$a = 1 + 2 * 3" do; dump(parse("$a = 1 + 2 * 3")).should == "(= $a (+ 1 (* 2 3)))"; end
      it "$a = 1 + 2 % 3" do; dump(parse("$a = 1 + 2 % 3")).should == "(= $a (+ 1 (% 2 3)))"; end
      it "$a = 1 + 2 / 3" do; dump(parse("$a = 1 + 2 / 3")).should == "(= $a (+ 1 (/ 2 3)))"; end
      it "$a = 1 + 2 << 3" do; dump(parse("$a = 1 + 2 << 3")).should == "(= $a (<< (+ 1 2) 3))"; end
      it "$a = 1 + 2 >> 3" do; dump(parse("$a = 1 + 2 >> 3")).should == "(= $a (>> (+ 1 2) 3))"; end
    end
    context "parentheses alter precedence" do
      it "$a = (1 + 2) * 3" do; dump(parse("$a = (1 + 2) * 3")).should == "(= $a (* (+ 1 2) 3))"; end
      it "$a = (1 + 2) / 3" do; dump(parse("$a = (1 + 2) / 3")).should == "(= $a (/ (+ 1 2) 3))"; end
    end
  end

  context "When the evaluator performs boolean operations" do
    context "using operators AND OR NOT" do
      it "$a = true  and true" do; dump(parse("$a = true and true")).should == "(= $a (&& true true))"; end
      it "$a = true  or true"  do; dump(parse("$a = true or true")).should == "(= $a (|| true true))" ; end
      it "$a = !true"          do; dump(parse("$a = !true")).should == "(= $a (! true))"              ; end
    end

    context "precedence should be correct" do
      it "$a = false or true and true" do
        dump(parse("$a = false or true and true")).should == "(= $a (|| false (&& true true)))"
      end
      it "$a = (false or true) and true" do
        dump(parse("$a = (false or true) and true")).should == "(= $a (&& (|| false true) true))"
      end
      it "$a = !true or true and true" do
        dump(parse("$a = !false or true and true")).should == "(= $a (|| (! false) (&& true true)))"
      end
    end

    # Possibly change to check of literal expressions
    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        dump(parse("! 'x'")).should == "(! 'x')"
      end
      it "''             == false" do
        dump(parse("! ''")).should == "(! '')"
      end
      it ":undef         == false" do
        dump(parse("! undef")).should == "(! :undef)"
      end
    end
  end

  context "When parsing comparisons" do
    context "of string values" do
      it "$a = 'a' == 'a'"  do; dump(parse("$a = 'a' == 'a'")).should == "(= $a (== 'a' 'a'))"   ; end
      it "$a = 'a' != 'a'"  do; dump(parse("$a = 'a' != 'a'")).should == "(= $a (!= 'a' 'a'))"   ; end
      it "$a = 'a' < 'b'"   do; dump(parse("$a = 'a' < 'b'")).should == "(= $a (< 'a' 'b'))"     ; end
      it "$a = 'a' > 'b'"   do; dump(parse("$a = 'a' > 'b'")).should == "(= $a (> 'a' 'b'))"     ; end
      it "$a = 'a' <= 'b'"  do; dump(parse("$a = 'a' <= 'b'")).should == "(= $a (<= 'a' 'b'))"   ; end
      it "$a = 'a' >= 'b'"  do; dump(parse("$a = 'a' >= 'b'")).should == "(= $a (>= 'a' 'b'))"   ; end
    end
    context "of integer values" do
      it "$a = 1 == 1"  do; dump(parse("$a = 1 == 1")).should == "(= $a (== 1 1))"   ; end
      it "$a = 1 != 1"  do; dump(parse("$a = 1 != 1")).should == "(= $a (!= 1 1))"   ; end
      it "$a = 1 < 2"   do; dump(parse("$a = 1 < 2")).should == "(= $a (< 1 2))"     ; end
      it "$a = 1 > 2"   do; dump(parse("$a = 1 > 2")).should == "(= $a (> 1 2))"     ; end
      it "$a = 1 <= 2"  do; dump(parse("$a = 1 <= 2")).should == "(= $a (<= 1 2))"   ; end
      it "$a = 1 >= 2"  do; dump(parse("$a = 1 >= 2")).should == "(= $a (>= 1 2))"   ; end
    end
    context "of regular expressions (parse errors)" do
      # Not supported in concrete syntax
      it "$a = /.*/ == /.*/" do
        expect {  parse("$a = /.*/ == /.*/") }.to raise_error(Puppet::ParseError)
      end
      it "$a = /.*/ != /a.*/" do
        expect {  parse("$a = /.*/ != /.*/") }.to raise_error(Puppet::ParseError)
      end
    end
  end
  context "When parsing Regular Expression matching" do
    it "$a = 'a' =~ /.*/"    do; dump(parse("$a = 'a' =~ /.*/")).should == "(= $a (=~ 'a' /.*/))"      ; end
    it "$a = 'a' =~ '.*'"    do; dump(parse("$a = 'a' =~ '.*'")).should == "(= $a (=~ 'a' '.*'))"      ; end
    it "$a = 'a' !~ /b.*/"   do; dump(parse("$a = 'a' !~ /b.*/")).should == "(= $a (!~ 'a' /b.*/))"    ; end
    it "$a = 'a' !~ 'b.*'"   do; dump(parse("$a = 'a' !~ 'b.*'")).should == "(= $a (!~ 'a' 'b.*'))"    ; end
  end
  context "When parsing Lists" do
    it "$a = []" do
      dump(parse("$a = []")).should == "(= $a ([]))"
    end
    it "$a = [1]" do
      dump(parse("$a = [1]")).should == "(= $a ([] 1))"
    end
    it "$a = [1,2,3]" do
      dump(parse("$a = [1,2,3]")).should == "(= $a ([] 1 2 3))"
    end
    it "[...[...[]]] should create nested arrays without trouble" do
      dump(parse("$a = [1,[2.0, 2.1, [2.2]],[3.0, 3.1]]")).should == "(= $a ([] 1 ([] 2.0 2.1 ([] 2.2)) ([] 3.0 3.1)))"
    end
    it "$a = [2 + 2]" do
      dump(parse("$a = [2+2]")).should == "(= $a ([] (+ 2 2)))"
    end
    it "$a [1,2,3] == [1,2,3]" do
      dump(parse("$a = [1,2,3] == [1,2,3]")).should == "(= $a (== ([] 1 2 3) ([] 1 2 3)))"
    end
  end
  context "When parsing indexed access" do
    it "$a = $b[2]" do
      dump(parse("$a = $b[2]")).should == "(= $a (slice $b 2))"
    end
    it "$a = [1, 2, 3][2]" do
      # Not pending when using egrammar
      #pending "hasharrayaccess only operates on variable as LHS due to clash with resource reference in puppet 3.x"
      dump(parse("$a = [1,2,3][2]")).should == "(= $a (slice ([] 1 2 3) 2))"
    end
    it "$a = {'a' => 1, 'b' => 2}['b']" do
      # Not pending when using egrammar
      #pending "hasharrayaccess only operates on variable as LHS due to clash with resource reference in puppet 3.x"
      dump(parse("$a = {'a'=>1,'b' =>2}[b]")).should == "(= $a (slice ({} ('a' 1) ('b' 2)) b))"
    end

  end

  context "When parsing assignments" do
    it "Should allow simple assignment" do
      dump(parse("$a = 10")).should == "(= $a 10)"
    end
    it "Should allow chained assignment" do
      dump(parse("$a = $b = 10")).should == "(= $a (= $b 10))"
    end
    it "Should allow chained assignment with expressions" do
      dump(parse("$a = 1 + ($b = 10)")).should == "(= $a (+ 1 (= $b 10)))"
    end
  end

  context "When parsing Hashes" do
    it "(selftest) these tests depends on that the factory creates hash with literal expressions" do
      x = literal({'a'=>1,'b'=>2}).current
      x.entries.each {|v| v.kind_of?(Puppet::Pops::API::Model::KeyedEntry).should == true }
      Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x).should == "({} ('a' 1) ('b' 2))"
    end
    it "should create a  Hash when evaluating a LiteralHash" do
      dump(parse("$a = {'a'=>1,'b'=>2}")).should == "(= $a ({} ('a' 1) ('b' 2)))"
    end
    it "$a = {...{...{}}} should create nested hashes without trouble" do
      dump(parse("$a = {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}")).should == "(= $a ({} ('a' 1) ('b' ({} ('x' 2.1) ('y' 2.2)))))"
    end
    it "$a = {'a'=> 2 + 2} should evaluate values in entries" do
      dump(parse("$a = {'a'=>2+2}")).should == "(= $a ({} ('a' (+ 2 2))))"
    end
    it "$a = {'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2}" do
      dump(parse("$a = {'a'=>1,'b'=>2} == {'a'=>1,'b'=>2}")).should == "(= $a (== ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))"
    end
    it "$a = {'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3}" do
      dump(parse("$a = {'a'=>1,'b'=>2} != {'a'=>1,'b'=>2}")).should == "(= $a (!= ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))"
    end
  end
  context "When parsing the 'in' operator" do
    it "with integer in a list" do
      dump(parse("$a = 1 in [1,2,3]")).should == "(= $a (in 1 ([] 1 2 3)))"
    end
    it "with string key in a hash" do
      dump(parse("$a = 'a' in {'x'=>1, 'a'=>2, 'y'=> 3}")).should == "(= $a (in 'a' ({} ('x' 1) ('a' 2) ('y' 3))))"
    end
    it "with substrings of a string" do
      dump(parse("$a = 'ana' in 'bananas'")).should == "(= $a (in 'ana' 'bananas'))"
    end
    it "with sublist in a list" do
      dump(parse("$a = [2,3] in [1,2,3]")).should == "(= $a (in ([] 2 3) ([] 1 2 3)))"
    end
  end
  context "When parsing string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      dump(parse("$a = \"$var\"")).should == "(= $a (cat '' (str $var) ''))"
    end
    it "should interpolate a variable in a text expression, \"${$var}\"" do
      dump(parse("$a = \"${$var}\"")).should == "(= $a (cat '' (str $var) ''))"
    end
    it "should interpolate a variable, \"yo${var}yo\"" do
      dump(parse("$a = \"yo${var}yo\"")).should == "(= $a (cat 'yo' (str $var) 'yo'))"
    end
    it "should interpolate any expression in a text expression, \"${var*2}\"" do
      dump(parse("$a = \"yo${var+2}yo\"")).should == "(= $a (cat 'yo' (str (+ $var 2)) 'yo'))"
    end
  end
end