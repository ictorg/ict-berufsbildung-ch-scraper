require 'httparty'
require 'nokogiri'
require 'active_support/all'

save_options = {encoding: "UTF-8", indent: 4, save_with: Nokogiri::XML::Node::SaveOptions::FORMAT | Nokogiri::XML::Node::SaveOptions::AS_XML}
output_directory = './out/'.freeze
languages = %w(de it fr)

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
  dirname = ''
  module_languages = []
  languages.each do |l|
    module_request_url = module_url + m[module_number_attribute] + "&clang=#{l}"
    module_document = Nokogiri::HTML(HTTParty.get(module_request_url))
    module_data = module_document.css(module_data_selector)
    module_table_data = module_data.css('> dd:nth-child(6) > table > tbody > tr')

    if module_data.empty?
      puts "No #{l} translation for #{m[module_number_attribute]}!"
      next
    else
      module_languages << l
    end
    module_builder = Nokogiri::XML::Builder.new do |xml|
      xml.competency('xmlns' => 'https://ictorg.ch/competency', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'https://ictorg.ch/competency ../../../schema/competency.xsd') {
        xml.meta {
          xml.provider('name' => 'ICT-Berufsbildung') {
            xml.id_ m[module_number_attribute]
            xml.reference module_request_url.gsub(/&/, '%26')
            xml.level module_data.css('dd:nth-child(12)').first.text
            xml.lessons module_data.css('dd:nth-child(16)').first.text
            xml.achnowledgment module_data.css('dd:nth-child(18)').first.text
          }
        }
        xml.title module_data.css('dd:nth-child(2)').first.text
        xml.capability module_data.css('dd:nth-child(4)').first.text
        xml.goals {
          module_table_data.each_with_index do |t, i|
            if i%2 == 0
              xml.goal {
                xml.text("\n#{' '*12}")
                xml.text(t.css('> td:nth-child(2)').first.text)
                knowledge = module_table_data[i+1].css('table > tr')
                if knowledge.empty?
                  puts "No knowledge points defined in #{m[module_number_attribute]}!"
                else
                  xml.text("\n#{' '*12}")
                  xml.send('knowledge-list') {
                    knowledge.each_with_index do |tt, ii|
                      knowledge_text = tt.css('> td:nth-child(2)').text
                      xml.text("\n#{' ' * 16}")
                      xml.knowledge "\n#{' ' * 20}" + knowledge_text + "\n#{' ' * 16}"

                      if ii == knowledge.length - 1
                        xml.text("\n#{' ' * 12}")
                      end
                    end
                  }
                  xml.text("\n#{' ' * 8}")
                end
              }
            end
          end
        }
      }
    end
    if l == 'de'
      dirname = ActiveSupport::Inflector::parameterize(module_data.css('dd:nth-child(2)').first.text)
      Dir.mkdir(output_directory + dirname)
    end

    File.open(output_directory + dirname + "/#{l}-ch.xml", 'w') do |file|
      file.write module_builder.to_xml(save_options)
    end
  end
  module_builder = Nokogiri::XML::Builder.new do |xml|
    xml.competency('xmlns' => 'https://ictorg.ch/competency', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'https://ictorg.ch/competency ../../schema/competency.xsd') {
      module_languages.each do |l|
        xml.description('xml:lang' => "#{l}-ch") {
          xml.text("./#{dirname}/#{l}-ch.xml")
        }
      end
    }
  end
  File.open(output_directory + "/#{dirname}.xml", 'w') do |file|
    file.write module_builder.to_xml(save_options)
  end
  puts "Scraped module #{m[module_number_attribute]}."
end