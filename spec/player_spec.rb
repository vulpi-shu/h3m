require "spec_helper"
require 'yaml'

describe H3m::Player do

  @fixtures = YAML.load_file("spec/resources.yml")
  @files = @fixtures.map do |p|
    {path: "spec/resources/#{p["file"]}", params: p }
  end

  @files.each do |file|
    context "from file #{file[:path]}" do

      before :all do
        @map = H3m::Map.new(file[:path])
        @present_players  = @map.players.select {|p| p.present? }
        @computer_players = @map.players.select {|p| p.computer? }
      end

      it "should determine player presence" do
        @players.each_with_index do |p, i|
          p.present?.should == file[:params]["players"][i]["present"]
        end
      end

      it "should determine player availability to human and computer" do
        @present_players.each_with_index do |p, i|
          p.human?.should == file[:params]["players"][i]["human"]
          p.computer?.should == file[:params]["players"][i]["human"]
        end
      end
      
      it "should determine computer behaviour" do
        @computer_players.each_with_index do |p, i|
          p.computer_behaviour.should == file[:params]["players"][i]["computer_behaviour"]
        end
      end
      
      it "should determine has player town on start or not" do
        @present_players.each_with_index do |p, i|
          p.has_town_on_start?.should == file[:params]["players"][i]["has_town_on_start"]
        end
      end

    end
  end

end