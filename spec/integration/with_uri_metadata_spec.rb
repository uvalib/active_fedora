require 'spec_helper'

describe "URIs as objects" do
  before do
    class BookTitle < ActiveFedora::Base
      property :pref_label, predicate: ::RDF::Vocab::SKOS.prefLabel
    end

    class Book < ActiveFedora::Base
      property :title, predicate: ::RDF::Vocab::DC.title, class_name: "BookTitle"
    end
  end

  after do
    Object.send(:remove_const, :BookTitle)
    Object.send(:remove_const, :Book)
  end

  let(:book)  { Book.new }
  let(:title) { BookTitle.create(pref_label: ["My Book Title"]) }

  subject { book.title.first.pref_label.first }

  context "with a book's title as a uri" do
    before do
      book.title = [title.uri]
      book.save
    end
    it { is_expected.to eq("My Book Title") }
  end

  context "with a book's title as an AF::Base object" do
    before do
      book.title = [title]
      book.save
    end
    it { is_expected.to eq("My Book Title") }
  end
end
