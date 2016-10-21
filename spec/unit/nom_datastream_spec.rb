require 'spec_helper'

describe ActiveFedora::NomDatastream do
  describe "test" do
    subject {
      class MyNomDatastream < ActiveFedora::NomDatastream
       
        set_terminology do |t|
          t.a :path => '//a', :accessor => lambda { |x| x.text }, :index => 'a_s'
          t.b :path => '//b', :index => 'b_s'
        end
      end 

      MyNomDatastream.from_xml '<root><a>123</a><b><c>asdf</c></b></root>'
    }

    it "should work" do
      expect(subject.a).to include("123")
    end

    it "should to_solr" do
      expect(subject.to_solr['a_s']).to include('123')
      expect(subject.to_solr['b_s']).to include('asdf')
    end

    it "should be a managed datastream" do
      expect(subject.controlGroup).to eq('M')
    end
  end

  describe "with options for .set_terminology" do
    subject {
      class TerminologyOptions < ActiveFedora::NomDatastream
        set_terminology({
          :namespaces => {
            'dc' => "http://purl.org/dc/elements/1.1/",
            'dcterms' => "http://purl.org/dc/terms/"
          }
        }) do |t|
          t.a :path => 'a', :xmlns => 'dc', :accessor => lambda { |x| x.text }
        end
      end

      TerminologyOptions.from_xml %(
        <root
          xmlns:dc="http://purl.org/dc/elements/1.1/"
          xmlns:dcterms="http://purl.org/dc/terms/"
        >
          <dc:a>123</dc:a>
          <dcterms:a>not-part-of-a</dcterms:a>
          <dcterms:b>abcd</dcterms:b>
        </root>
      )
    }

    it "should scope #a attribute to only the dc namespace" do
      expect(subject.a).to eq(["123"])
    end

  end
end
