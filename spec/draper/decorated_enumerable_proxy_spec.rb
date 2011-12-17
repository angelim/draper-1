require 'spec_helper'

describe Draper::DecoratedEnumerableProxy do

  before        { ApplicationController.new.set_current_view_context }
  subject       { Draper::DecoratedEnumerableProxy.new(source, ProductDecorator, :context => "some") }
  let(:p1)      { Product.new }
  let(:p2)      { Product.new }
  let(:widget)  { Widget.new }
  let(:source)  { ProductArray.new [p1, p2 ] }
  
  describe "#initialize" do
    it "sets +wrapped_collection+" do
      subject.wrapped_collection.class.should == ProductArray
    end
    it "sets +klass+" do
      subject.klass.should == ProductDecorator
    end
    it "sets +options+" do
      subject.options.should == { :context => "some" }
    end
  end
  
  describe "#each" do
    context "when members are of the same type" do
      it "returns decorated members" do
        members = []
        subject.each{ |m| members << m }
        members.first.class.should == ProductDecorator
        members.last.class.should == ProductDecorator
      end
    end
    context "when members are of different types" do
      let(:source)  { ProductArray.new [p1, widget ] }
      it "returns their correspondent decorator" do
        members = []
        subject.each{ |m| members << m }
        members.first.class.should == ProductDecorator
        members.last.class.should == WidgetDecorator
      end
    end
  end
  
  describe "#to_ary" do
    it "returns decorated members" do
      members = subject.to_ary
      members.first.class.should == ProductDecorator
      members.last.class.should == ProductDecorator
    end
  end
  
  describe "#method_missing" do
    it "falls back to wrapper class " do
      subject.collection_method.should == "Some result"
    end
  end
  
  describe "#respond_to" do
    it "falls back to wrapper class " do
      subject.should respond_to :collection_method
    end
  end
  
  describe "#==" do
    it "evaluates class to wrapper class" do
      (subject == source).should be_true
    end
  end
  
  describe "#[]" do
    it "returns decorated element from enumerable index" do
      subject[1].class.should == ProductDecorator
    end
  end
  
  describe "#to_s" do
    it "returns formatted inspection" do
      subject.to_s.should =~ /DecoratedEnumerableProxy/
    end
  end
  
end
