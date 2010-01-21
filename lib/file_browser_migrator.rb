require 'nokogiri'

class FileBrowserMigrator
  class << self
    def run
      [PagePart, Snippet, Layout].each do |klass|
        klass.find_each do |resource|
          fix resource
          resource.content_will_change! # ActiveRecord::Dirty fails to notice the content change.
          resource.save!
        end
      end
    end

    def fix(resource)
      resource.content.gsub!(/<img.*?src=\".*?\/assets\/.*?\".*?>/) do |img_tag|
        tag = Nokogiri.parse(img_tag).children.first # First element of the document containing only this tag.

        # Change the tag to an r:assets:image one.
        tag.name = 'r:assets:image'
        src = tag.remove_attribute 'src'
        asset = src && Asset.find_by_asset_file_name(src.value.split('/').last)
        next unless asset

        # Use alt from img tag for asset caption if missing.
        alt = tag.remove_attribute 'alt'
        asset.update_attributes(:caption => alt.value) if asset.caption.blank? && alt

        # Set Radiant's reference to the asset.
        tag.set_attribute('id', asset.id.to_s)

        asset_tag = tag.to_html.gsub("></r:assets:image>", " />") # As HTML, converted to self-closing tag.
      end
    end
  end
end
