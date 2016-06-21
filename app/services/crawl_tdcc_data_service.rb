class CrawlTdccDataService
    
    # URL example: http://www.tdcc.com.tw/smWeb/QryStock.jsp?SCA_DATE=20160617&SqlMethod=StockNo&StockNo=3662&StockName=&sub=%ACd%B8%DF
    
    require 'open-uri'
    
    def initialize
    end
    
    def fetch_all_data
        all_stocks = fetch_all_stock_number
    end
    
    private 
    
    def fetch_all_stock_number
        # Get all the stocks from http://www.emega.com.tw/js/StockTable.htm
        stock_list = []
        targetURL = "http://www.emega.com.tw/js/StockTable.htm"
        text = Nokogiri::HTML(open(targetURL)).inner_text
        list = text.split(/\r?\n/)
        list.each do |l|
            if /^\d{4}/.match(l)
                stock_list << l
            end
        end
        return stock_list
    end
end