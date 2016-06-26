class CrawlTdccDataService
    
    # URL example: http://www.tdcc.com.tw/smWeb/QryStock.jsp?SCA_DATE=20160617&SqlMethod=StockNo&StockNo=3662&StockName=&sub=%ACd%B8%DF
    
    require 'open-uri'
    

    def initialize
    end
    
    def fetch_all_data
        targetURL = "http://www.tdcc.com.tw/smWeb/QryStock.jsp"
        all_stocks = fetch_all_stock_number
        all_stocks.each do |stock|
            url = targetURL + '?SCA_DATE=' + '20160617' + '&SqlMethod=StockNo&StockNo=' + stock + '&StockName=&sub=%ACd%B8%DF'
            
            web_data = Nokogiri::HTML(open(url))
            byebug
            # 
            # tables[6] contains 證券代號
            # tables[7] 
            tables = web_data.css("table")
            
            title_text = tables[6].css("tr").css("td")[0].inner_text
            stock_number = /\d+/.match(title_text).to_s
            stock_name = title_text.split(/\s/)[1].split("：")[1]
            
        end
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
                stock_list << l.squish
            end
        end
        return stock_list
    end
end