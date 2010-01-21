require 'nokogiri'

class FileBrowserMigrator
  class << self
    def run
      [PagePart, Snippet, Layout].each do |klass|
        klass.find_each do |content|
          fix content
          content.save!
        end
      end
    end

    def fix(content)
      content.content.gsub!(/<img.*?src=\".*?\/assets\/.*?\".*?>/) do |img_tag|
        tag = Nokogiri.parse(img_tag).children.first # First element of the document containing only this tag.
        tag.name = 'r:assets:image'
        src = tag.remove_attribute 'src'
        asset = src && Asset.find_by_asset_file_name(src.value.split('/').last)
        next unless asset

        # Use alt from img tag for asset caption if missing.
        alt = tag.remove_attribute 'alt'
        asset.update_attributes(:caption => alt.value) if asset.caption.blank? && alt

        # Get "title", Radiant's reference to the asset, from the img src.
        tag.set_attribute('title', asset.title)

        asset_tag = tag.to_html.gsub("></r:assets:image>", " />") # As HTML, converted to self-closing tag.
      end
    end
  end
end
