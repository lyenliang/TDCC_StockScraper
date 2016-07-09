require 'mysql2'
require 'open-uri'
require 'nokogiri'

@db_host = "localhost"
@db_user = "lyenliang"
@db_pass = "somepass"
@db_name = "c9"
@tdcc_table_name = "tdcc"
@stock_price_table_name = "stock_price"

@tdcc_url = "http://www.tdcc.com.tw/smWeb/QryStock.jsp"
@stock_table_url = "http://www.emega.com.tw/js/StockTable.htm"

@otc_price = "http://www.tpex.org.tw/web/stock/aftertrading/daily_trading_info/st43_download.php"
@exchange_market_price = "http://www.twse.com.tw/ch/trading/exchange/STOCK_DAY_AVG/STOCK_DAY_AVG2.php"

@client = Mysql2::Client.new(:host => @db_host, :username => @db_user, :password => @db_pass)
@client.query("USE #{@db_name}")

def init()
    # reset()
    dates = fetch_all_dates
    stocks = fetch_all_stock_number
    # fetch_tdcc_all_data(dates, stocks)
    fetch_price_all_data(dates, stocks)
end

def reset
    # reset_db
    reset_tdcc_table
    reset_price_table
end

def reset_tdcc_table
    @client.query("DROP TABLE IF EXISTS #{@tdcc_table_name};")
    @client.query("CREATE TABLE #{@tdcc_table_name} (stock_number VARCHAR(255), stock_name VARCHAR(255), date DATE, share_group VARCHAR(255), people INT, shares INT, percent FLOAT);")
end

def reset_price_table
    @client.query("DROP TABLE IF EXISTS #{@stock_price_table_name};")
    @client.query("CREATE TABLE #{@stock_price_table_name} (stock_number VARCHAR(255), date DATE, closing_price FLOAT, type VARCHAR(255));")
end

def reset_db
    @client.query("DROP DATABASE IF EXISTS #{@db_name};")
    @client.query("CREATE DATABASE #{@db_name} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;")
    @client.query("USE #{@db_name}")
end

def insert_tdcc_table(snumber, sname, date, sgroup, people, ss, pt)
    @client.query("INSERT INTO #{@tdcc_table_name} (stock_number, stock_name, date, share_group, people, shares, percent)
            VALUES ('#{snumber}', '#{sname}', '#{date}', '#{sgroup}', '#{people}', '#{ss}', '#{pt}');")
end

def insert_price_table(stock_number, date, closing_price, type)
    puts "stock_number: #{stock_number}"
    puts "date: #{date}"
    puts "closing_price: #{closing_price}"
    puts "type: #{type}"
    @client.query("INSERT INTO #{@stock_price_table_name} (stock_number, date, closing_price, type)
            VALUES ('#{stock_number}', '#{date}', '#{closing_price}', '#{type}');")
end

def fetch_tdcc_all_data(dates, stocks)
    all_stocks.each do |stock|
        dates.each do |date|
            fetch_tdcc_single_date(stock, date)
        end
    end
end



def fetch_tdcc_single_date(stock, date)
    begin
        url = @tdcc_url + '?SCA_DATE=' + date + '&SqlMethod=StockNo&StockNo=' + stock + '&StockName=&sub=%ACd%B8%DF'
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
            insert_tdcc_table(stock_number, stock_name, date, cells[1].inner_text, cells[2].inner_text.gsub(/,/, ''), cells[3].inner_text.gsub(/,/, ''), cells[4].inner_text)
        end

    rescue Exception => e
        # continue the loop
        puts "Error!!!"
        puts e.message
        puts e.backtrace.inspect
    end
end

def fetch_all_stock_number
    # Get all the stocks from http://www.emega.com.tw/js/StockTable.htm
    stock_list = []
    text = Nokogiri::HTML(open(@stock_table_url)).inner_text
    list = text.split(/\r?\n/)
    list.each do |l|
        if /^\d{4}/.match(l)
            stripped_string = l.lstrip.chop
            #puts "stripped_string: #{stripped_string}"
            stock_list << stripped_string
        end
    end
    return stock_list
end

def fetch_all_dates
    # return a list of all the dates
    dates = []
    open_url = open(@tdcc_url)
    date_tmp = Nokogiri::HTML(open_url).css("option")

    date_tmp.each do |date_t|
        dates << date_t.inner_text
    end

    return dates
end

def fetch_db_latest_date
    date = @client.query("select date from #{@db_name}.#{@tdcc_table_name} order by date DESC limit 1;")
    date_s = date.first["date"].to_s
    return date_s
end

def truncate_old_dates(last_date, all_dates)
    last_date_format = last_date.gsub(/-/, '')
    index = all_dates.index(last_date_format)
    if index > 0
        length = index + 1
        return all_dates[0, length]
    else
        return all_dates[0,0]
    end
end

def fetch_new_data
    last_date = fetch_db_latest_date
    all_dates = fetch_all_dates
    new_dates = truncate_old_dates(last_date, all_dates)
    all_stocks = fetch_all_stock_number

    all_stocks.each do |stock|
        new_dates.each do |date|
            fetch_tdcc_single_date(stock, date)
        end
    end
end

def fetch_price_all_data(dates, stocks)
    year_months = extractMonths(dates)
    year_months.each do |month|
        stocks.each do |stock|
            fetch_price(stock, month)
        end
    end
end

# An example showing the input and output of extractMonths(dates):
# input: ["20160701", "20160624", "20160617" ... "2015/07/03"]
# output: ["105/07", "105/06", ... "104/07"]
def extractMonths(dates)
    last = dates[0]
    first = dates[-1]

    first_month = first[4...6].to_i
    first_year = ad_to_tw(first[0, 4].to_i)

    last_month = last[4...6].to_i
    last_year = ad_to_tw(last[0, 4].to_i)
    return calculateWholeMonths(first_year, first_month, last_year, last_month)
end

def calculateWholeMonths(first_year, first_month, last_year, last_month)
    allMonths = []

    for m in (last_month).downto(1)
        leading_zero_m = "#{m}".rjust(2, '0')
        allMonths << "#{last_year}/#{leading_zero_m}"
    end

    for m in (12).downto(first_month)
        leading_zero_m = "#{m}".rjust(2, '0')
        allMonths << "#{first_year}/#{leading_zero_m}"
    end
    return allMonths
end

def fetch_price(stkno, date)
    begin
        result = fetch_otc(stkno, date)
        if result == false
            puts "#{stkno} data not found in counter market"
            # if stkno != '1455'
            #     puts "!!!"
            # end
            fetch_stock_exchange(stkno, date)
        end
    rescue Exception => e
        # continue the loop
        puts "Error!!!"
        puts e.message
        puts e.backtrace.inspect
    end
    # 上市

end

def fetch_stock_exchange(stock, date)
    # 上市
    # example:
    # http://www.twse.com.tw/ch/trading/exchange/STOCK_DAY_AVG/STOCK_DAY_AVG2.php?STK_NO=2303&myear=2016&mmon=02&type=csv
    puts "Fetch stock exchange #{stock}, #{date}"
    year_month = date.split('/')
    year = tw_to_ad(year_month[0]).to_s
    month = year_month[1].to_s
    url = @exchange_market_price + '?STK_NO=' + stock + '&myear=' + year + '&mmon=' + month + '&type=csv'
    open_url = open(url)
    web_data = Nokogiri::HTML(open_url)
    rows = web_data.inner_text.split(/\r?\n/)
    for i in 2..(rows.size-3)
        date_price = rows[i].split(/,/)
        closing_price = date_price[1]
        if closing_price == '--'
            next
        end
        date = date_price[0]
        date = transform_date(date)
        insert_price_table(stock, date, closing_price, 'exchange')
    end
end

# OTC: over-the-counter
def fetch_otc(stock, date)
    # 上櫃
    # example:
    # http://www.tpex.org.tw/web/stock/aftertrading/daily_trading_info/st43_download.php?l=zh-tw&d=105/07&stkno=3662&s=0,asc,0
    # stock = "3662"
    url = @otc_price + '?l=zh-tw&d=' + date + '&stkno=' + stock + '&s=0,asc,0'
    puts "stock: #{stock}"
    puts "date: #{date}"

    open_url = open(url)
    web_data = Nokogiri::HTML(open_url)
    rows = web_data.inner_text.split(/\r?\n/)
    if rows.size <= 6
        return false
    end
    for i in 5..(rows.size-2)
        row_data = rows[i].split(/,/)
        date = row_data[0]
        date = transform_date(date)
        # transform date to 20XX-XX-XX
        price = row_data[7].gsub(/"/, '')
        insert_price_table(stock, date, price, 'otc')
    end
    return true
end

def ad_to_tw(ad_year)
    return ad_year.to_i - 1911
end

def tw_to_ad(tw_year)
    return tw_year.to_i + 1911
end

def transform_date(date)
    date.gsub!(/"/, '')
    year_month_day = date.split(/\//)
    ad_year = tw_to_ad(year_month_day[0]).to_s
    return ad_year + "-" + year_month_day[1] + "-" + year_month_day[2]
end

reset_price_table
init

# fetch_new_data

@client.close