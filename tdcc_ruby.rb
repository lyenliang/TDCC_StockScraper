require 'mysql2'
require 'open-uri'
require 'nokogiri'

@db_host = "localhost"
@db_user = "lyenliang"
@db_pass = "somepass"
@db_name = "c9"
@db_table = "tdcc"

@client = Mysql2::Client.new(:host => @db_host, :username => @db_user)
@client.query("USE #{@db_name}")

def reset()
    @client.query("DROP DATABASE IF EXISTS #{@db_name};")
    @client.query("CREATE DATABASE #{@db_name} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;")
    @client.query("USE #{@db_name}")
    @client.query("CREATE TABLE #{@db_table} (stock_number VARCHAR(255), stock_name VARCHAR(255), date DATE, share_group VARCHAR(255), people INT, shares INT, percent FLOAT);")
end

def insert(snumber, sname, d, sgroup, people, ss, pt)
    @client.query("INSERT INTO #{@db_table} (stock_number, stock_name, date, share_group, people, shares, percent) 
            VALUES ('#{snumber}', '#{sname}', '#{d}', '#{sgroup}', '#{people}', '#{ss}', '#{pt}');")
end

def fetch_all_data
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
                    insert(stock_number, stock_name, date, cells[1].inner_text, cells[2].inner_text.gsub(/,/, ''), cells[3].inner_text.gsub(/,/, ''), cells[4].inner_text)
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
            stripped_string = l.lstrip.chop
            #puts "stripped_string: #{stripped_string}"
            stock_list << stripped_string
            
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

#reset()
fetch_all_data

@client.close