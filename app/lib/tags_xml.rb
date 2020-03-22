# frozen_string_literal: true

class TagsXml
  SAVE_OPTS = [
      Nokogiri::XML::Node::SaveOptions::FORMAT,
      Nokogiri::XML::Node::SaveOptions::NO_DECLARATION,
      Nokogiri::XML::Node::SaveOptions::AS_XML
  ].sum

  # Load from xml string.
  # @param xml [String] xml node with children tags
  # @return [TagsXml]
  def self.load(xml)
    xml_node = Nokogiri::XML(xml)
    new(xml_node.root)
  end

  # Build from tags array.
  # @param tags [Array<String>]
  # @return [TagsXml]
  def self.build(tags)
    raise ArgumentError, 'tags are invalid' unless tags.is_a?(Array)

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.tags do
        tags.each { |value| xml.tag(value.to_s) }
      end
    end
    new(builder.doc.root)
  end

  def initialize(xml_node)
    @xml_node = xml_node
  end

  # @return [String] xml string.
  def to_xml
    @xml_node.to_xml(save_with: SAVE_OPTS)
  end

  # @return [Array<String>] array of tags.
  def tags
    @xml_node.xpath('./tag').map(&:text)
  end
end
