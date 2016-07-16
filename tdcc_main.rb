require 'mysql2'
require 'open-uri'
require 'nokogiri'

require 'tdcc'

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

# 上市: http://isin.twse.com.tw/isin/C_public.jsp?strMode=2
# 上櫃: http://isin.twse.com.tw/isin/C_public.jsp?strMode=4
# 興櫃: http://isin.twse.com.tw/isin/C_public.jsp?strMode=5
@exchange_list_url = "http://isin.twse.com.tw/isin/C_public.jsp?strMode=2"
@otc_list_url = "http://isin.twse.com.tw/isin/C_public.jsp?strMode=4"
@emerging_list_url = "http://isin.twse.com.tw/isin/C_public.jsp?strMode=5"

@client = Mysql2::Client.new(:host => @db_host, :username => @db_user)
@client.query("USE #{@db_name}")

def rebuild_all()
    clear_tables()
    reset_price_table
    dates = fetch_all_dates
    stocks = Tdcc.fetch_all_stock_number
    fetch_tdcc_all_data(dates, stocks)
    fetch_price_all_data(dates, stocks)
end

def clear_tables
    # reset_db
    reset_tdcc_table
    reset_price_table
end

def reset_tdcc_table
    @client.query("DROP TABLE IF EXISTS #{@tdcc_table_name};")
    @client.query("CREATE TABLE #{@tdcc_table_name} (stock_number VARCHAR(255), stock_name VARCHAR(255), date DATE, share_group VARCHAR(255), people INT, shares INT8, percent FLOAT);")
end

def reset_price_table
    @client.query("DROP TABLE IF EXISTS #{@price_table_name};")
    @client.query("CREATE TABLE #{@price_table_name} (stock_number VARCHAR(255), date DATE, closing_price FLOAT, type VARCHAR(255));")
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
    @client.query("INSERT INTO #{@price_table_name} (stock_number, date, closing_price, type)
            VALUES ('#{stock_number}', '#{date}', '#{closing_price}', '#{type}');")
end

#def fetch_all_stock_number
#    exchange = fetch_list(@exchange_list_url)
#    otc = fetch_list(@otc_list_url)
#    # emerging = fetch_list(@emerging_list_url)
#    return [*exchange, *otc]
#end

#def fetch_list(target_url)
#  result_list = []
#  web_data = Nokogiri::HTML(open(target_url))
#  trs = web_data.css("tr")
#  trs.each do |tr|
#    if /^\d{4}\s/.match(tr.inner_text)
#      result_list << tr.inner_text[0, 4]
#    end
#  end
#  return result_list
#end

def fetch_tdcc_all_data(dates, stocks)
    stocks.each do |stock|
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

def fetch_db_latest_date(table_name)
    date = @client.query("select date from #{@db_name}.#{table_name} order by date DESC limit 1;")
    date_s = date.first["date"].to_s
    return date_s
end

def truncate_old_dates(last_date, all_dates)
    last_date_format = last_date.gsub(/-/, '')
    index = all_dates.index(last_date_format)
    if index > 0
        length = index
        return all_dates[0, length]
    else
        return all_dates[0,0]
    end
end

def update_tdcc_data
    last_date = fetch_db_latest_date(@tdcc_table_name)
    all_dates = fetch_all_dates
    new_dates = truncate_old_dates(last_date, all_dates)
    if new_dates.size == 0
      return
    end
    all_stocks = Tdcc.fetch_all_stock_number

    all_stocks.each do |stock|
        new_dates.each do |date|
            fetch_tdcc_single_date(stock, date)
        end
    end
end

def update_price_data
    last_date = fetch_db_latest_date(@price_table_name)
    all_dates = fetch_all_dates

    new_dates = truncate_old_dates(last_date, all_dates)
    if new_dates.size == 0
      return
    end

    all_stocks = Tdcc.fetch_all_stock_number
    all_stocks.each do |stock|
        new_dates.each do |date|
            fetch_price(stock, date)
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

def change_date_format(date)
  if date.length == 8 # assume date == YYYYMMDD
    return date[0, 4] + "/" + date[4, 2]
  end
end

def fetch_stock_exchange(stock, date)
    # date format: "YYYY/MM" example: "2016/07"
    # 上市
    # example:
    # http://www.twse.com.tw/ch/trading/exchange/STOCK_DAY_AVG/STOCK_DAY_AVG2.php?STK_NO=2303&myear=2016&mmon=02&type=csv
    if !date.include?("/")
      date = change_date_format(date)
      year_month = date.split('/')
      year = year_month[0]
    else
      year_month = date.split('/')
      year = tw_to_ad(year_month[0]).to_s
    end
    month = year_month[1].to_s
    puts "Fetch stock exchange #{stock}, #{date}"
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
    # date can be: "105/07", "20160702", or "201607"
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

update_tdcc_param = "update_tdcc"
rebuild_param = "rebuild"

if ARGV.size < 1
  puts "Available parameters: #{update_tdcc_param}, #{rebuild_param}"
else
  if ARGV[0] == update_tdcc_param
    update_tdcc_data
    update_price_data
  elsif ARGV[0] == rebuild_param
    rebuild_all
  else
    puts "Unrecognized parameter: #{ARGV[0]}"
  end
end

@client.close
