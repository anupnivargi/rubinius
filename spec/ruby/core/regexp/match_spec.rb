# -*- encoding: utf-8 -*-
require File.expand_path('../../../spec_helper', __FILE__)

describe :regexp_match, :shared => true do
  it "returns nil if there is no match" do
    /xyz/.send(@method,"abxyc").should be_nil
  end

  it "returns nil if the object is nil" do
    /\w+/.send(@method, nil).should be_nil
  end
end

describe "Regexp#=~" do
  it_behaves_like(:regexp_match, :=~)

  it "returns the index of the first character of the matching region" do
    (/(.)(.)(.)/ =~ "abc").should == 0
  end

  ruby_version_is "1.9" do
    it "returns the index too, when argument is a Symbol" do
      (/(.)(.)(.)/ =~ :abc).should == 0
    end
  end
end

describe "Regexp#match" do
  it_behaves_like(:regexp_match, :match)

  it "returns a MatchData object" do
    /(.)(.)(.)/.match("abc").should be_kind_of(MatchData)
  end

  ruby_version_is "1.9" do
    it "returns a MatchData object, when argument is a Symbol" do
      /(.)(.)(.)/.match(:abc).should be_kind_of(MatchData)
    end

    describe "with [string, position]" do
      describe "when given a positive position" do
        it "matches the input at a given position" do
          /(.).(.)/.match("01234", 1).captures.should == ["1", "3"]
        end

        with_feature :encoding do
          it "uses the start as a character offset" do
            /(.).(.)/.match("零一二三四", 1).captures.should == ["一", "三"]
          end

          it "raises an ArgumentError for an invalid encoding" do
            lambda { /(.).(.)/.match("Hello, \x96 world!", 1) }.should raise_error(ArgumentError)
          end
        end
      end

      describe "when given a negative position" do
        it "matches the input at a given position" do
          /(.).(.)/.match("01234", -4).captures.should == ["1", "3"]
        end

        with_feature :encoding do
          it "uses the start as a character offset" do
            /(.).(.)/.match("零一二三四", -4).captures.should == ["一", "三"]
          end

          it "raises an ArgumentError for an invalid encoding" do
            lambda { /(.).(.)/.match("Hello, \x96 world!", -1) }.should raise_error(ArgumentError)
          end
        end
      end
    end

    describe "when passed a block" do
      it "yields the MatchData" do
        /./.match("abc") {|m| ScratchPad.record m }
        ScratchPad.recorded.should be_kind_of(MatchData)
      end

      it "returns the block result" do
        /./.match("abc") { :result }.should == :result
      end

      it "does not yield if there is no match" do
        ScratchPad.record []
        /a/.match("b") {|m| ScratchPad << m }
        ScratchPad.recorded.should == []
      end
    end
  end

  it "resets $~ if passed nil" do
    # set $~
    /./.match("a")
    $~.should be_kind_of(MatchData)

    /1/.match(nil)
    $~.should be_nil
  end

  it "raises TypeError when the given argument cannot be coarce to String" do
    f = 1
    lambda { /foo/.match(f)[0] }.should raise_error(TypeError)
  end

  ruby_version_is ""..."1.9" do
    it "coerces Exceptions into strings" do
      f = Exception.new("foo")
      /foo/.match(f)[0].should == "foo"
    end
  end

  ruby_version_is "1.9" do
    it "raises TypeError when the given argument is an Exception" do
      f = Exception.new("foo")
      lambda { /foo/.match(f)[0] }.should raise_error(TypeError)
    end
  end
end

describe "Regexp#~" do
  it "matches against the contents of $_" do
    $_ = "input data"
    (~ /at/).should == 7
  end
end
