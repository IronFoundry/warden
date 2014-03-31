# coding: UTF-8

require "spec_helper"

describe Warden::Protocol::LoggingRequest do
  subject(:request) do
    described_class.new(:handle => "handle", :application_id => "application_id", :instance_index => "instance_index",
                        :loggregator_router => "loggregator_router", :loggregator_secret => "loggregator_secret")
  end

  it_should_behave_like "wrappable request"

  its("class.type_camelized") { should == "Logging" }
  its("class.type_underscored") { should == "logging" }

  field :handle do
    it_should_be_required
  end

  field :application_id do
    it_should_be_required
  end

  field :instance_index do
    it_should_be_required
  end

  field :loggregator_router do
    it_should_be_required
  end

  field :loggregator_secret do
    it_should_be_required
  end

  field :drain_uris do
    it_should_be_optional

    it "should allow one or more entries" do
      subject.drain_uris = ["a", "b"]
      subject.should be_valid
    end
  end

  it "should respond to #logging_response" do
    request.create_response.should be_a(Warden::Protocol::LoggingResponse)
  end
end

describe Warden::Protocol::LoggingResponse do
  subject(:response) do
    described_class.new
  end

  it_should_behave_like "wrappable response"

  its("class.type_camelized") { should == "Logging" }
  its("class.type_underscored") { should == "logging" }

  it { should be_ok }
  it { should_not be_error }
end