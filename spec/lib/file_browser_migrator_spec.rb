require File.dirname(__FILE__) + '/../spec_helper'

describe FileBrowserMigrator do
  describe "fixing content" do
    before do
      @asset = mock_model(Asset, :caption => nil, :title => 'MyAsset', :update_attributes => nil)
      Asset.stub!(:find_by_asset_file_name).and_return @asset
      @content = %(
        <p>All models are wrong, some are useful.</p>
        <img src="../../../assets/Correlation.jpeg" />
        <img src="../../../assets/LolCat.gif" alt="Lol!" />
        <p>Some junk, <a><b>Malformed</a></b> HTML...
      )
      @part = PagePart.new(:content => @content)
    end

    it "should not alter image tags for which it can't find an asset" do
      Asset.stub!(:find_by_asset_file_name).and_return nil

      FileBrowserMigrator.fix @part
      @part.content.should == @content
    end

    it "should alter image tags for which it can find an asset" do
      FileBrowserMigrator.fix @part
      @part.content.should_not include("<img")
    end

    it "should use the last part of the src to search for a matching asset" do
      Asset.should_receive(:find_by_asset_file_name).with "Correlation.jpeg"
      FileBrowserMigrator.fix @part
    end

    it "should not update the asset caption when one exists" do
      @asset.stub!(:caption).and_return "Something"
      @asset.should_not_receive :update_attributes
      FileBrowserMigrator.fix @part
    end

    it "should update the asset caption when there is alt text, and no caption exists" do
      @asset.stub!(:caption).and_return nil
      @asset.should_receive(:update_attributes).once.with :caption => "Lol!"
      FileBrowserMigrator.fix @part
    end

    it "should transform img w. src tags to r:assets:image w. title tags" do
      FileBrowserMigrator.fix @part
      @part.content.should == %(
        <p>All models are wrong, some are useful.</p>
        <r:assets:image title="MyAsset" />
        <r:assets:image title="MyAsset" />
        <p>Some junk, <a><b>Malformed</a></b> HTML...
      )
    end
  end

  describe "running" do
    before do
      FileBrowserMigrator.stub! :fix
    end

    after do
      FileBrowserMigrator.run
    end

    [PagePart, Snippet, Layout].each do |content_class|
      it "should fix and save #{content_class.name.humanize.downcase.pluralize}" do
        content_class.stub!(:find_each).and_yield @content = mock_model(content_class, :save! => true)
        FileBrowserMigrator.should_receive(:fix).with @content
        @content.should_receive :save!
      end
    end
  end
end
