require 'spec_helper'

@@last_pid = 0
describe ActiveFedora::SemanticNode do

  describe "with a bunch of objects" do
    def increment_pid
      @@last_pid += 1    
    end
    
    before(:each) do
      class SpecNode
        include ActiveFedora::SemanticNode
        
        attr_accessor :pid
        def initialize (params={}) 
          self.pid = params[:pid]
        end
        def internal_uri
          'info:fedora/' + pid.to_s
        end
      end

      @node = SpecNode.new
      allow(@node).to receive(:rels_ext).and_return(double("rels_ext", :content_will_change! => true, :content=>''))
      @node.pid = increment_pid
    end
    
    after(:each) do
      Object.send(:remove_const, :SpecNode)
    end

    describe "pid_from_uri" do
      it "should strip the info:fedora/ out of a given string" do 
        expect(SpecNode.pid_from_uri("info:fedora/FOO:BAR")).to eq("FOO:BAR")
      end
    end
    
    describe ".add_relationship" do
      it "should add relationship to the relationships graph" do
        @node.add_relationship("isMemberOf", 'demo:9')
        expect(@node.ids_for_outbound("isMemberOf")).to eq(['demo:9'])
      end
      it "should not be written into the graph until it is saved" do
        @n1 = ActiveFedora::Base.new
        @node.add_relationship(:has_part, @n1)
        expect(@node.relationships.statements.to_a.first.object.to_s).to eq('info:fedora/') 
        @n1.save
        expect(@node.relationships.statements.to_a.first.object.to_s).to eq(@n1.internal_uri)
      end

      it "should add a literal relationship to the relationships graph" do
        @node.add_relationship("isMemberOf", 'demo:9', true)
        expect(@node.relationships("isMemberOf")).to eq(['demo:9'])
      end
      
      it "adding relationship to an instance should not affect class-level relationships hash" do 
        local_test_node1 = SpecNode.new
        local_test_node2 = SpecNode.new
        allow(local_test_node1).to receive(:rels_ext).and_return(double("rels_ext", :content_will_change! => true, :content=>''))
        local_test_node1.add_relationship(:is_member_of, 'demo:10')
        allow(local_test_node2).to receive(:rels_ext).and_return(double('rels-ext', :content=>''))
        
        expect(local_test_node1.relationships(:is_member_of)).to eq(["demo:10"])
        expect(local_test_node2.relationships(:is_member_of)).to eq([])
      end
      
    end

    describe ".clear_relationship" do
      before do
        @node.add_relationship(:is_member_of, 'demo:9')
        @node.add_relationship(:is_member_of, 'demo:7')
        @node.add_relationship(:has_description, 'demo:9')
      end
      it "should clear the specified relationship" do
        @node.clear_relationship(:is_member_of)
        expect(@node.relationships(:is_member_of)).to eq([])
        expect(@node.relationships(:has_description)).to eq(['demo:9'])
      end
    end
    
    describe '#remove_relationship' do
      it 'should remove a relationship from the relationships hash' do
        allow(@node).to receive(:rels_ext).and_return(double("rels_ext", :content_will_change! => true, :content=>''))
        @node.add_relationship(:has_part, "info:fedora/3")
        @node.add_relationship(:has_part, "info:fedora/4")
        #check both are there
        expect(@node.ids_for_outbound(:has_part)).to include "3", "4"
        @node.remove_relationship(:has_part, "info:fedora/3")
        #check returns false if relationship does not exist and does nothing with different predicate
        @node.remove_relationship(:has_member,"info:fedora/4")
        #check only one item removed
        expect(@node.ids_for_outbound(:has_part)).to eq(['4'])
        @node.remove_relationship(:has_part,"info:fedora/4")
        #check last item removed and predicate removed since now emtpy
        expect(@node.ids_for_outbound(:has_part)).to eq([])

        expect(@node.relationships_are_dirty).to eq(true)
        
      end
    end

    describe '#assert_kind_of' do
      it 'should raise an exception if object supplied is not the correct type' do
        expect {@node.assert_kind_of 'SpecNode', @node, ActiveFedora::Base}.to raise_error
        #now should not throw any exception
        @node.assert_kind_of 'SpecNode', @node, SpecNode
      end
    end
  end
end
