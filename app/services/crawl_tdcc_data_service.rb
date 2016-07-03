class CrawlTdccDataService

    # URL example: http://www.tdcc.com.tw/smWeb/QryStock.jsp?SCA_DATE=20160617&SqlMethod=StockNo&StockNo=3662&StockName=&sub=%ACd%B8%DF

    require 'open-uri'


    def initialize
    end

    def fetch_all_data
        table_data = Array.new(15)
        targetURL = "http://www.tdcc.com.tw/smWeb/QryStock.jsp"
        dates = fetch_all_date(targetURL)
        all_stocks = fetch_all_stock_number

        all_stocks.each do |stock|
            dates.each do |date|
                begin

                    url = targetURL + '?SCA_DATE=' + date + '&SqlMethod=StockNo&StockNo=' + stock + '&StockName=&sub=%ACd%B8%DF'
                    puts "stock: #{stock}"
                    puts "date: #{date}"

                    open_url = open(url)
                    web_data = Nokogiri::HTML(open_url)

                    #
                    # tables[6] contains 證券代號
                    # tables[7]
                    tables = web_data.css("table")

                    title_text = tables[6].css("tr").css("td")[0].inner_text
                    stock_number = /\d+/.match(title_text).to_s
                    stock_name = title_text.split(/\s/)[1].split("：")[1]

                    rows = tables[7].css("tbody").css("tr")

                    for i in 1..15
                        cells = rows[i].css("td")
                        tdcc = Tdcc.new
                        tdcc.stock_number = stock_number
                        tdcc.stock_name = stock_name
                        tdcc.date = date
                        tdcc.share_group = cells[1].inner_text
                        tdcc.people = cells[2].inner_text.gsub(/,/, '')
                        tdcc.shares = cells[3].inner_text.gsub(/,/, '')
                        tdcc.percent = cells[4].inner_text
                        tdcc.save
                    end

                rescue Exception => e
                    # continue the loop
                    puts "Error!!!"
                    puts e.message
                    puts e.backtrace.inspect
                end

            end # end of dates.each
        end # end of all_stocks.each
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

    def fetch_all_date(targetURL)
        # return a list of all the dates
        dates = []
        open_url = open(targetURL)
        date_tmp = Nokogiri::HTML(open_url).css("option")

        date_tmp.each do |date_t|
            dates << date_t.inner_text
        end

        return dates
    end
end
