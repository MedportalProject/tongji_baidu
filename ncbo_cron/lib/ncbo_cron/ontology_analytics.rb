require 'logger'
# require 'uri'
# require 'date'
# require 'net/http'
# require 'json'

module NcboCron
  module Models

    class OntologyAnalytics
      ONTOLOGY_ANALYTICS_REDIS_FIELD = "ontology_analytics"

      def initialize(logger)
        @logger = logger
      end

      def run
        redis = Redis.new(:host => NcboCron.settings.redis_host, :port => NcboCron.settings.redis_port)
        ontology_analytics = fetch_ontology_analytics
        redis.set(ONTOLOGY_ANALYTICS_REDIS_FIELD, Marshal.dump(ontology_analytics))
      end

      def days_in_month(d)
        m = d.month
        if [1,3,5,7,8,10,12].include?(m)
          31
        elsif [4,6,9,11].include?(m)
          30
        elsif d.leap?
          29
        else
          28
        end
      end

      def get_start_date(year,month)
        return month < 10 ? year.to_s + "0" +  month.to_s + "01" : year.to_s + month.to_s + "01"
      end

      def get_end_date(year,month)
        last_day_of_the_month = days_in_month Date::new(year,month,1)
        return month < 10 ? year.to_s + "0" + month.to_s + last_day_of_the_month.to_s : year.to_s + month.to_s + last_day_of_the_month.to_s
      end


      def fetch_ontology_analytics
        
        @logger.info "Start ontology analytics refresh..."
        @logger.flush
        
        aggregated_results = Hash.new
        ont_acronyms = LinkedData::Models::Ontology.where.include(:acronym).all.map {|o| o.acronym}
        # ont_acronyms = ["NCIT", "ONTOMA", "CMPO", "AEO", "SNOMEDCT"]
    
        uri = URI.parse("https://api.baidu.com/json/tongji/v1/ReportService/getData")
        header = {'Content-Type': 'data/json;charset=UTF-8'}
    
        analytics_start_year = 2020
        analytics_end_year = Date.today.year
        analytics_end_month = Date.today.month
        year = analytics_start_year
    
        while year <= analytics_end_year
          month = 1
          while month < 13


            if (year == analytics_end_year) and (month > analytics_end_month)
              break
            end
    
            start_date = get_start_date(year,month)
            end_date = get_end_date(year,month)
            max_results = 10000 # 单次获取数据条数
            start_index = 0 # 百度统计索引是从0开始的
    
            loop do
              raw = {
                "header": {
                  "username": "yourusername",
                  "password": "yourpassword",
                  "token": "yourtoken",
                  "account_type": 1
                },
                "body": {
                  "site_id": "yoursiteid",
                  "start_date": "#{start_date}",
                  "end_date": "#{end_date}",
                  "metrics": "pv_count",
                  "method": "visit/toppage/a",
                  "start_index": "#{start_index}",
                  "max_results": "#{max_results}"
                }
              }  
    
              # Create the HTTP objects
              https = Net::HTTP.new(uri.host, uri.port)
              https.use_ssl = true
    
              request = Net::HTTP::Post.new(uri.request_uri, header)
              request.body = raw.to_json
    
              # Send the request
              response = https.request(request)
              json = JSON.parse(response.body) 
    
              visit_page_title_array = json['body']['data'][0]['result']['items'][0] # 受访页面URL数组
              pv_count_array = json['body']['data'][0]['result']['items'][1] # 受访页面浏览量数组
    
 
	      i = 0
              while i < visit_page_title_array.length
                name = visit_page_title_array[i][0]["name"]
                value = pv_count_array[i][0]
                ont_acronyms.each do |acronym|
                  if name =~ /^http:\/\/medportal\.bmicc\.cn\/ontologies\/#{acronym}(\/?\?{0}|\/?\?{1}.*)$/
                    if (aggregated_results.has_key?(acronym))
                      # year
                      if (aggregated_results[acronym].has_key?(year))
                        # month
                        if (aggregated_results[acronym][year].has_key?(month))
                          aggregated_results[acronym][year][month] += value
                        else
                          aggregated_results[acronym][year][month] = value
                        end
                      else
                        aggregated_results[acronym][year] = Hash.new
                        aggregated_results[acronym][year][month] = value
                      end
                    else
                      aggregated_results[acronym] = Hash.new
                      aggregated_results[acronym][year] = Hash.new
                      aggregated_results[acronym][year][month] = value
                    end
                    break
                  end
                end
                i = i + 1
              end
                    
                        
              if (visit_page_title_array.length < max_results)
                break # 终止loop循环
              else
                start_index += max_results 
                # 开始下一次loop循环
              end
            end
    
            # 循环下一个月
            month = month + 1
          end
          # 循环下一年
          year = year + 1
        end 
             
    
        ont_acronyms.each do |acronym|
          (analytics_start_year..analytics_end_year).each do |y|
            aggregated_results[acronym] = Hash.new if aggregated_results[acronym].nil?
            aggregated_results[acronym][y] = Hash.new unless aggregated_results[acronym].has_key?(y)
          end
          # fill up non existent months with zeros
          (1..12).each { |n| aggregated_results[acronym].values.each { |v| v[n] = 0 unless v.has_key?(n) } }
        end
    
	@logger.info aggregated_results
        @logger.info "Completed ontology analytics refresh..."
        @logger.flush

        aggregated_results
      end
    

    end
  end
end

# require 'ontologies_linked_data'
# require 'goo'
# require 'ncbo_annotator'
# require 'ncbo_cron/config'
# require_relative '../../config/config'
# ontology_analytics_log_path = File.join("logs", "ontology-analytics.log")
# ontology_analytics_logger = Logger.new(ontology_analytics_log_path)
# NcboCron::Models::OntologyAnalytics.new(ontology_analytics_logger).run
# ./bin/ncbo_cron --disable-processing true --disable-pull true --disable-flush true --disable-warmq true --disable-ontologies-report true --disable-mapping-counts true --disable-spam-deletion true --ontology-analytics '14 * * * *'
