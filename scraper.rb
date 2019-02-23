require 'httparty'
require 'nokogiri'

output_directory = './out/'.freeze

index_url = 'https://cf.ict-berufsbildung.ch/modules.php?name=Mbk&a=20100'.freeze
module_list_selector = 'div.item:nth-child(3) > form:nth-child(3) > line:nth-child(2) > div:nth-child(2) > z:nth-child(1)'.freeze
module_list_attribute = 'ng-init'.freeze
module_list_pattern = /\[(.*)\]/m
module_number_attribute = 'cmodnr'.freeze
module_url = 'https://cf.ict-berufsbildung.ch/modules.php?name=Mbk&a=20101&cmodnr='.freeze
module_data_selector = '#publikationModul > tabs:nth-child(1) > tab:nth-child(1) > tabs:nth-child(1) > tab:nth-child(1) > dl:nth-child(2)'.freeze

index_document = Nokogiri::HTML(HTTParty.get(index_url))
unless index_document
  exit 1
end

module_list = index_document.css(module_list_selector)
unless module_list
  exit 1
end

module_list = module_list.first[module_list_attribute]
unless module_list
  exit 1
end

module_list = JSON.parse(module_list_pattern.match(module_list).to_s)
unless module_list
  exit 1
end

module_list.each do |m|
  module_document = Nokogiri::HTML(HTTParty.get(module_url + m[module_number_attribute]))
  module_data = module_document.css(module_data_selector)

  module_builder = Nokogiri::XML::Builder.new do |xml|
    xml.competency('xmlns' => 'https://ictorg.ch/competency', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'https://ictorg.ch/competency ../../../schema/competency.xsd') {
      xml.meta {
        xml.provider('name' => 'ICT-Berufsbildung') {
          xml.id_ m[module_number_attribute]
          xml.reference module_url + m[module_number_attribute]
          xml.level module_data.css('dd:nth-child(12)').first.text
          xml.lessons module_data.css('dd:nth-child(16)').first.text
          xml.achnowledgment module_data.css('dd:nth-child(18)').first.text
        }
      }
      xml.title module_data.css('dd:nth-child(2)').first.text
      xml.capability module_data.css('dd:nth-child(4)').first.text
      xml.goals
    }
  end

  File.open(output_directory + 'test.xml', 'w') do |file|
    file.write module_builder.to_xml(encoding: "UTF-8")
  end
  exit 1
end